use evm::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait, Status};
use evm::errors::{EVMError, PC_OUT_OF_BOUNDS, EVMErrorTrait, CONTRACT_ACCOUNT_EXISTS};

use evm::model::account::{AccountTrait};
use evm::model::{Address, Transfer, ExecutionResult, AccountType};
use evm::state::{State, StateTrait};
use starknet::{EthAddress, ContractAddress};
use utils::helpers::{U256Trait, compute_starknet_address};
use evm::stack::{Stack, StackTrait};

use evm::instructions::{
    duplication_operations, environmental_information, ExchangeOperationsTrait, logging_operations,
    LoggingOperationsTrait, memory_operations, sha3, StopAndArithmeticOperationsTrait,
    ComparisonAndBitwiseOperationsTrait, SystemOperationsTrait, BlockInformationTrait,
    DuplicationOperationsTrait, EnvironmentInformationTrait, PushOperationsTrait,
    MemoryOperationTrait
};

use evm::call_helpers::is_precompile;

#[generate_trait]
impl EVMImpl of EVMTrait {
    /// Creates an instance of the EVM to execute a transaction.
    ///
    /// # Arguments
    /// * `origin` - The EVM address of the origin of the transaction.
    /// * `target` - The EVM address of the called contract.
    /// * `calldata` - The calldata of the execution.
    /// * `value` - The value of the execution.
    /// * `gas_limit` - The gas limit of the execution.
    /// * `gas_price` - The gas price for the execution.
    /// * `read_only` - Whether the execution is read only.
    /// * `is_deploy_tx` - Whether the execution is a deploy transaction.
    ///
    /// # Returns
    /// * ExecutionResult struct, containing:
    /// *   The execution status
    /// *   The return data of the execution.
    /// *   The destroyed contracts
    /// *   The created contracts
    /// *   The events emitted
    fn process_message_call(
        origin: Address,
        target: Address,
        calldata: Span<u8>,
        value: u256,
        gas_price: u128,
        gas_limit: u128,
        read_only: bool,
        is_deploy_tx: bool,
    ) -> ExecutionResult {
        let mut state: State = Default::default();

        let mut target_account = state.get_account(target.evm);
        let (bytecode, calldata) = if is_deploy_tx {
            (calldata, array![].span())
        } else {
            (target_account.code, calldata)
        };

        let call_ctx = CallContextTrait::new(
            caller: origin,
            :origin,
            :bytecode,
            :calldata,
            :value,
            :read_only,
            :gas_limit,
            :gas_price,
            should_transfer: true,
        );

        let mut ctx = ExecutionContextTrait::new(
            address: target, :call_ctx, depth: 0, state: state,
        );

        if is_deploy_tx {
            // Check collision
            if target_account.has_code_or_nonce() {
                return ExecutionResult {
                    address: target,
                    status: Status::Reverted,
                    return_data: Into::<
                        felt252, u256
                    >::into(EVMError::DeployError(CONTRACT_ACCOUNT_EXISTS).to_string())
                        .to_bytes(),
                    state: ctx.state,
                };
            }
            let execution_result = ctx.process_create_message();
            return execution_result;
        }

        // Execute the bytecode
        let result = ctx.process_message();
        return result;
    }

    fn process_create_message(ref self: ExecutionContext) -> ExecutionResult {
        let mut target_account = self.state.get_account(self.address().evm);

        target_account.set_nonce(1);
        target_account.set_type(AccountType::ContractAccount);
        target_account.address = self.address();
        self.state.set_account(target_account);

        let result = self.process_message();

        match result.status {
            Status::Active => {
                // TODO: The Execution Result should not share the Status type since it cannot be active
                // This INVARIANT should be handled by the type system
                panic!(
                    "INVARIANT: Status of the Execution Context should not be Active in finalize logic"
                )
            },
            Status::Stopped => {
                self.state = result.state;

                let code = result.return_data;
                target_account.set_code(code);
                self.state.set_account(target_account);

                ExecutionResult {
                    status: Status::Stopped,
                    address: self.address(),
                    state: self.state(),
                    return_data: self.return_data(),
                }
            },
            Status::Reverted => result,
        }
    }

    fn process_message(ref self: ExecutionContext) -> ExecutionResult {
        if self.should_transfer() && self.value() > 0 {
            let transfer = Transfer {
                sender: self.caller(), recipient: self.address(), amount: self.value(),
            };
            self.state.add_transfer(transfer).expect('TODO(ELIAS): handle');
        }

        // Handle precompile logic
        if is_precompile(self.address().evm) {
            panic!("Not Implemented: Precompiles are not implemented yet");
        }

        // execute code

        // Decode and execute the current opcode.
        loop {
            let mut res = self.decode_and_execute();

            let execution_result = match res {
                Result::Ok(_) => {
                    match self.status() {
                        Status::Active => {
                            // execute the next opcode
                            // TODO: pair programming with Eni
                            res = self.decode_and_execute();
                        },
                        Status::Stopped => {
                            break ExecutionResult {
                                status: self.status(),
                                address: self.address(),
                                state: self.state(),
                                return_data: self.return_data(),
                            };
                        },
                        Status::Reverted => {
                            break ExecutionResult {
                                status: self.status(),
                                address: self.address(),
                                // return a Default::default() State -> flush it!
                                state: self.state(),
                                return_data: self.return_data(),
                            };
                        }
                    }
                },
                Result::Err(error) => {
                    // If an error occurred, revert execution self.
                    // Currently, revert reason is a Span<u8>.
                    break ExecutionResult {
                        status: self.status(),
                        address: self.address(),
                        // return a Default::default() State -> flush it!
                        state: self.state(),
                        return_data: Into::<felt252, u256>::into(error.to_string()).to_bytes(),
                    };
                }
            };
        }
    }

    fn decode_and_execute(ref self: ExecutionContext) -> Result<(), EVMError> {
        // Retrieve the current program counter.
        let pc = self.pc();

        let bytecode = self.call_ctx().bytecode();
        let bytecode_len = bytecode.len();

        // Check if PC is not out of bounds.
        if pc >= bytecode_len {
            self.set_stopped();
            return Result::Ok(());
        }

        let opcode: u8 = *bytecode.at(pc);
        // Increment pc
        self.set_pc(pc + 1);

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
