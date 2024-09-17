use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;
use core::num::traits::Zero;
use core::ops::SnapshotDeref;
use core::starknet::EthAddress;
use core::starknet::get_tx_info;
use core::starknet::storage::{StoragePointerReadAccess};
use evm::backend::starknet_backend;
use evm::create_helpers::CreateHelpers;
use evm::errors::{EVMError, EVMErrorTrait, CONTRACT_ACCOUNT_EXISTS};

use evm::instructions::{
    ExchangeOperationsTrait, LoggingOperationsTrait, StopAndArithmeticOperationsTrait,
    ComparisonAndBitwiseOperationsTrait, SystemOperationsTrait, BlockInformationTrait,
    DuplicationOperationsTrait, EnvironmentInformationTrait, PushOperationsTrait,
    MemoryOperationTrait, Sha3Trait
};

use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{
    Message, Environment, Transfer, ExecutionSummary, ExecutionSummaryTrait, ExecutionResult,
    ExecutionResultTrait, ExecutionResultStatus, AddressTrait, TransactionResult, Address
};
use evm::precompiles::Precompiles;
use evm::precompiles::eth_precompile_addresses;
use evm::state::StateTrait;
use utils::address::compute_contract_address;
use utils::constants;
use utils::eth_transaction::common::TxKind;
use utils::eth_transaction::eip2930::{AccessListItem, AccessListItemTrait};
use utils::eth_transaction::transaction::{Transaction, TransactionTrait};
use utils::helpers::EthAddressExTrait;
use utils::set::{Set, SetTrait};

#[generate_trait]
pub impl EVMImpl of EVMTrait {
    fn process_transaction(
        ref self: KakarotCore::ContractState, origin: Address, tx: Transaction, intrinsic_gas: u64
    ) -> TransactionResult {
        // Charge the cost of intrinsic gas - which has been verified to be <= gas_limit.
        let block_base_fee = self.snapshot_deref().Kakarot_base_fee.read();
        let gas_price = tx.effective_gas_price(Option::Some(block_base_fee.into()));
        let gas_left = tx.gas_limit() - intrinsic_gas;
        let mut env = starknet_backend::get_env(origin.evm, gas_price);

        let mut sender_account = env.state.get_account(origin.evm);
        sender_account.set_nonce(sender_account.nonce() + 1);
        env.state.set_account(sender_account);

        // Handle deploy/non-deploy transaction cases
        let (to, is_deploy_tx, code, code_address, calldata) = match tx.kind() {
            TxKind::Create => {
                // Deploy tx case.
                let mut origin_nonce: u64 = get_tx_info().unbox().nonce.try_into().unwrap();
                let to_evm_address = compute_contract_address(origin.evm, origin_nonce);
                let to_starknet_address = self.compute_starknet_address(to_evm_address);
                let to = Address { evm: to_evm_address, starknet: to_starknet_address };
                let code = tx.input();
                let calldata = [].span();
                (to, true, code, Zero::zero(), calldata)
            },
            TxKind::Call(to) => {
                let target_starknet_address = self.compute_starknet_address(to);
                let to = Address { evm: to, starknet: target_starknet_address };
                let code = env.state.get_account(to.evm).code;
                (to, false, code, to, tx.input())
            }
        };

        let mut accessed_addresses: Set<EthAddress> = Default::default();
        accessed_addresses.add(env.coinbase);
        accessed_addresses.add(to.evm);
        accessed_addresses.add(origin.evm);
        accessed_addresses.extend(eth_precompile_addresses().spanset());

        let mut accessed_storage_keys: Set<(EthAddress, u256)> = Default::default();

        if let Option::Some(mut access_list) = tx.access_list() {
            for access_list_item in access_list {
                let AccessListItem { ethereum_address, storage_keys: _ } = *access_list_item;
                let storage_keys = access_list_item.to_storage_keys();
                accessed_addresses.add(ethereum_address);
                accessed_storage_keys.extend_from_span(storage_keys);
            }
        };

        let message = Message {
            caller: origin,
            target: to,
            gas_limit: gas_left,
            data: calldata,
            code,
            code_address: code_address,
            value: tx.value(),
            should_transfer_value: true,
            depth: 0,
            read_only: false,
            accessed_addresses: accessed_addresses.spanset(),
            accessed_storage_keys: accessed_storage_keys.spanset(),
        };
        let mut summary = Self::process_message_call(message, env, is_deploy_tx);

        // Gas refunds
        let gas_used = tx.gas_limit() - summary.gas_left;
        let gas_refund = core::cmp::min(gas_used / 5, summary.gas_refund);

        // Charging gas fees to the sender
        // At the end of the tx, the sender must have paid
        // (gas_used - gas_refund) * gas_price to the miner
        // Because tx.gas_price == env.gas_price, and we checked the sender has enough balance
        // to cover the gas fees + the value transfer, this transfer should never fail.
        // We can thus directly charge the sender for the effective gas fees,
        // without pre-emtively charging for the tx gas fee and then refund.
        // This is not true for EIP-1559 transactions - not supported yet.
        let total_gas_used = gas_used - gas_refund;
        let _transaction_fee = total_gas_used.into() * gas_price;

        //TODO(gas): EF-tests doesn't yet support in-EVM gas charging, they assume that the gas
        //charged is always correct for now.
        // As correct gas accounting is not an immediate priority, we can just ignore the gas
        // charging for now.
        // match summary
        //     .state
        //     .add_transfer(
        //         Transfer {
        //             sender: origin,
        //             recipient: Address {
        //                 evm: coinbase, starknet: block_info.sequencer_address,
        //             },
        //             amount: transaction_fee.into()
        //         }
        //     ) {
        //     Result::Ok(_) => {},
        //     Result::Err(err) => {
        //
        //         return TransactionResultTrait::exceptional_failure(
        //             err.to_bytes(), tx.gas_limit()
        //         );
        //     }
        // };

        TransactionResult {
            success: summary.is_success(),
            return_data: summary.return_data,
            gas_used: total_gas_used,
            state: summary.state,
        }
    }


