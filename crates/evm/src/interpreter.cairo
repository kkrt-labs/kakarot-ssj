/// System imports.

/// Internal imports.
use evm::call_helpers::MachineCallHelpers;
use evm::context::{CallContextTrait, Status};
use evm::context::{ExecutionContextTrait, ExecutionContext};
use evm::errors::{EVMError, PC_OUT_OF_BOUNDS};
use evm::instructions::{
    duplication_operations, environmental_information, ExchangeOperationsTrait, logging_operations,
    LoggingOperationsTrait, memory_operations, sha3, StopAndArithmeticOperationsTrait,
    ComparisonAndBitwiseOperationsTrait, SystemOperationsTrait, BlockInformationTrait,
    DuplicationOperationsTrait, EnvironmentInformationTrait, PushOperationsTrait,
    MemoryOperationTrait
};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::storage_journal::JournalTrait;
use utils::{helpers::u256_to_bytes_array};

#[derive(Drop, Copy)]
struct EVMInterpreter {}

trait EVMInterpreterTrait {
    /// Create a new instance of the EVM Interpreter.
    fn new() -> EVMInterpreter;
    /// Execute the EVM bytecode.
    fn run(ref self: EVMInterpreter, ref machine: Machine);
    /// Decodes the opcode at `pc` and executes the associated function.
    fn decode_and_execute(ref self: EVMInterpreter, ref machine: Machine) -> Result<(), EVMError>;
    fn finalize_revert(ref self: EVMInterpreter, ref machine: Machine);
}


impl EVMInterpreterImpl of EVMInterpreterTrait {
    #[inline(always)]
    fn new() -> EVMInterpreter {
        EVMInterpreter {}
    }

    fn run(ref self: EVMInterpreter, ref machine: Machine) {
        // Decode and execute the current opcode.
        let result = self.decode_and_execute(ref machine);

        match result {
            Result::Ok(_) => {
                match machine.status() {
                    Status::Active => {
                        // execute the next opcode
                        self.run(ref machine);
                    },
                    Status::Stopped => {
                        machine.storage_journal.finalize_local();
                        if machine.is_root() {
                            machine.storage_journal.finalize_global();
                        } else if machine.is_call() {
                            machine.finalize_calling_context();
                            self.run(ref machine);
                        } else { // TODO(greg): finalize the create context
                        };
                    },
                    Status::Reverted => { self.finalize_revert(ref machine); }
                }
            },
            Result::Err(error) => {
                // If an error occurred, revert execution machine.
                // Currently, revert reason is a Span<u8>.
                machine.set_reverted();
                self.finalize_revert(ref machine);
            }
        }
    }

