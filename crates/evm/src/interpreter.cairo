use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;
use core::num::traits::Zero;
use core::ops::SnapshotDeref;
use core::starknet::EthAddress;
use core::starknet::storage::{StoragePointerReadAccess};
use crate::backend::starknet_backend;
use crate::create_helpers::CreateHelpers;
use crate::errors::{EVMError, EVMErrorTrait};

use crate::instructions::{
    ExchangeOperationsTrait, LoggingOperationsTrait, StopAndArithmeticOperationsTrait,
    ComparisonAndBitwiseOperationsTrait, SystemOperationsTrait, BlockInformationTrait,
    DuplicationOperationsTrait, EnvironmentInformationTrait, PushOperationsTrait,
    MemoryOperationTrait, Sha3Trait
};

use crate::model::account::{Account, AccountTrait};
use crate::model::vm::{VM, VMTrait};
use crate::model::{
    Message, Environment, Transfer, ExecutionSummary, ExecutionResult, ExecutionResultTrait,
    ExecutionResultStatus, AddressTrait, TransactionResult, Address
};
use crate::precompiles::Precompiles;
use crate::precompiles::eth_precompile_addresses;
use crate::state::StateTrait;
use utils::address::compute_contract_address;
use utils::constants;
use utils::eth_transaction::common::TxKind;
use utils::eth_transaction::eip2930::{AccessListItem, AccessListItemTrait};
use utils::eth_transaction::transaction::{Transaction, TransactionTrait};
use utils::set::{Set, SetTrait};
use utils::traits::eth_address::EthAddressExTrait;