    fn process_message_call(
        message: Message, mut env: Environment, is_deploy_tx: bool,
    ) -> ExecutionSummary {
        let mut target_account = env.state.get_account(message.target.evm);
        let result = if is_deploy_tx {
            // Check collision
            if target_account.has_code_or_nonce() {
                return ExecutionSummaryTrait::exceptional_failure(
                    EVMError::DeployError(CONTRACT_ACCOUNT_EXISTS).to_bytes(),
                );
            }

            let mut result = Self::process_create_message(message, ref env);
            if result.is_success() {
                result.return_data = message.target.evm.to_bytes().span();
            }
            result
        } else {
            Self::process_message(message, ref env)
        };

        // No need to take snapshot of state, as the state is still empty at this point.
        ExecutionSummary {
            status: result.status,
            state: env.state,
            return_data: result.return_data,
            gas_left: result.gas_left,
            gas_refund: result.gas_refund
        }
    }

    fn process_create_message(message: Message, ref env: Environment) -> ExecutionResult {
        //TODO(optimization) - Since the effects of executed code are
        //reverted in the `process_message` function already,
        // we only need to revert the changes made to the target account.  Take a
        // snapshot of the environment state so that we can revert if the
        let state_snapshot = env.state.clone();
        let target_evm_address = message.target.evm;

        //@dev: Adding a scope block around `target_account` to ensure that the same instance is not
        //being accessed after the state has been modified in `process_message`.
        {
            let mut target_account = env.state.get_account(target_evm_address);
            // Increment nonce of target
            target_account.set_nonce(1);
            // Set the target as created
            target_account.set_created(true);
            target_account.address = message.target;
            env.state.set_account(target_account);
        }

        let mut result = Self::process_message(message, ref env);
        if result.is_success() {
            // Write the return_data of the initcode
            // as the deployed contract's bytecode and charge gas
            let target_account = env.state.get_account(target_evm_address);
            match result.finalize_creation(target_account) {
                Result::Ok(account_created) => { env.state.set_account(account_created) },
                Result::Err(err) => {
                    env.state = state_snapshot;
                    result.return_data = [].span();
                    return ExecutionResultTrait::exceptional_failure(
                        err.to_bytes(), result.accessed_addresses, result.accessed_storage_keys
                    );
                }
            };
        } else {
            // Revert state to the snapshot taken before the create processing.
            env.state = state_snapshot;
        }
        result
    }