    fn decode_and_execute(ref self: EVMInterpreter, ref machine: Machine) -> Result<(), EVMError> {
        // Retrieve the current program counter.
        let pc = machine.pc();
        let bytecode = machine.call_ctx().bytecode();
        let bytecode_len = bytecode.len();

        // Check if PC is not out of bounds.
        if pc >= bytecode_len {
            return Result::Err(EVMError::InvalidProgramCounter(PC_OUT_OF_BOUNDS));
        }

        let opcode: u8 = *bytecode.at(pc);

        // Increment pc
        machine.set_pc(pc + 1);

        // Call the appropriate function based on the opcode.
        if opcode == 0 {
            // STOP
            return machine.exec_stop();
        }
        if opcode == 1 {
            // ADD
            return machine.exec_add();
        }
        if opcode == 2 {
            // MUL
            return machine.exec_mul();
        }
        if opcode == 3 {
            // SUB
            return machine.exec_sub();
        }
        if opcode == 4 {
            // DIV
            return machine.exec_div();
        }
        if opcode == 5 {
            // SDIV
            return machine.exec_sdiv();
        }
        if opcode == 6 {
            // MOD
            return machine.exec_mod();
        }
        if opcode == 7 {
            // SMOD
            return machine.exec_smod();
        }
        if opcode == 8 {
            // ADDMOD
            return machine.exec_addmod();
        }
        if opcode == 9 {
            // MULMOD
            return machine.exec_mulmod();
        }
        if opcode == 10 {
            // EXP
            return machine.exec_exp();
        }
        if opcode == 11 {
            // SIGNEXTEND
            return machine.exec_signextend();
        }
        if opcode == 16 {
            // LT
            return machine.exec_lt();
        }
        if opcode == 17 {
            // GT
            return machine.exec_gt();
        }
        if opcode == 18 {
            // SLT
            return machine.exec_slt();
        }
        if opcode == 19 {
            // SGT
            return machine.exec_sgt();
        }
        if opcode == 20 {
            // EQ
            return machine.exec_eq();
        }
        if opcode == 21 {
            // ISZERO
            return machine.exec_iszero();
        }
        if opcode == 22 {
            // AND
            return machine.exec_and();
        }
        if opcode == 23 {
            // OR
            return machine.exec_or();
        }
        if opcode == 24 {
            // XOR
            return machine.exec_xor();
        }
        if opcode == 25 {
            // NOT
            return machine.exec_not();
        }
        if opcode == 26 {
            // BYTE
            return machine.exec_byte();
        }
        if opcode == 27 {
            // SHL
            return machine.exec_shl();
        }
        if opcode == 28 {
            // SHR
            return machine.exec_shr();
        }
        if opcode == 29 {
            // SAR
            return machine.exec_sar();
        }
        if opcode == 48 {
            // ADDRESS
            return machine.exec_address();
        }
        if opcode == 49 {
            // BALANCE
            return machine.exec_balance();
        }
        if opcode == 50 {
            // ORIGIN
            return machine.exec_origin();
        }
        if opcode == 51 {
            // CALLER
            return machine.exec_caller();
        }
        if opcode == 52 {
            // CALLVALUE
            return machine.exec_callvalue();
        }
        if opcode == 53 {
            // CALLDATALOAD
            return machine.exec_calldataload();
        }
        if opcode == 54 {
            // CALLDATASIZE
            return machine.exec_calldatasize();
        }
        if opcode == 55 {
            // CALLDATACOPY
            return machine.exec_calldatacopy();
        }
        if opcode == 56 {
            // CODESIZE
            return machine.exec_codesize();
        }
        if opcode == 57 {
            // CODECOPY
            return machine.exec_codecopy();
        }
        if opcode == 58 {
            // GASPRICE
            return machine.exec_gasprice();
        }
        if opcode == 59 {
            // EXTCODESIZE
            return machine.exec_extcodesize();
        }
        if opcode == 60 {
            // EXTCODECOPY
            return machine.exec_extcodecopy();
        }
        if opcode == 61 {
            // RETURNDATASIZE
            return machine.exec_returndatasize();
        }
        if opcode == 62 {
            // RETURNDATACOPY
            return machine.exec_returndatacopy();
        }
        if opcode == 63 {
            // EXTCODEHASH
            return machine.exec_extcodehash();
        }
        if opcode == 64 {
            // BLOCKHASH
            return machine.exec_blockhash();
        }
        if opcode == 65 {
            // COINBASE
            return machine.exec_coinbase();
        }
        if opcode == 66 {
            // TIMESTAMP
            return machine.exec_timestamp();
        }
        if opcode == 67 {
            // NUMBER
            return machine.exec_number();
        }
        if opcode == 68 {
            // PREVRANDAO
            return machine.exec_prevrandao();
        }
        if opcode == 69 {
            // GASLIMIT
            return machine.exec_gaslimit();
        }
        if opcode == 70 {
            // CHAINID
            return machine.exec_chainid();
        }
        if opcode == 71 {
            // SELFBALANCE
            return machine.exec_selfbalance();
        }
        if opcode == 72 {
            // BASEFEE
            return machine.exec_basefee();
        }
        if opcode == 80 {
            // POP
            return machine.exec_pop();
        }
        if opcode == 81 {
            // MLOAD
            return machine.exec_mload();
        }
        if opcode == 82 {
            // MSTORE
            return machine.exec_mstore();
        }
        if opcode == 83 {
            // MSTORE8
            return machine.exec_mstore8();
        }
        if opcode == 84 {
            // SLOAD
            return machine.exec_sload();
        }
        if opcode == 85 {
            // SSTORE
            return machine.exec_sstore();
        }
        if opcode == 86 {
            // JUMP
            return machine.exec_jump();
        }
        if opcode == 87 {
            // JUMPI
            return machine.exec_jumpi();
        }
        if opcode == 88 {
            // PC
            return machine.exec_pc();
        }
        if opcode == 89 {
            // MSIZE
            return machine.exec_msize();
        }
        if opcode == 90 {
            // GAS
            return machine.exec_gas();
        }
        if opcode == 91 {
            // JUMPDEST
            return machine.exec_jumpdest();
        }
        if opcode == 95 {
            // PUSH0
            return machine.exec_push0();
        }
        if opcode == 96 {
            // PUSH1
            return machine.exec_push1();
        }
        if opcode == 97 {
            // PUSH2
            return machine.exec_push2();
        }
        if opcode == 98 {
            // PUSH3
            return machine.exec_push3();
        }
        if opcode == 99 {
            // PUSH4
            return machine.exec_push4();
        }
        if opcode == 100 {
            // PUSH5
            return machine.exec_push5();
        }
        if opcode == 101 {
            // PUSH6
            return machine.exec_push6();
        }
        if opcode == 102 {
            // PUSH7
            return machine.exec_push7();
        }
        if opcode == 103 {
            // PUSH8
            return machine.exec_push8();
        }
        if opcode == 104 {
            // PUSH9
            return machine.exec_push9();
        }
        if opcode == 105 {
            // PUSH10
            return machine.exec_push10();
        }
        if opcode == 106 {
            // PUSH11
            return machine.exec_push11();
        }
        if opcode == 107 {
            // PUSH12
            return machine.exec_push12();
        }
        if opcode == 108 {
            // PUSH13
            return machine.exec_push13();
        }
        if opcode == 109 {
            // PUSH14
            return machine.exec_push14();
        }
        if opcode == 110 {
            // PUSH15
            return machine.exec_push15();
        }
        if opcode == 111 {
            // PUSH16
            return machine.exec_push16();
        }
        if opcode == 112 {
            // PUSH17
            return machine.exec_push17();
        }
        if opcode == 113 {
            // PUSH18
            return machine.exec_push18();
        }
        if opcode == 114 {
            // PUSH19
            return machine.exec_push19();
        }
        if opcode == 115 {
            // PUSH20
            return machine.exec_push20();
        }
        if opcode == 116 {
            // PUSH21
            return machine.exec_push21();
        }
        if opcode == 117 {
            // PUSH22
            return machine.exec_push22();
        }
        if opcode == 118 {
            // PUSH23
            return machine.exec_push23();
        }
        if opcode == 119 {
            // PUSH24
            return machine.exec_push24();
        }
        if opcode == 120 {
            // PUSH25
            return machine.exec_push25();
        }
        if opcode == 121 {
            // PUSH26
            return machine.exec_push26();
        }
        if opcode == 122 {
            // PUSH27
            return machine.exec_push27();
        }
        if opcode == 123 {
            // PUSH28
            return machine.exec_push28();
        }
        if opcode == 124 {
            // PUSH29
            return machine.exec_push29();
        }
        if opcode == 125 {
            // PUSH30
            return machine.exec_push30();
        }
        if opcode == 126 {
            // PUSH31
            return machine.exec_push31();
        }
        if opcode == 127 {
            // PUSH32
            return machine.exec_push32();
        }
        if opcode == 128 {
            // DUP1
            return machine.exec_dup1();
        }
        if opcode == 129 {
            // DUP2
            return machine.exec_dup2();
        }
        if opcode == 130 {
            // DUP3
            return machine.exec_dup3();
        }
        if opcode == 131 {
            // DUP4
            return machine.exec_dup4();
        }
        if opcode == 132 {
            // DUP5
            return machine.exec_dup5();
        }
        if opcode == 133 {
            // DUP6
            return machine.exec_dup6();
        }
        if opcode == 134 {
            // DUP7
            return machine.exec_dup7();
        }
        if opcode == 135 {
            // DUP8
            return machine.exec_dup8();
        }
        if opcode == 136 {
            // DUP9
            return machine.exec_dup9();
        }
        if opcode == 137 {
            // DUP10
            return machine.exec_dup10();
        }
        if opcode == 138 {
            // DUP11
            return machine.exec_dup11();
        }
        if opcode == 139 {
            // DUP12
            return machine.exec_dup12();
        }
        if opcode == 140 {
            // DUP13
            return machine.exec_dup13();
        }
        if opcode == 141 {
            // DUP14
            return machine.exec_dup14();
        }
        if opcode == 142 {
            // DUP15
            return machine.exec_dup15();
        }
        if opcode == 143 {
            // DUP16
            return machine.exec_dup16();
        }
        if opcode == 144 {
            // SWAP1
            return machine.exec_swap1();
        }
        if opcode == 145 {
            // SWAP2
            return machine.exec_swap2();
        }
        if opcode == 146 {
            // SWAP3
            return machine.exec_swap3();
        }
        if opcode == 147 {
            // SWAP4
            return machine.exec_swap4();
        }
        if opcode == 148 {
            // SWAP5
            return machine.exec_swap5();
        }
        if opcode == 149 {
            // SWAP6
            return machine.exec_swap6();
        }
        if opcode == 150 {
            // SWAP7
            return machine.exec_swap7();
        }
        if opcode == 151 {
            // SWAP8
            return machine.exec_swap8();
        }
        if opcode == 152 {
            // SWAP9
            return machine.exec_swap9();
        }
        if opcode == 153 {
            // SWAP10
            return machine.exec_swap10();
        }
        if opcode == 154 {
            // SWAP11
            return machine.exec_swap11();
        }
        if opcode == 155 {
            // SWAP12
            return machine.exec_swap12();
        }
        if opcode == 156 {
            // SWAP13
            return machine.exec_swap13();
        }
        if opcode == 157 {
            // SWAP14
            return machine.exec_swap14();
        }
        if opcode == 158 {
            // SWAP15
            return machine.exec_swap15();
        }
        if opcode == 159 {
            // SWAP16
            return machine.exec_swap16();
        }
        if opcode == 160 {
            // LOG0
            return machine.exec_log0();
        }
        if opcode == 161 {
            // LOG1
            return machine.exec_log1();
        }
        if opcode == 162 {
            // LOG2
            return machine.exec_log2();
        }
        if opcode == 163 {
            // LOG3
            return machine.exec_log3();
        }
        if opcode == 164 {
            // LOG4
            return machine.exec_log4();
        }
        if opcode == 240 {
            // CREATE
            return machine.exec_create();
        }
        if opcode == 241 {
            // CALL
            return machine.exec_call();
        }
        if opcode == 242 {
            // CALLCODE
            return machine.exec_callcode();
        }
        if opcode == 243 {
            // RETURN
            return machine.exec_return();
        }
        if opcode == 244 {
            // DELEGATECALL
            return machine.exec_delegatecall();
        }
        if opcode == 245 {
            // CREATE2
            return machine.exec_create2();
        }
        if opcode == 250 {
            // STATICCALL
            return machine.exec_staticcall();
        }
        if opcode == 253 {
            // REVERT
            return machine.exec_revert();
        }
        if opcode == 254 {
            // INVALID
            return machine.exec_invalid();
        }
        if opcode == 255 {
            // SELFDESTRUCT
            return machine.exec_selfdestruct();
        }
        // Unknown opcode
        return Result::Err(EVMError::UnknownOpcode(opcode));
    }

    /// Finalizes the revert of an execution context.
    /// Clears all pending journal entries, not finalizing the pending state changes applied inside this context.
    fn finalize_revert(ref self: EVMInterpreter, ref machine: Machine) {
        machine.storage_journal.clear_local();
    //TODO add the rest of the revert handling.
    }
}
