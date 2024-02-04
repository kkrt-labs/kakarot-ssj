use evm::call_helpers::is_precompile;
use evm::create_helpers::CreateHelpers;
use evm::errors::{EVMError, ensure, PC_OUT_OF_BOUNDS, EVMErrorTrait, CONTRACT_ACCOUNT_EXISTS};

use evm::instructions::{
    duplication_operations, environmental_information, ExchangeOperationsTrait, logging_operations,
    LoggingOperationsTrait, memory_operations, sha3, StopAndArithmeticOperationsTrait,
    ComparisonAndBitwiseOperationsTrait, SystemOperationsTrait, BlockInformationTrait,
    DuplicationOperationsTrait, EnvironmentInformationTrait, PushOperationsTrait,
    MemoryOperationTrait
};

use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{
    Message, Environment, Address, Transfer, ExecutionSummary, ExecutionSummaryTrait,
    ExecutionResult, ExecutionResultTrait, AccountType
};
use evm::precompiles::Precompiles;
use evm::stack::{Stack, StackTrait};
use evm::state::{State, StateTrait};
use starknet::{EthAddress, ContractAddress};
use utils::constants;
use utils::helpers::{U256Trait, compute_starknet_address, EthAddressExTrait};

#[generate_trait]
impl EVMImpl of EVMTrait {
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
            let mut result = EVMTrait::process_create_message(message, ref env);
            if result.success {
                result.return_data = message.target.evm.to_bytes().span();
            }
            result
        } else {
            EVMTrait::process_message(message, ref env)
        };

        // No need to take snapshot of state, as the state is still empty at this point.
        ExecutionSummary {
            success: result.success,
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
        let mut target_account = env.state.get_account(target_evm_address);

        // Increment nonce of target
        target_account.set_nonce(1);
        target_account.set_type(AccountType::ContractAccount);
        target_account.address = message.target;
        env.state.set_account(target_account);

        let mut result = EVMTrait::process_message(message, ref env);

        if result.success {
            // Write the return_data of the initcode
            // as the deployed contract's bytecode and charge gas
            match result.finalize_creation(target_account) {
                Result::Ok(account_created) => { env.state.set_account(account_created) },
                Result::Err(err) => {
                    env.state = state_snapshot;
                    result.return_data = Default::default().span();
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
        let result = EVMTrait::execute_code(ref vm);

        // Retrieve ownership of the `env` variable
        // The state in the environment has been modified by the VM.
        env = vm.env;

        if !result.success {
            // The `process_message` function has mutated the environment state.
            // Revert state changes using the old snapshot as execution failed.

            env.state = state_snapshot;
        }

        result
    }

    fn execute_code(ref vm: VM) -> ExecutionResult {
        // Handle precompile logic
        if is_precompile(vm.message.target.evm) {
            let result = Precompiles::exec_precompile(ref vm);

            match result {
                Result::Ok(_) => {
                    return ExecutionResult {
                        success: true,
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

        // initalize valid jumpdests
        vm.init_valid_jump_destinations();

        // Retrieve the current program counter.
        let pc = vm.pc();
        let bytecode = vm.message().code;

        // Check if PC is not out of bounds.
        if pc >= bytecode.len() || vm.is_running() == false {
            // REVERT opcode case
            if vm.is_error() {
                return ExecutionResult {
                    success: false,
                    return_data: vm.return_data(),
                    gas_left: vm.gas_left(),
                    accessed_addresses: vm.accessed_addresses(),
                    accessed_storage_keys: vm.accessed_storage_keys(),
                    gas_refund: 0
                };
            };
            // Success case
            return ExecutionResult {
                success: true,
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

        match EVMTrait::execute_opcode(ref vm, opcode) {
            Result::Ok(_) => {
                if vm.is_running() {
                    return EVMTrait::execute_code(ref vm);
                }
                // REVERT opcode case
                if vm.is_error() {
                    return ExecutionResult {
                        success: false,
                        return_data: vm.return_data(),
                        gas_left: vm.gas_left(),
                        accessed_addresses: vm.accessed_addresses(),
                        accessed_storage_keys: vm.accessed_storage_keys(),
                        gas_refund: 0
                    };
                };
                // Success case
                return ExecutionResult {
                    success: true,
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
        return match opcode {
            0 => self.exec_stop(),
            1 => self.exec_add(),
            2 => self.exec_mul(),
            3 => self.exec_sub(),
            4 => self.exec_div(),
            5 => self.exec_sdiv(),
            6 => self.exec_mod(),
            7 => self.exec_smod(),
            8 => self.exec_addmod(),
            9 => self.exec_mulmod(),
            10 => self.exec_exp(),
            11 => self.exec_signextend(),
            12 | 13 | 14 | 15 => Result::Err(EVMError::InvalidOpcode(opcode)),
            16 => self.exec_lt(),
            17 => self.exec_gt(),
            18 => self.exec_slt(),
            19 => self.exec_sgt(),
            20 => self.exec_eq(),
            21 => self.exec_iszero(),
            22 => self.exec_and(),
            23 => self.exec_or(),
            24 => self.exec_xor(),
            25 => self.exec_not(),
            26 => self.exec_byte(),
            27 => self.exec_shl(),
            28 => self.exec_shr(),
            29 => self.exec_sar(),
            30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 40 | 41 | 42 | 43 | 44 | 45 | 46 |
            47 => Result::Err(EVMError::InvalidOpcode(opcode)),
            48 => self.exec_address(),
            49 => self.exec_balance(),
            50 => self.exec_origin(),
            51 => self.exec_caller(),
            52 => self.exec_callvalue(),
            53 => self.exec_calldataload(),
            54 => self.exec_calldatasize(),
            55 => self.exec_calldatacopy(),
            56 => self.exec_codesize(),
            57 => self.exec_codecopy(),
            58 => self.exec_gasprice(),
            59 => self.exec_extcodesize(),
            60 => self.exec_extcodecopy(),
            61 => self.exec_returndatasize(),
            62 => self.exec_returndatacopy(),
            63 => self.exec_extcodehash(),
            64 => self.exec_blockhash(),
            65 => self.exec_coinbase(),
            66 => self.exec_timestamp(),
            67 => self.exec_number(),
            68 => self.exec_prevrandao(),
            69 => self.exec_gaslimit(),
            70 => self.exec_chainid(),
            71 => self.exec_selfbalance(),
            72 => self.exec_basefee(),
            73 | 74 | 75 | 76 | 77 | 78 | 79 => Result::Err(EVMError::InvalidOpcode(opcode)),
            80 => self.exec_pop(),
            81 => self.exec_mload(),
            82 => self.exec_mstore(),
            83 => self.exec_mstore8(),
            84 => self.exec_sload(),
            85 => self.exec_sstore(),
            86 => self.exec_jump(),
            87 => self.exec_jumpi(),
            88 => self.exec_pc(),
            89 => self.exec_msize(),
            90 => self.exec_gas(),
            91 => self.exec_jumpdest(),
            92 | 93 | 94 => Result::Err(EVMError::InvalidOpcode(opcode)),
            95 => self.exec_push0(),
            96 => self.exec_push1(),
            97 => self.exec_push2(),
            98 => self.exec_push3(),
            99 => self.exec_push4(),
            100 => self.exec_push5(),
            101 => self.exec_push6(),
            102 => self.exec_push7(),
            103 => self.exec_push8(),
            104 => self.exec_push9(),
            105 => self.exec_push10(),
            106 => self.exec_push11(),
            107 => self.exec_push12(),
            108 => self.exec_push13(),
            109 => self.exec_push14(),
            110 => self.exec_push15(),
            111 => self.exec_push16(),
            112 => self.exec_push17(),
            113 => self.exec_push18(),
            114 => self.exec_push19(),
            115 => self.exec_push20(),
            116 => self.exec_push21(),
            117 => self.exec_push22(),
            118 => self.exec_push23(),
            119 => self.exec_push24(),
            120 => self.exec_push25(),
            121 => self.exec_push26(),
            122 => self.exec_push27(),
            123 => self.exec_push28(),
            124 => self.exec_push29(),
            125 => self.exec_push30(),
            126 => self.exec_push31(),
            127 => self.exec_push32(),
            128 => self.exec_dup1(),
            129 => self.exec_dup2(),
            130 => self.exec_dup3(),
            131 => self.exec_dup4(),
            132 => self.exec_dup5(),
            133 => self.exec_dup6(),
            134 => self.exec_dup7(),
            135 => self.exec_dup8(),
            136 => self.exec_dup9(),
            137 => self.exec_dup10(),
            138 => self.exec_dup11(),
            139 => self.exec_dup12(),
            140 => self.exec_dup13(),
            141 => self.exec_dup14(),
            142 => self.exec_dup15(),
            143 => self.exec_dup16(),
            144 => self.exec_swap1(),
            145 => self.exec_swap2(),
            146 => self.exec_swap3(),
            147 => self.exec_swap4(),
            148 => self.exec_swap5(),
            149 => self.exec_swap6(),
            150 => self.exec_swap7(),
            151 => self.exec_swap8(),
            152 => self.exec_swap9(),
            153 => self.exec_swap10(),
            154 => self.exec_swap11(),
            155 => self.exec_swap12(),
            156 => self.exec_swap13(),
            157 => self.exec_swap14(),
            158 => self.exec_swap15(),
            159 => self.exec_swap16(),
            160 => self.exec_log0(),
            161 => self.exec_log1(),
            162 => self.exec_log2(),
            163 => self.exec_log3(),
            164 => self.exec_log4(),
            165 | 166 | 167 | 168 | 169 | 170 | 171 | 172 | 173 | 174 | 175 | 176 | 177 | 178 |
            179 | 180 | 181 | 182 | 183 | 184 | 185 | 186 | 187 | 188 | 189 | 190 | 191 | 192 |
            193 | 194 | 195 | 196 | 197 | 198 | 199 | 200 | 201 | 202 | 203 | 204 | 205 | 206 |
            207 | 208 | 209 | 210 | 211 | 212 | 213 | 214 | 215 | 216 | 217 | 218 | 219 | 220 |
            221 | 222 | 223 | 224 | 225 | 226 | 227 | 228 | 229 | 230 | 231 | 232 | 233 | 234 |
            235 | 236 | 237 | 238 | 239 => Result::Err(EVMError::InvalidOpcode(opcode)),
            240 => self.exec_create(),
            241 => self.exec_call(),
            242 => self.exec_callcode(),
            243 => self.exec_return(),
            244 => self.exec_delegatecall(),
            245 => self.exec_create2(),
            246 | 247 | 248 | 249 => Result::Err(EVMError::InvalidOpcode(opcode)),
            250 => self.exec_staticcall(),
            251 | 252 => Result::Err(EVMError::InvalidOpcode(opcode)),
            253 => self.exec_revert(),
            254 => self.exec_invalid(),
            255 => self.exec_selfdestruct(),
            _ => Result::Err(EVMError::InvalidOpcode(opcode))
        };
    }
}
