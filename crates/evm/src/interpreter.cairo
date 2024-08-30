use evm::create_helpers::CreateHelpers;
use evm::errors::{EVMError, EVMErrorTrait, CONTRACT_ACCOUNT_EXISTS};

use evm::instructions::{
    ExchangeOperationsTrait, LoggingOperationsTrait, StopAndArithmeticOperationsTrait,
    ComparisonAndBitwiseOperationsTrait, SystemOperationsTrait, BlockInformationTrait,
    DuplicationOperationsTrait, EnvironmentInformationTrait, PushOperationsTrait,
    MemoryOperationTrait
};

use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{
    Message, Environment, Address, Transfer, ExecutionSummary, ExecutionSummaryTrait,
    ExecutionResult, ExecutionResultTrait, ExecutionResultStatus, AddressTrait
};
use evm::precompiles::Precompiles;
use evm::state::StateTrait;
use utils::constants;
use utils::helpers::EthAddressExTrait;

#[generate_trait]
pub impl EVMImpl of EVMTrait {
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

        // Check if PC is not out of bounds.
        if pc >= bytecode.len() || vm.is_running() == false {
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
        if opcode == 0 {
            // STOP
            return self.exec_stop();
        }
        if opcode == 1 {
            // ADD
            return self.exec_add();
        }
        if opcode == 2 {
            // MUL
            return self.exec_mul();
        }
        if opcode == 3 {
            // SUB
            return self.exec_sub();
        }
        if opcode == 4 {
            // DIV
            return self.exec_div();
        }
        if opcode == 5 {
            // SDIV
            return self.exec_sdiv();
        }
        if opcode == 6 {
            // MOD
            return self.exec_mod();
        }
        if opcode == 7 {
            // SMOD
            return self.exec_smod();
        }
        if opcode == 8 {
            // ADDMOD
            return self.exec_addmod();
        }
        if opcode == 9 {
            // MULMOD
            return self.exec_mulmod();
        }
        if opcode == 10 {
            // EXP
            return self.exec_exp();
        }
        if opcode == 11 {
            // SIGNEXTEND
            return self.exec_signextend();
        }
        if opcode == 16 {
            // LT
            return self.exec_lt();
        }
        if opcode == 17 {
            // GT
            return self.exec_gt();
        }
        if opcode == 18 {
            // SLT
            return self.exec_slt();
        }
        if opcode == 19 {
            // SGT
            return self.exec_sgt();
        }
        if opcode == 20 {
            // EQ
            return self.exec_eq();
        }
        if opcode == 21 {
            // ISZERO
            return self.exec_iszero();
        }
        if opcode == 22 {
            // AND
            return self.exec_and();
        }
        if opcode == 23 {
            // OR
            return self.exec_or();
        }
        if opcode == 24 {
            // XOR
            return self.exec_xor();
        }
        if opcode == 25 {
            // NOT
            return self.exec_not();
        }
        if opcode == 26 {
            // BYTE
            return self.exec_byte();
        }
        if opcode == 27 {
            // SHL
            return self.exec_shl();
        }
        if opcode == 28 {
            // SHR
            return self.exec_shr();
        }
        if opcode == 29 {
            // SAR
            return self.exec_sar();
        }
        if opcode == 48 {
            // ADDRESS
            return self.exec_address();
        }
        if opcode == 49 {
            // BALANCE
            return self.exec_balance();
        }
        if opcode == 50 {
            // ORIGIN
            return self.exec_origin();
        }
        if opcode == 51 {
            // CALLER
            return self.exec_caller();
        }
        if opcode == 52 {
            // CALLVALUE
            return self.exec_callvalue();
        }
        if opcode == 53 {
            // CALLDATALOAD
            return self.exec_calldataload();
        }
        if opcode == 54 {
            // CALLDATASIZE
            return self.exec_calldatasize();
        }
        if opcode == 55 {
            // CALLDATACOPY
            return self.exec_calldatacopy();
        }
        if opcode == 56 {
            // CODESIZE
            return self.exec_codesize();
        }
        if opcode == 57 {
            // CODECOPY
            return self.exec_codecopy();
        }
        if opcode == 58 {
            // GASPRICE
            return self.exec_gasprice();
        }
        if opcode == 59 {
            // EXTCODESIZE
            return self.exec_extcodesize();
        }
        if opcode == 60 {
            // EXTCODECOPY
            return self.exec_extcodecopy();
        }
        if opcode == 61 {
            // RETURNDATASIZE
            return self.exec_returndatasize();
        }
        if opcode == 62 {
            // RETURNDATACOPY
            return self.exec_returndatacopy();
        }
        if opcode == 63 {
            // EXTCODEHASH
            return self.exec_extcodehash();
        }
        if opcode == 64 {
            // BLOCKHASH
            return self.exec_blockhash();
        }
        if opcode == 65 {
            // COINBASE
            return self.exec_coinbase();
        }
        if opcode == 66 {
            // TIMESTAMP
            return self.exec_timestamp();
        }
        if opcode == 67 {
            // NUMBER
            return self.exec_number();
        }
        if opcode == 68 {
            // PREVRANDAO
            return self.exec_prevrandao();
        }
        if opcode == 69 {
            // GASLIMIT
            return self.exec_gaslimit();
        }
        if opcode == 70 {
            // CHAINID
            return self.exec_chainid();
        }
        if opcode == 71 {
            // SELFBALANCE
            return self.exec_selfbalance();
        }
        if opcode == 72 {
            // BASEFEE
            return self.exec_basefee();
        }
        if opcode == 73 {
            // BLOBHASH
            return self.exec_blobhash();
        }
        if opcode == 74 {
            // BLOBBASEFEE
            return self.exec_blobbasefee();
        }
        if opcode == 80 {
            // POP
            return self.exec_pop();
        }
        if opcode == 81 {
            // MLOAD
            return self.exec_mload();
        }
        if opcode == 82 {
            // MSTORE
            return self.exec_mstore();
        }
        if opcode == 83 {
            // MSTORE8
            return self.exec_mstore8();
        }
        if opcode == 84 {
            // SLOAD
            return self.exec_sload();
        }
        if opcode == 85 {
            // SSTORE
            return self.exec_sstore();
        }
        if opcode == 86 {
            // JUMP
            return self.exec_jump();
        }
        if opcode == 87 {
            // JUMPI
            return self.exec_jumpi();
        }
        if opcode == 88 {
            // PC
            return self.exec_pc();
        }
        if opcode == 89 {
            // MSIZE
            return self.exec_msize();
        }
        if opcode == 90 {
            // GAS
            return self.exec_gas();
        }
        if opcode == 91 {
            // JUMPDEST
            return self.exec_jumpdest();
        }
        if opcode == 92 {
            // TLOAD
            return self.exec_tload();
        }
        if opcode == 93 {
            // TSTORE
            return self.exec_tstore();
        }
        if opcode == 94 {
            // MCOPY
            return self.exec_mcopy();
        }
        if opcode == 95 {
            // PUSH0
            return self.exec_push0();
        }
        if opcode == 96 {
            // PUSH1
            return self.exec_push1();
        }
        if opcode == 97 {
            // PUSH2
            return self.exec_push2();
        }
        if opcode == 98 {
            // PUSH3
            return self.exec_push3();
        }
        if opcode == 99 {
            // PUSH4
            return self.exec_push4();
        }
        if opcode == 100 {
            // PUSH5
            return self.exec_push5();
        }
        if opcode == 101 {
            // PUSH6
            return self.exec_push6();
        }
        if opcode == 102 {
            // PUSH7
            return self.exec_push7();
        }
        if opcode == 103 {
            // PUSH8
            return self.exec_push8();
        }
        if opcode == 104 {
            // PUSH9
            return self.exec_push9();
        }
        if opcode == 105 {
            // PUSH10
            return self.exec_push10();
        }
        if opcode == 106 {
            // PUSH11
            return self.exec_push11();
        }
        if opcode == 107 {
            // PUSH12
            return self.exec_push12();
        }
        if opcode == 108 {
            // PUSH13
            return self.exec_push13();
        }
        if opcode == 109 {
            // PUSH14
            return self.exec_push14();
        }
        if opcode == 110 {
            // PUSH15
            return self.exec_push15();
        }
        if opcode == 111 {
            // PUSH16
            return self.exec_push16();
        }
        if opcode == 112 {
            // PUSH17
            return self.exec_push17();
        }
        if opcode == 113 {
            // PUSH18
            return self.exec_push18();
        }
        if opcode == 114 {
            // PUSH19
            return self.exec_push19();
        }
        if opcode == 115 {
            // PUSH20
            return self.exec_push20();
        }
        if opcode == 116 {
            // PUSH21
            return self.exec_push21();
        }
        if opcode == 117 {
            // PUSH22
            return self.exec_push22();
        }
        if opcode == 118 {
            // PUSH23
            return self.exec_push23();
        }
        if opcode == 119 {
            // PUSH24
            return self.exec_push24();
        }
        if opcode == 120 {
            // PUSH25
            return self.exec_push25();
        }
        if opcode == 121 {
            // PUSH26
            return self.exec_push26();
        }
        if opcode == 122 {
            // PUSH27
            return self.exec_push27();
        }
        if opcode == 123 {
            // PUSH28
            return self.exec_push28();
        }
        if opcode == 124 {
            // PUSH29
            return self.exec_push29();
        }
        if opcode == 125 {
            // PUSH30
            return self.exec_push30();
        }
        if opcode == 126 {
            // PUSH31
            return self.exec_push31();
        }
        if opcode == 127 {
            // PUSH32
            return self.exec_push32();
        }
        if opcode == 128 {
            // DUP1
            return self.exec_dup1();
        }
        if opcode == 129 {
            // DUP2
            return self.exec_dup2();
        }
        if opcode == 130 {
            // DUP3
            return self.exec_dup3();
        }
        if opcode == 131 {
            // DUP4
            return self.exec_dup4();
        }
        if opcode == 132 {
            // DUP5
            return self.exec_dup5();
        }
        if opcode == 133 {
            // DUP6
            return self.exec_dup6();
        }
        if opcode == 134 {
            // DUP7
            return self.exec_dup7();
        }
        if opcode == 135 {
            // DUP8
            return self.exec_dup8();
        }
        if opcode == 136 {
            // DUP9
            return self.exec_dup9();
        }
        if opcode == 137 {
            // DUP10
            return self.exec_dup10();
        }
        if opcode == 138 {
            // DUP11
            return self.exec_dup11();
        }
        if opcode == 139 {
            // DUP12
            return self.exec_dup12();
        }
        if opcode == 140 {
            // DUP13
            return self.exec_dup13();
        }
        if opcode == 141 {
            // DUP14
            return self.exec_dup14();
        }
        if opcode == 142 {
            // DUP15
            return self.exec_dup15();
        }
        if opcode == 143 {
            // DUP16
            return self.exec_dup16();
        }
        if opcode == 144 {
            // SWAP1
            return self.exec_swap1();
        }
        if opcode == 145 {
            // SWAP2
            return self.exec_swap2();
        }
        if opcode == 146 {
            // SWAP3
            return self.exec_swap3();
        }
        if opcode == 147 {
            // SWAP4
            return self.exec_swap4();
        }
        if opcode == 148 {
            // SWAP5
            return self.exec_swap5();
        }
        if opcode == 149 {
            // SWAP6
            return self.exec_swap6();
        }
        if opcode == 150 {
            // SWAP7
            return self.exec_swap7();
        }
        if opcode == 151 {
            // SWAP8
            return self.exec_swap8();
        }
        if opcode == 152 {
            // SWAP9
            return self.exec_swap9();
        }
        if opcode == 153 {
            // SWAP10
            return self.exec_swap10();
        }
        if opcode == 154 {
            // SWAP11
            return self.exec_swap11();
        }
        if opcode == 155 {
            // SWAP12
            return self.exec_swap12();
        }
        if opcode == 156 {
            // SWAP13
            return self.exec_swap13();
        }
        if opcode == 157 {
            // SWAP14
            return self.exec_swap14();
        }
        if opcode == 158 {
            // SWAP15
            return self.exec_swap15();
        }
        if opcode == 159 {
            // SWAP16
            return self.exec_swap16();
        }
        if opcode == 160 {
            // LOG0
            return self.exec_log0();
        }
        if opcode == 161 {
            // LOG1
            return self.exec_log1();
        }
        if opcode == 162 {
            // LOG2
            return self.exec_log2();
        }
        if opcode == 163 {
            // LOG3
            return self.exec_log3();
        }
        if opcode == 164 {
            // LOG4
            return self.exec_log4();
        }
        if opcode == 240 {
            // CREATE
            return self.exec_create();
        }
        if opcode == 241 {
            // CALL
            return self.exec_call();
        }
        if opcode == 242 {
            // CALLCODE
            return self.exec_callcode();
        }
        if opcode == 243 {
            // RETURN
            return self.exec_return();
        }
        if opcode == 244 {
            // DELEGATECALL
            return self.exec_delegatecall();
        }
        if opcode == 245 {
            // CREATE2
            return self.exec_create2();
        }
        if opcode == 250 {
            // STATICCALL
            return self.exec_staticcall();
        }
        if opcode == 253 {
            // REVERT
            return self.exec_revert();
        }
        if opcode == 254 {
            // INVALID
            return self.exec_invalid();
        }
        if opcode == 255 {
            // SELFDESTRUCT
            return self.exec_selfdestruct();
        }
        // Unknown opcode
        return Result::Err(EVMError::InvalidOpcode(opcode));
    }
}