    fn process_message(message: Message, ref env: Environment) -> ExecutionResult {
        if (message.depth > constants::STACK_MAX_DEPTH) {
            // Because the failure happens before any modification to warm address/storage,
            // we can pass an empty set

            return ExecutionResultTrait::exceptional_failure(
                EVMError::DepthLimit.to_bytes(), Default::default(), Default::default()
            );
        }

        let state_snapshot = env.state.clone();
        if message.should_transfer_value && message.value != 0 {
            let transfer = Transfer {
                sender: message.caller, recipient: message.target, amount: message.value
            };
            match env.state.add_transfer(transfer) {
                Result::Ok(_) => {},
                Result::Err(err) => {
                    return ExecutionResultTrait::exceptional_failure(
                        err.to_bytes(), Default::default(), Default::default()
                    );
                }
            }
        }

        // Instantiate a new VM using the message to process and the current environment.
        let mut vm: VM = VMTrait::new(message, env);

        // Decode and execute the current opcode.
        // until we have processed all opcodes or until we have stopped.
        // Use a recursive function to allow passing VM by ref - which wouldn't work in a loop;
        let result = Self::execute_code(ref vm);

        // Retrieve ownership of the `env` variable
        // The state in the environment has been modified by the VM.
        env = vm.env;

        if !result.is_success() {
            // The `process_message` function has mutated the environment state.
            // Revert state changes using the old snapshot as execution failed.

            env.state = state_snapshot;
        }

        result
    }

    fn execute_code(ref vm: VM) -> ExecutionResult {
        // Handle precompile logic
        if vm.message.code_address.evm.is_precompile() {
            let result = Precompiles::exec_precompile(ref vm);

            match result {
                Result::Ok(_) => {
                    let status = if vm.is_error() {
                        ExecutionResultStatus::Revert
                    } else {
                        ExecutionResultStatus::Success
                    };
                    return ExecutionResult {
                        status,
                        return_data: vm.return_data(),
                        gas_left: vm.gas_left(),
                        accessed_addresses: vm.accessed_addresses(),
                        accessed_storage_keys: vm.accessed_storage_keys(),
                        gas_refund: vm.gas_refund()
                    };
                },
                Result::Err(error) => {
                    // If an error occurred, revert execution self.
                    // Currently, revert reason is a Span<u8>.
                    return ExecutionResultTrait::exceptional_failure(
                        error.to_bytes(), vm.accessed_addresses(), vm.accessed_storage_keys()
                    );
                }
            }
        }

        // Retrieve the current program counter.
        let pc = vm.pc();
        let bytecode = vm.message().code;

        // If PC is out of bounds, stop the VM
        // Also empties the returndata - akin to executing the STOP opcode.
        if pc >= bytecode.len() {
            vm.exec_stop();
        }

        if !vm.is_running() {
            // REVERT opcode case
            if vm.is_error() {
                return ExecutionResult {
                    status: ExecutionResultStatus::Revert,
                    return_data: vm.return_data(),
                    gas_left: vm.gas_left(),
                    accessed_addresses: vm.accessed_addresses(),
                    accessed_storage_keys: vm.accessed_storage_keys(),
                    gas_refund: 0
                };
            };
            // Success case
            return ExecutionResult {
                status: ExecutionResultStatus::Success,
                return_data: vm.return_data(),
                gas_left: vm.gas_left(),
                accessed_addresses: vm.accessed_addresses(),
                accessed_storage_keys: vm.accessed_storage_keys(),
                gas_refund: vm.gas_refund()
            };
        }

        let opcode: u8 = *bytecode.at(pc);
        // Increment pc
        vm.set_pc(pc + 1);

        match Self::execute_opcode(ref vm, opcode) {
            Result::Ok(_) => {
                if vm.is_running() {
                    return Self::execute_code(ref vm);
                }
                // REVERT opcode case
                if vm.is_error() {
                    return ExecutionResult {
                        status: ExecutionResultStatus::Revert,
                        return_data: vm.return_data(),
                        gas_left: vm.gas_left(),
                        accessed_addresses: vm.accessed_addresses(),
                        accessed_storage_keys: vm.accessed_storage_keys(),
                        gas_refund: 0
                    };
                };
                // Success case
                return ExecutionResult {
                    status: ExecutionResultStatus::Success,
                    return_data: vm.return_data(),
                    gas_left: vm.gas_left(),
                    accessed_addresses: vm.accessed_addresses(),
                    accessed_storage_keys: vm.accessed_storage_keys(),
                    gas_refund: vm.gas_refund()
                };
            },
            Result::Err(error) => {
                // If an error occurred, revert execution self.
                // Currently, revert reason is a Span<u8>.
                return ExecutionResultTrait::exceptional_failure(
                    error.to_bytes(), vm.accessed_addresses(), vm.accessed_storage_keys()
                );
            }
        }
    }