#[generate_trait]
pub impl EVMImpl of EVMTrait {
    fn prepare_message(
        self: @KakarotCore::ContractState,
        tx: @Transaction,
        sender_account: @Account,
        ref env: Environment,
        gas_left: u64
    ) -> (Message, bool) {
        let (to, is_deploy_tx, code, code_address, calldata) = match tx.kind() {
            TxKind::Create => {
                let origin_nonce: u64 = sender_account.nonce();
                let to_evm_address = compute_contract_address(
                    sender_account.address().evm, origin_nonce
                );
                let to_starknet_address = self.compute_starknet_address(to_evm_address);
                let to = Address { evm: to_evm_address, starknet: to_starknet_address };
                (to, true, tx.input(), Zero::zero(), [].span())
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
        accessed_addresses.add(env.origin.evm);
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
            caller: env.origin,
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

        (message, is_deploy_tx)
    }

    fn process_transaction(
        ref self: KakarotCore::ContractState, origin: Address, tx: Transaction, intrinsic_gas: u64
    ) -> TransactionResult {
        // Charge the cost of intrinsic gas - which has been verified to be <= gas_limit.
        let block_base_fee = self.snapshot_deref().Kakarot_base_fee.read();
        let gas_price = tx.effective_gas_price(Option::Some(block_base_fee.into()));
        let gas_left = tx.gas_limit() - intrinsic_gas;
        let max_fee = tx.gas_limit().into() * gas_price;
        let mut env = starknet_backend::get_env(origin, gas_price);

        let (message, is_deploy_tx) = {
            let mut sender_account = env.state.get_account(origin.evm);

            // Charge the intrinsic gas to the sender so that it's not available for the execution
            // of the transaction but don't trigger any actual transfer, as only the actual consumed
            // gas is charged at the end of the transaction
            sender_account.set_balance(sender_account.balance() - max_fee.into());

            let (message, is_deploy_tx) = self
                .prepare_message(@tx, @sender_account, ref env, gas_left);

            // Increment nonce of sender AFTER computing the created address
            // to use the correct nonce when computing the address.
            sender_account.set_nonce(sender_account.nonce() + 1);

            env.state.set_account(sender_account);
            (message, is_deploy_tx)
        };

        let mut summary = Self::process_message_call(message, env, is_deploy_tx);

        // Cancel the max_fee that was taken from the sender to prevent double charging
        let mut sender_account = summary.state.get_account(origin.evm);
        sender_account.set_balance(sender_account.balance() + max_fee.into());
        summary.state.set_account(sender_account);

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
            success: summary.status == ExecutionResultStatus::Success,
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
                return ExecutionSummary {
                    status: ExecutionResultStatus::Exception,
                    return_data: EVMError::Collision.to_bytes(),
                    gas_left: 0,
                    state: env.state,
                    gas_refund: 0
                };
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

        match Self::execute_opcode(ref vm, opcode) {
            Result::Ok(_) => {
                if opcode != 0x56 && opcode != 0x57 {
                    // Increment pc if not a JUMP family opcode
                    vm.set_pc(vm.pc() + 1);
                }

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
        match opcode {
            0 => // STOP
            Result::Ok(self.exec_stop()),
            1 => // ADD
            self.exec_add(),
            2 => // MUL
            self.exec_mul(),
            3 => // SUB
            self.exec_sub(),
            4 => // DIV
            self.exec_div(),
            5 => // SDIV
            self.exec_sdiv(),
            6 => // MOD
            self.exec_mod(),
            7 => // SMOD
            self.exec_smod(),
            8 => // ADDMOD
            self.exec_addmod(),
            9 => // MULMOD
            self.exec_mulmod(),
            10 => // EXP
            self.exec_exp(),
            11 => // SIGNEXTEND
            self.exec_signextend(),
            12 => Result::Err(EVMError::InvalidOpcode(opcode)),
            13 => Result::Err(EVMError::InvalidOpcode(opcode)),
            14 => Result::Err(EVMError::InvalidOpcode(opcode)),
            15 => Result::Err(EVMError::InvalidOpcode(opcode)),
            16 => // LT
            self.exec_lt(),
            17 => // GT
            self.exec_gt(),
            18 => // SLT
            self.exec_slt(),
            19 => // SGT
            self.exec_sgt(),
            20 => // EQ
            self.exec_eq(),
            21 => // ISZERO
            self.exec_iszero(),
            22 => // AND
            self.exec_and(),
            23 => // OR
            self.exec_or(),
            24 => // XOR
            self.exec_xor(),
            25 => // NOT
            self.exec_not(),
            26 => // BYTE
            self.exec_byte(),
            27 => // SHL
            self.exec_shl(),
            28 => // SHR
            self.exec_shr(),
            29 => // SAR
            self.exec_sar(),
            30 => Result::Err(EVMError::InvalidOpcode(opcode)),
            31 => Result::Err(EVMError::InvalidOpcode(opcode)),
            32 => // KECCAK256
            self.exec_sha3(),
            33 => Result::Err(EVMError::InvalidOpcode(opcode)),
            34 => Result::Err(EVMError::InvalidOpcode(opcode)),
            35 => Result::Err(EVMError::InvalidOpcode(opcode)),
            36 => Result::Err(EVMError::InvalidOpcode(opcode)),
            37 => Result::Err(EVMError::InvalidOpcode(opcode)),
            38 => Result::Err(EVMError::InvalidOpcode(opcode)),
            39 => Result::Err(EVMError::InvalidOpcode(opcode)),
            40 => Result::Err(EVMError::InvalidOpcode(opcode)),
            41 => Result::Err(EVMError::InvalidOpcode(opcode)),
            42 => Result::Err(EVMError::InvalidOpcode(opcode)),
            43 => Result::Err(EVMError::InvalidOpcode(opcode)),
            44 => Result::Err(EVMError::InvalidOpcode(opcode)),
            45 => Result::Err(EVMError::InvalidOpcode(opcode)),
            46 => Result::Err(EVMError::InvalidOpcode(opcode)),
            47 => Result::Err(EVMError::InvalidOpcode(opcode)),
            48 => // ADDRESS
            self.exec_address(),
            49 => // BALANCE
            self.exec_balance(),
            50 => // ORIGIN
            self.exec_origin(),
            51 => // CALLER
            self.exec_caller(),
            52 => // CALLVALUE
            self.exec_callvalue(),
            53 => // CALLDATALOAD
            self.exec_calldataload(),
            54 => // CALLDATASIZE
            self.exec_calldatasize(),
            55 => // CALLDATACOPY
            self.exec_calldatacopy(),
            56 => // CODESIZE
            self.exec_codesize(),
            57 => // CODECOPY
            self.exec_codecopy(),
            58 => // GASPRICE
            self.exec_gasprice(),
            59 => // EXTCODESIZE
            self.exec_extcodesize(),
            60 => // EXTCODECOPY
            self.exec_extcodecopy(),
            61 => // RETURNDATASIZE
            self.exec_returndatasize(),
            62 => // RETURNDATACOPY
            self.exec_returndatacopy(),
            63 => // EXTCODEHASH
            self.exec_extcodehash(),
            64 => // BLOCKHASH
            self.exec_blockhash(),
            65 => // COINBASE
            self.exec_coinbase(),
            66 => // TIMESTAMP
            self.exec_timestamp(),
            67 => // NUMBER
            self.exec_number(),
            68 => // PREVRANDAO
            self.exec_prevrandao(),
            69 => // GASLIMIT
            self.exec_gaslimit(),
            70 => // CHAINID
            self.exec_chainid(),
            71 => // SELFBALANCE
            self.exec_selfbalance(),
            72 => // BASEFEE
            self.exec_basefee(),
            73 => // BLOBHASH
            self.exec_blobhash(),
            74 => // BLOBBASEFEE
            self.exec_blobbasefee(),
            75 => Result::Err(EVMError::InvalidOpcode(opcode)),
            76 => Result::Err(EVMError::InvalidOpcode(opcode)),
            77 => Result::Err(EVMError::InvalidOpcode(opcode)),
            78 => Result::Err(EVMError::InvalidOpcode(opcode)),
            79 => Result::Err(EVMError::InvalidOpcode(opcode)),
            80 => // POP
            self.exec_pop(),
            81 => // MLOAD
            self.exec_mload(),
            82 => // MSTORE
            self.exec_mstore(),
            83 => // MSTORE8
            self.exec_mstore8(),
            84 => // SLOAD
            self.exec_sload(),
            85 => // SSTORE
            self.exec_sstore(),
            86 => // JUMP
            self.exec_jump(),
            87 => // JUMPI
            self.exec_jumpi(),
            88 => // PC
            self.exec_pc(),
            89 => // MSIZE
            self.exec_msize(),
            90 => // GAS
            self.exec_gas(),
            91 => // JUMPDEST
            self.exec_jumpdest(),
            92 => // TLOAD
            self.exec_tload(),
            93 => // TSTORE
            self.exec_tstore(),
            94 => // MCOPY
            self.exec_mcopy(),
            95 => // PUSH0
            self.exec_push0(),
            96 => // PUSH1
            self.exec_push1(),
            97 => // PUSH2
            self.exec_push2(),
            98 => // PUSH3
            self.exec_push3(),
            99 => // PUSH4
            self.exec_push4(),
            100 => // PUSH5
            self.exec_push5(),
            101 => // PUSH6
            self.exec_push6(),
            102 => // PUSH7
            self.exec_push7(),
            103 => // PUSH8
            self.exec_push8(),
            104 => // PUSH9
            self.exec_push9(),
            105 => // PUSH10
            self.exec_push10(),
            106 => // PUSH11
            self.exec_push11(),
            107 => // PUSH12
            self.exec_push12(),
            108 => // PUSH13
            self.exec_push13(),
            109 => // PUSH14
            self.exec_push14(),
            110 => // PUSH15
            self.exec_push15(),
            111 => // PUSH16
            self.exec_push16(),
            112 => // PUSH17
            self.exec_push17(),
            113 => // PUSH18
            self.exec_push18(),
            114 => // PUSH19
            self.exec_push19(),
            115 => // PUSH20
            self.exec_push20(),
            116 => // PUSH21
            self.exec_push21(),
            117 => // PUSH22
            self.exec_push22(),
            118 => // PUSH23
            self.exec_push23(),
            119 => // PUSH24
            self.exec_push24(),
            120 => // PUSH25
            self.exec_push25(),
            121 => // PUSH26
            self.exec_push26(),
            122 => // PUSH27
            self.exec_push27(),
            123 => // PUSH28
            self.exec_push28(),
            124 => // PUSH29
            self.exec_push29(),
            125 => // PUSH30
            self.exec_push30(),
            126 => // PUSH31
            self.exec_push31(),
            127 => // PUSH32
            self.exec_push32(),
            128 => // DUP1
            self.exec_dup1(),
            129 => // DUP2
            self.exec_dup2(),
            130 => // DUP3
            self.exec_dup3(),
            131 => // DUP4
            self.exec_dup4(),
            132 => // DUP5
            self.exec_dup5(),
            133 => // DUP6
            self.exec_dup6(),
            134 => // DUP7
            self.exec_dup7(),
            135 => // DUP8
            self.exec_dup8(),
            136 => // DUP9
            self.exec_dup9(),
            137 => // DUP10
            self.exec_dup10(),
            138 => // DUP11
            self.exec_dup11(),
            139 => // DUP12
            self.exec_dup12(),
            140 => // DUP13
            self.exec_dup13(),
            141 => // DUP14
            self.exec_dup14(),
            142 => // DUP15
            self.exec_dup15(),
            143 => // DUP16
            self.exec_dup16(),
            144 => // SWAP1
            self.exec_swap1(),
            145 => // SWAP2
            self.exec_swap2(),
            146 => // SWAP3
            self.exec_swap3(),
            147 => // SWAP4
            self.exec_swap4(),
            148 => // SWAP5
            self.exec_swap5(),
            149 => // SWAP6
            self.exec_swap6(),
            150 => // SWAP7
            self.exec_swap7(),
            151 => // SWAP8
            self.exec_swap8(),
            152 => // SWAP9
            self.exec_swap9(),
            153 => // SWAP10
            self.exec_swap10(),
            154 => // SWAP11
            self.exec_swap11(),
            155 => // SWAP12
            self.exec_swap12(),
            156 => // SWAP13
            self.exec_swap13(),
            157 => // SWAP14
            self.exec_swap14(),
            158 => // SWAP15
            self.exec_swap15(),
            159 => // SWAP16
            self.exec_swap16(),
            160 => // LOG0
            self.exec_log0(),
            161 => // LOG1
            self.exec_log1(),
            162 => // LOG2
            self.exec_log2(),
            163 => // LOG3
            self.exec_log3(),
            164 => // LOG4
            self.exec_log4(),
            165 => Result::Err(EVMError::InvalidOpcode(opcode)),
            166 => Result::Err(EVMError::InvalidOpcode(opcode)),
            167 => Result::Err(EVMError::InvalidOpcode(opcode)),
            168 => Result::Err(EVMError::InvalidOpcode(opcode)),
            169 => Result::Err(EVMError::InvalidOpcode(opcode)),
            170 => Result::Err(EVMError::InvalidOpcode(opcode)),
            171 => Result::Err(EVMError::InvalidOpcode(opcode)),
            172 => Result::Err(EVMError::InvalidOpcode(opcode)),
            173 => Result::Err(EVMError::InvalidOpcode(opcode)),
            174 => Result::Err(EVMError::InvalidOpcode(opcode)),
            175 => Result::Err(EVMError::InvalidOpcode(opcode)),
            176 => Result::Err(EVMError::InvalidOpcode(opcode)),
            177 => Result::Err(EVMError::InvalidOpcode(opcode)),
            178 => Result::Err(EVMError::InvalidOpcode(opcode)),
            179 => Result::Err(EVMError::InvalidOpcode(opcode)),
            180 => Result::Err(EVMError::InvalidOpcode(opcode)),
            181 => Result::Err(EVMError::InvalidOpcode(opcode)),
            182 => Result::Err(EVMError::InvalidOpcode(opcode)),
            183 => Result::Err(EVMError::InvalidOpcode(opcode)),
            184 => Result::Err(EVMError::InvalidOpcode(opcode)),
            185 => Result::Err(EVMError::InvalidOpcode(opcode)),
            186 => Result::Err(EVMError::InvalidOpcode(opcode)),
            187 => Result::Err(EVMError::InvalidOpcode(opcode)),
            188 => Result::Err(EVMError::InvalidOpcode(opcode)),
            189 => Result::Err(EVMError::InvalidOpcode(opcode)),
            190 => Result::Err(EVMError::InvalidOpcode(opcode)),
            191 => Result::Err(EVMError::InvalidOpcode(opcode)),
            192 => Result::Err(EVMError::InvalidOpcode(opcode)),
            193 => Result::Err(EVMError::InvalidOpcode(opcode)),
            194 => Result::Err(EVMError::InvalidOpcode(opcode)),
            195 => Result::Err(EVMError::InvalidOpcode(opcode)),
            196 => Result::Err(EVMError::InvalidOpcode(opcode)),
            197 => Result::Err(EVMError::InvalidOpcode(opcode)),
            198 => Result::Err(EVMError::InvalidOpcode(opcode)),
            199 => Result::Err(EVMError::InvalidOpcode(opcode)),
            200 => Result::Err(EVMError::InvalidOpcode(opcode)),
            201 => Result::Err(EVMError::InvalidOpcode(opcode)),
            202 => Result::Err(EVMError::InvalidOpcode(opcode)),
            203 => Result::Err(EVMError::InvalidOpcode(opcode)),
            204 => Result::Err(EVMError::InvalidOpcode(opcode)),
            205 => Result::Err(EVMError::InvalidOpcode(opcode)),
            206 => Result::Err(EVMError::InvalidOpcode(opcode)),
            207 => Result::Err(EVMError::InvalidOpcode(opcode)),
            208 => Result::Err(EVMError::InvalidOpcode(opcode)),
            209 => Result::Err(EVMError::InvalidOpcode(opcode)),
            210 => Result::Err(EVMError::InvalidOpcode(opcode)),
            211 => Result::Err(EVMError::InvalidOpcode(opcode)),
            212 => Result::Err(EVMError::InvalidOpcode(opcode)),
            213 => Result::Err(EVMError::InvalidOpcode(opcode)),
            214 => Result::Err(EVMError::InvalidOpcode(opcode)),
            215 => Result::Err(EVMError::InvalidOpcode(opcode)),
            216 => Result::Err(EVMError::InvalidOpcode(opcode)),
            217 => Result::Err(EVMError::InvalidOpcode(opcode)),
            218 => Result::Err(EVMError::InvalidOpcode(opcode)),
            219 => Result::Err(EVMError::InvalidOpcode(opcode)),
            220 => Result::Err(EVMError::InvalidOpcode(opcode)),
            221 => Result::Err(EVMError::InvalidOpcode(opcode)),
            222 => Result::Err(EVMError::InvalidOpcode(opcode)),
            223 => Result::Err(EVMError::InvalidOpcode(opcode)),
            224 => Result::Err(EVMError::InvalidOpcode(opcode)),
            225 => Result::Err(EVMError::InvalidOpcode(opcode)),
            226 => Result::Err(EVMError::InvalidOpcode(opcode)),
            227 => Result::Err(EVMError::InvalidOpcode(opcode)),
            228 => Result::Err(EVMError::InvalidOpcode(opcode)),
            229 => Result::Err(EVMError::InvalidOpcode(opcode)),
            230 => Result::Err(EVMError::InvalidOpcode(opcode)),
            231 => Result::Err(EVMError::InvalidOpcode(opcode)),
            232 => Result::Err(EVMError::InvalidOpcode(opcode)),
            233 => Result::Err(EVMError::InvalidOpcode(opcode)),
            234 => Result::Err(EVMError::InvalidOpcode(opcode)),
            235 => Result::Err(EVMError::InvalidOpcode(opcode)),
            236 => Result::Err(EVMError::InvalidOpcode(opcode)),
            237 => Result::Err(EVMError::InvalidOpcode(opcode)),
            238 => Result::Err(EVMError::InvalidOpcode(opcode)),
            239 => Result::Err(EVMError::InvalidOpcode(opcode)),
            240 => // CREATE
            self.exec_create(),
            241 => // CALL
            self.exec_call(),
            242 => // CALLCODE
            self.exec_callcode(),
            243 => // RETURN
            self.exec_return(),
            244 => // DELEGATECALL
            self.exec_delegatecall(),
            245 => // CREATE2
            self.exec_create2(),
            246 => Result::Err(EVMError::InvalidOpcode(opcode)),
            247 => Result::Err(EVMError::InvalidOpcode(opcode)),
            248 => Result::Err(EVMError::InvalidOpcode(opcode)),
            249 => Result::Err(EVMError::InvalidOpcode(opcode)),
            250 => // STATICCALL
            self.exec_staticcall(),
            251 => Result::Err(EVMError::InvalidOpcode(opcode)),
            252 => Result::Err(EVMError::InvalidOpcode(opcode)),
            253 => // REVERT
            self.exec_revert(),
            254 => // INVALID
            self.exec_invalid(),
            255 => // SELFDESTRUCT
            self.exec_selfdestruct(),
            _ => Result::Err(EVMError::InvalidOpcode(opcode)),
        }
    }
}

#[cfg(test)]
mod tests {
    use contracts::kakarot_core::KakarotCore;
    use core::num::traits::Zero;
    use crate::model::{Account, Environment, Message};
    use crate::state::StateTrait;
    use crate::test_utils::{dual_origin, test_dual_address};
    use super::EVMTrait;
    use utils::constants::EMPTY_KECCAK;
    use utils::eth_transaction::common::TxKind;
    use utils::eth_transaction::legacy::TxLegacy;
    use utils::eth_transaction::transaction::{Transaction, TransactionTrait};

    fn setup() -> (KakarotCore::ContractState, Account, Environment) {
        let state = KakarotCore::contract_state_for_testing();
        let sender_account = Account {
            address: test_dual_address(),
            nonce: 5,
            balance: 1000000000000000000_u256, // 1 ETH
            code: array![].span(),
            code_hash: EMPTY_KECCAK,
            selfdestruct: false,
            is_created: true,
        };
        let mut env = Environment {
            origin: dual_origin(),
            gas_price: 20000000000_u128, // 20 Gwei
            chain_id: 1_u64,
            prevrandao: 0_u256,
            block_number: 12345_u64,
            block_gas_limit: 30000000_u64,
            block_timestamp: 1634567890_u64,
            coinbase: 0x0000000000000000000000000000000000000000.try_into().unwrap(),
            base_fee: 0_u64,
            state: Default::default(),
        };
        env.state.set_account(sender_account);
        (state, sender_account, env)
    }

    #[test]
    fn test_prepare_message_create() {
        let (mut state, sender_account, mut env) = setup();
        let tx = Transaction::Legacy(
            TxLegacy {
                chain_id: Option::Some(1),
                nonce: 5,
                gas_price: 20000000000_u128, // 20 Gwei
                gas_limit: 1000000_u64,
                to: TxKind::Create,
                value: 0_u256,
                input: array![0x60, 0x80, 0x60, 0x40, 0x52].span(), // Simple contract bytecode
            }
        );

        let (message, is_deploy_tx) = state
            .prepare_message(@tx, @sender_account, ref env, tx.gas_limit());

        assert_eq!(is_deploy_tx, true);
        assert_eq!(message.code, tx.input());
        assert_eq!(
            message.target.evm, 0xf50541960eec6df5caa295adee1a1a95c3c3241c.try_into().unwrap()
        ); // compute_contract_address('evm_address', 5);
        assert_eq!(message.code_address, Zero::zero());
        assert_eq!(message.data, [].span());
        assert_eq!(message.gas_limit, tx.gas_limit());
        assert_eq!(message.depth, 0);
        assert_eq!(message.should_transfer_value, true);
        assert_eq!(message.value, 0_u256);
    }

    #[test]
    fn test_prepare_message_call() {
        let (mut state, sender_account, mut env) = setup();
        let target_address = sender_account.address;
        let tx = Transaction::Legacy(
            TxLegacy {
                chain_id: Option::Some(1),
                nonce: 5,
                gas_price: 20000000000_u128, // 20 Gwei
                gas_limit: 1000000_u64,
                to: TxKind::Call(target_address.evm),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![0x12, 0x34, 0x56, 0x78].span(), // Some calldata
            }
        );

        let (message, is_deploy_tx) = state
            .prepare_message(@tx, @sender_account, ref env, tx.gas_limit());

        assert_eq!(is_deploy_tx, false);
        assert_eq!(message.target.evm, target_address.evm);
        assert_eq!(message.code_address.evm, target_address.evm);
        assert_eq!(message.code, sender_account.code);
        assert_eq!(message.data, tx.input());
        assert_eq!(message.gas_limit, tx.gas_limit());
        assert_eq!(message.depth, 0);
        assert_eq!(message.should_transfer_value, true);
        assert_eq!(message.value, 1000000000000000000_u256);
    }
}