    fn execute_opcode(ref self: VM, opcode: u8) -> Result<(), EVMError> {
        // Call the appropriate function based on the opcode.
        if opcode == 0x00 {
            // STOP
            return Result::Ok(self.exec_stop());
        }
        if opcode == 0x01 {
            // ADD
            return self.exec_add();
        }
        if opcode == 0x02 {
            // MUL
            return self.exec_mul();
        }
        if opcode == 0x03 {
            // SUB
            return self.exec_sub();
        }
        if opcode == 0x04 {
            // DIV
            return self.exec_div();
        }
        if opcode == 0x05 {
            // SDIV
            return self.exec_sdiv();
        }
        if opcode == 0x06 {
            // MOD
            return self.exec_mod();
        }
        if opcode == 0x07 {
            // SMOD
            return self.exec_smod();
        }
        if opcode == 0x08 {
            // ADDMOD
            return self.exec_addmod();
        }
        if opcode == 0x09 {
            // MULMOD
            return self.exec_mulmod();
        }
        if opcode == 0x0A {
            // EXP
            return self.exec_exp();
        }
        if opcode == 0x0B {
            // SIGNEXTEND
            return self.exec_signextend();
        }
        if opcode == 0x10 {
            // LT
            return self.exec_lt();
        }
        if opcode == 0x11 {
            // GT
            return self.exec_gt();
        }
        if opcode == 0x12 {
            // SLT
            return self.exec_slt();
        }
        if opcode == 0x13 {
            // SGT
            return self.exec_sgt();
        }
        if opcode == 0x14 {
            // EQ
            return self.exec_eq();
        }
        if opcode == 0x15 {
            // ISZERO
            return self.exec_iszero();
        }
        if opcode == 0x16 {
            // AND
            return self.exec_and();
        }
        if opcode == 0x17 {
            // OR
            return self.exec_or();
        }
        if opcode == 0x18 {
            // XOR
            return self.exec_xor();
        }
        if opcode == 0x19 {
            // NOT
            return self.exec_not();
        }
        if opcode == 0x1A {
            // BYTE
            return self.exec_byte();
        }
        if opcode == 0x1B {
            // SHL
            return self.exec_shl();
        }
        if opcode == 0x1C {
            // SHR
            return self.exec_shr();
        }
        if opcode == 0x1D {
            // SAR
            return self.exec_sar();
        }
        if opcode == 0x20 {
            // KECCAK256
            return self.exec_sha3();
        }
        if opcode == 0x30 {
            // ADDRESS
            return self.exec_address();
        }
        if opcode == 0x31 {
            // BALANCE
            return self.exec_balance();
        }
        if opcode == 0x32 {
            // ORIGIN
            return self.exec_origin();
        }
        if opcode == 0x33 {
            // CALLER
            return self.exec_caller();
        }
        if opcode == 0x34 {
            // CALLVALUE
            return self.exec_callvalue();
        }
        if opcode == 0x35 {
            // CALLDATALOAD
            return self.exec_calldataload();
        }
        if opcode == 0x36 {
            // CALLDATASIZE
            return self.exec_calldatasize();
        }
        if opcode == 0x37 {
            // CALLDATACOPY
            return self.exec_calldatacopy();
        }
        if opcode == 0x38 {
            // CODESIZE
            return self.exec_codesize();
        }
        if opcode == 0x39 {
            // CODECOPY
            return self.exec_codecopy();
        }
        if opcode == 0x3A {
            // GASPRICE
            return self.exec_gasprice();
        }
        if opcode == 0x3B {
            // EXTCODESIZE
            return self.exec_extcodesize();
        }
        if opcode == 0x3C {
            // EXTCODECOPY
            return self.exec_extcodecopy();
        }
        if opcode == 0x3D {
            // RETURNDATASIZE
            return self.exec_returndatasize();
        }
        if opcode == 0x3E {
            // RETURNDATACOPY
            return self.exec_returndatacopy();
        }
        if opcode == 0x3F {
            // EXTCODEHASH
            return self.exec_extcodehash();
        }
        if opcode == 0x40 {
            // BLOCKHASH
            return self.exec_blockhash();
        }
        if opcode == 0x41 {
            // COINBASE
            return self.exec_coinbase();
        }
        if opcode == 0x42 {
            // TIMESTAMP
            return self.exec_timestamp();
        }
        if opcode == 0x43 {
            // NUMBER
            return self.exec_number();
        }
        if opcode == 0x44 {
            // PREVRANDAO
            return self.exec_prevrandao();
        }
        if opcode == 0x45 {
            // GASLIMIT
            return self.exec_gaslimit();
        }
        if opcode == 0x46 {
            // CHAINID
            return self.exec_chainid();
        }
        if opcode == 0x47 {
            // SELFBALANCE
            return self.exec_selfbalance();
        }
        if opcode == 0x48 {
            // BASEFEE
            return self.exec_basefee();
        }
        if opcode == 0x49 {
            // BLOBHASH
            return self.exec_blobhash();
        }
        if opcode == 0x4A {
            // BLOBBASEFEE
            return self.exec_blobbasefee();
        }
        if opcode == 0x50 {
            // POP
            return self.exec_pop();
        }
        if opcode == 0x51 {
            // MLOAD
            return self.exec_mload();
        }
        if opcode == 0x52 {
            // MSTORE
            return self.exec_mstore();
        }
        if opcode == 0x53 {
            // MSTORE8
            return self.exec_mstore8();
        }
        if opcode == 0x54 {
            // SLOAD
            return self.exec_sload();
        }
        if opcode == 0x55 {
            // SSTORE
            return self.exec_sstore();
        }
        if opcode == 0x56 {
            // JUMP
            return self.exec_jump();
        }
        if opcode == 0x57 {
            // JUMPI
            return self.exec_jumpi();
        }
        if opcode == 0x58 {
            // PC
            return self.exec_pc();
        }
        if opcode == 0x59 {
            // MSIZE
            return self.exec_msize();
        }
        if opcode == 0x5A {
            // GAS
            return self.exec_gas();
        }
        if opcode == 0x5B {
            // JUMPDEST
            return self.exec_jumpdest();
        }
        if opcode == 0x5C {
            // TLOAD
            return self.exec_tload();
        }
        if opcode == 0x5D {
            // TSTORE
            return self.exec_tstore();
        }
        if opcode == 0x5E {
            // MCOPY
            return self.exec_mcopy();
        }
        if opcode == 0x5F {
            // PUSH0
            return self.exec_push0();
        }
        if opcode == 0x60 {
            // PUSH1
            return self.exec_push1();
        }
        if opcode == 0x61 {
            // PUSH2
            return self.exec_push2();
        }
        if opcode == 0x62 {
            // PUSH3
            return self.exec_push3();
        }
        if opcode == 0x63 {
            // PUSH4
            return self.exec_push4();
        }
        if opcode == 0x64 {
            // PUSH5
            return self.exec_push5();
        }
        if opcode == 0x65 {
            // PUSH6
            return self.exec_push6();
        }
        if opcode == 0x66 {
            // PUSH7
            return self.exec_push7();
        }
        if opcode == 0x67 {
            // PUSH8
            return self.exec_push8();
        }
        if opcode == 0x68 {
            // PUSH9
            return self.exec_push9();
        }
        if opcode == 0x69 {
            // PUSH10
            return self.exec_push10();
        }
        if opcode == 0x6A {
            // PUSH11
            return self.exec_push11();
        }
        if opcode == 0x6B {
            // PUSH12
            return self.exec_push12();
        }
        if opcode == 0x6C {
            // PUSH13
            return self.exec_push13();
        }
        if opcode == 0x6D {
            // PUSH14
            return self.exec_push14();
        }
        if opcode == 0x6E {
            // PUSH15
            return self.exec_push15();
        }
        if opcode == 0x6F {
            // PUSH16
            return self.exec_push16();
        }
        if opcode == 0x70 {
            // PUSH17
            return self.exec_push17();
        }
        if opcode == 0x71 {
            // PUSH18
            return self.exec_push18();
        }
        if opcode == 0x72 {
            // PUSH19
            return self.exec_push19();
        }
        if opcode == 0x73 {
            // PUSH20
            return self.exec_push20();
        }
        if opcode == 0x74 {
            // PUSH21
            return self.exec_push21();
        }
        if opcode == 0x75 {
            // PUSH22
            return self.exec_push22();
        }
        if opcode == 0x76 {
            // PUSH23
            return self.exec_push23();
        }
        if opcode == 0x77 {
            // PUSH24
            return self.exec_push24();
        }
        if opcode == 0x78 {
            // PUSH25
            return self.exec_push25();
        }
        if opcode == 0x79 {
            // PUSH26
            return self.exec_push26();
        }
        if opcode == 0x7A {
            // PUSH27
            return self.exec_push27();
        }
        if opcode == 0x7B {
            // PUSH28
            return self.exec_push28();
        }
        if opcode == 0x7C {
            // PUSH29
            return self.exec_push29();
        }
        if opcode == 0x7D {
            // PUSH30
            return self.exec_push30();
        }
        if opcode == 0x7E {
            // PUSH31
            return self.exec_push31();
        }
        if opcode == 0x7F {
            // PUSH32
            return self.exec_push32();
        }
        if opcode == 0x80 {
            // DUP1
            return self.exec_dup1();
        }
        if opcode == 0x81 {
            // DUP2
            return self.exec_dup2();
        }
        if opcode == 0x82 {
            // DUP3
            return self.exec_dup3();
        }
        if opcode == 0x83 {
            // DUP4
            return self.exec_dup4();
        }
        if opcode == 0x84 {
            // DUP5
            return self.exec_dup5();
        }
        if opcode == 0x85 {
            // DUP6
            return self.exec_dup6();
        }
        if opcode == 0x86 {
            // DUP7
            return self.exec_dup7();
        }
        if opcode == 0x87 {
            // DUP8
            return self.exec_dup8();
        }
        if opcode == 0x88 {
            // DUP9
            return self.exec_dup9();
        }
        if opcode == 0x89 {
            // DUP10
            return self.exec_dup10();
        }
        if opcode == 0x8A {
            // DUP11
            return self.exec_dup11();
        }
        if opcode == 0x8B {
            // DUP12
            return self.exec_dup12();
        }
        if opcode == 0x8C {
            // DUP13
            return self.exec_dup13();
        }
        if opcode == 0x8D {
            // DUP14
            return self.exec_dup14();
        }
        if opcode == 0x8E {
            // DUP15
            return self.exec_dup15();
        }
        if opcode == 0x8F {
            // DUP16
            return self.exec_dup16();
        }
        if opcode == 0x90 {
            // SWAP1
            return self.exec_swap1();
        }
        if opcode == 0x91 {
            // SWAP2
            return self.exec_swap2();
        }
        if opcode == 0x92 {
            // SWAP3
            return self.exec_swap3();
        }
        if opcode == 0x93 {
            // SWAP4
            return self.exec_swap4();
        }
        if opcode == 0x94 {
            // SWAP5
            return self.exec_swap5();
        }
        if opcode == 0x95 {
            // SWAP6
            return self.exec_swap6();
        }
        if opcode == 0x96 {
            // SWAP7
            return self.exec_swap7();
        }
        if opcode == 0x97 {
            // SWAP8
            return self.exec_swap8();
        }
        if opcode == 0x98 {
            // SWAP9
            return self.exec_swap9();
        }
        if opcode == 0x99 {
            // SWAP10
            return self.exec_swap10();
        }
        if opcode == 0x9A {
            // SWAP11
            return self.exec_swap11();
        }
        if opcode == 0x9B {
            // SWAP12
            return self.exec_swap12();
        }
        if opcode == 0x9C {
            // SWAP13
            return self.exec_swap13();
        }
        if opcode == 0x9D {
            // SWAP14
            return self.exec_swap14();
        }
        if opcode == 0x9E {
            // SWAP15
            return self.exec_swap15();
        }
        if opcode == 0x9F {
            // SWAP16
            return self.exec_swap16();
        }
        if opcode == 0xA0 {
            // LOG0
            return self.exec_log0();
        }
        if opcode == 0xA1 {
            // LOG1
            return self.exec_log1();
        }
        if opcode == 0xA2 {
            // LOG2
            return self.exec_log2();
        }
        if opcode == 0xA3 {
            // LOG3
            return self.exec_log3();
        }
        if opcode == 0xA4 {
            // LOG4
            return self.exec_log4();
        }
        if opcode == 0xF0 {
            // CREATE
            return self.exec_create();
        }
        if opcode == 0xF1 {
            // CALL
            return self.exec_call();
        }
        if opcode == 0xF2 {
            // CALLCODE
            return self.exec_callcode();
        }
        if opcode == 0xF3 {
            // RETURN
            return self.exec_return();
        }
        if opcode == 0xF4 {
            // DELEGATECALL
            return self.exec_delegatecall();
        }
        if opcode == 0xF5 {
            // CREATE2
            return self.exec_create2();
        }
        if opcode == 0xFA {
            // STATICCALL
            return self.exec_staticcall();
        }
        if opcode == 0xFD {
            // REVERT
            return self.exec_revert();
        }
        if opcode == 0xFE {
            // INVALID
            return self.exec_invalid();
        }
        if opcode == 0xFF {
            // SELFDESTRUCT
            return self.exec_selfdestruct();
        }
        // Unknown opcode
        return Result::Err(EVMError::InvalidOpcode(opcode));
    }
}
