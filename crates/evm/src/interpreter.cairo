/// System imports.
use array::ArrayTrait;
use array::SpanTrait;
use traits::Into;

/// Internal imports.
// TODO remove destruct imports when no longer required
use evm::context::{
    ExecutionSummary, ExecutionContext, ExecutionContextTrait, CallContextTrait,
    BoxDynamicExecutionContextDestruct
};
use utils::{helpers::u256_to_bytes_array};
use evm::errors::{EVMError, PC_OUT_OF_BOUNDS};
use evm::instructions::{
    duplication_operations, environmental_information, ExchangeOperationsTrait, logging_operations,
    memory_operations, sha3, StopAndArithmeticOperationsTrait, ComparisonAndBitwiseOperationsTrait,
    system_operations, BlockInformationTrait, DuplicationOperationsTrait,
    EnvironmentInformationTrait, PushOperationsTrait, MemoryOperationTrait
};
use result::ResultTrait;


/// EVM instructions as defined in the Yellow Paper and the EIPs.
#[derive(Drop, Copy)]
struct EVMInterpreter {}

trait EVMInterpreterTrait {
    /// Create a new instance of the EVM instructions.
    fn new() -> EVMInterpreter;
    /// Execute the EVM bytecode.
    fn run(ref self: EVMInterpreter, ref context: ExecutionContext);
    /// Decode the current opcode and execute associated function.
    fn decode_and_execute(
        ref self: EVMInterpreter, ref context: ExecutionContext
    ) -> Result<(), EVMError>;
}


impl EVMInterpreterImpl of EVMInterpreterTrait {
    /// Create a new instance of the EVM instructions.
    #[inline(always)]
    fn new() -> EVMInterpreter {
        EVMInterpreter {}
    }

    /// Execute the EVM bytecode.
    fn run(ref self: EVMInterpreter, ref context: ExecutionContext) {
        // Decode and execute the current opcode.
        let result = self.decode_and_execute(ref context);

        match result {
            Result::Ok(_) => {
                // Check if the execution is complete.
                if !(context.stopped()) {
                    // Execute the next opcode.
                    self.run(ref context);
                }
                if context.reverted() { // TODO: Revert logic
                }
                if context.stopped() { // TODO: stopped logic
                }
            },
            Result::Err(error) => {
                // If an error occurred, revert execution context.
                // Currently, revert reason is a Span<u8>. 
                context.revert(u256_to_bytes_array(error.into()).span());
            // TODO: Revert logic
            }
        }
    }

    ///  Decode the current opcode and execute associated function.
    fn decode_and_execute(
        ref self: EVMInterpreter, ref context: ExecutionContext
    ) -> Result<(), EVMError> {
        // Retrieve the current program counter.
        let pc = context.program_counter;
        let bytecode = context.call_context().bytecode();
        let bytecode_len = bytecode.len();

        // Check if PC is not out of bounds.
        if pc >= bytecode_len {
            return Result::Err(EVMError::InvalidProgramCounter(PC_OUT_OF_BOUNDS));
        }

        let opcode: u8 = *bytecode.at(pc);

        // Increment pc
        context.program_counter += 1;

        // Call the appropriate function based on the opcode.
        if opcode == 0 {
            // STOP
            return context.exec_stop();
        }
        if opcode == 1 {
            // ADD
            return context.exec_add();
        }
        if opcode == 2 {
            // MUL
            return context.exec_mul();
        }
        if opcode == 3 {
            // SUB
            return context.exec_sub();
        }
        if opcode == 4 {
            // DIV
            return context.exec_div();
        }
        if opcode == 5 {
            // SDIV
            return context.exec_sdiv();
        }
        if opcode == 6 {
            // MOD
            return context.exec_mod();
        }
        if opcode == 7 {
            // SMOD
            return context.exec_smod();
        }
        if opcode == 8 {
            // ADDMOD
            return context.exec_addmod();
        }
        if opcode == 9 {
            // MULMOD
            return context.exec_mulmod();
        }
        if opcode == 10 {
            // EXP
            return context.exec_exp();
        }
        if opcode == 11 {
            // SIGNEXTEND
            return context.exec_signextend();
        }
        if opcode == 16 {
            // LT
            return context.exec_lt();
        }
        if opcode == 17 {
            // GT
            return context.exec_gt();
        }
        if opcode == 18 {
            // SLT
            return context.exec_slt();
        }
        if opcode == 19 {
            // SGT
            return context.exec_sgt();
        }
        if opcode == 20 {
            // EQ
            return context.exec_eq();
        }
        if opcode == 21 {
            // ISZERO
            return context.exec_iszero();
        }
        if opcode == 22 {
            // AND
            return context.exec_and();
        }
        if opcode == 23 {
            // OR
            return context.exec_or();
        }
        if opcode == 24 {
            // XOR
            return context.exec_xor();
        }
        if opcode == 25 {
            // NOT
            return context.exec_not();
        }
        if opcode == 26 {
            // BYTE
            return context.exec_byte();
        }
        if opcode == 27 {
            // SHL
            return context.exec_shl();
        }
        if opcode == 28 {
            // SHR
            return context.exec_shr();
        }
        if opcode == 29 {
            // SAR
            return context.exec_sar();
        }
        if opcode == 48 {
            // ADDRESS
            return context.exec_address();
        }
        if opcode == 49 {
            // BALANCE
            return context.exec_balance();
        }
        if opcode == 50 {
            // ORIGIN
            return context.exec_origin();
        }
        if opcode == 51 {
            // CALLER
            return context.exec_caller();
        }
        if opcode == 52 {
            // CALLVALUE
            return context.exec_callvalue();
        }
        if opcode == 53 {
            // CALLDATALOAD
            return context.exec_calldataload();
        }
        if opcode == 54 {
            // CALLDATASIZE
            return context.exec_calldatasize();
        }
        if opcode == 55 {
            // CALLDATACOPY
            return context.exec_calldatacopy();
        }
        if opcode == 56 {
            // CODESIZE
            return context.exec_codesize();
        }
        if opcode == 57 {
            // CODECOPY
            return context.exec_codecopy();
        }
        if opcode == 58 {
            // GASPRICE
            return context.exec_gasprice();
        }
        if opcode == 59 {
            // EXTCODESIZE
            return context.exec_extcodesize();
        }
        if opcode == 60 {
            // EXTCODECOPY
            return context.exec_extcodecopy();
        }
        if opcode == 61 {
            // RETURNDATASIZE
            return context.exec_returndatasize();
        }
        if opcode == 62 {
            // RETURNDATACOPY
            return context.exec_returndatacopy();
        }
        if opcode == 63 {
            // EXTCODEHASH
            return context.exec_extcodehash();
        }
        if opcode == 64 {
            // BLOCKHASH
            return context.exec_blockhash();
        }
        if opcode == 65 {
            // COINBASE
            return context.exec_coinbase();
        }
        if opcode == 66 {
            // TIMESTAMP
            return context.exec_timestamp();
        }
        if opcode == 67 {
            // NUMBER
            return context.exec_number();
        }
        if opcode == 68 {
            // PREVRANDAO
            return context.exec_prevrandao();
        }
        if opcode == 69 {
            // GASLIMIT
            return context.exec_gaslimit();
        }
        if opcode == 70 {
            // CHAINID
            return context.exec_chainid();
        }
        if opcode == 71 {
            // SELFBALANCE
            return context.exec_selfbalance();
        }
        if opcode == 72 {
            // BASEFEE
            return context.exec_basefee();
        }
        if opcode == 80 {
            // POP
            return context.exec_pop();
        }
        if opcode == 81 {
            // MLOAD
            return context.exec_mload();
        }
        if opcode == 82 {
            // MSTORE
            return context.exec_mstore();
        }
        if opcode == 83 {
            // MSTORE8
            return context.exec_mstore8();
        }
        if opcode == 84 {
            // SLOAD
            return context.exec_sload();
        }
        if opcode == 85 {
            // SSTORE
            return context.exec_sstore();
        }
        if opcode == 86 {
            // JUMP
            return context.exec_jump();
        }
        if opcode == 87 {
            // JUMPI
            return context.exec_jumpi();
        }
        if opcode == 88 {
            // PC
            return context.exec_pc();
        }
        if opcode == 89 {
            // MSIZE
            return context.exec_msize();
        }
        if opcode == 90 {
            // GAS
            return context.exec_gas();
        }
        if opcode == 91 {
            // JUMPDEST
            return context.exec_jumpdest();
        }
        if opcode == 95 {
            // PUSH0
            return context.exec_push0();
        }
        if opcode == 96 {
            // PUSH1
            return context.exec_push1();
        }
        if opcode == 97 {
            // PUSH2
            return context.exec_push2();
        }
        if opcode == 98 {
            // PUSH3
            return context.exec_push3();
        }
        if opcode == 99 {
            // PUSH4
            return context.exec_push4();
        }
        if opcode == 100 {
            // PUSH5
            return context.exec_push5();
        }
        if opcode == 101 {
            // PUSH6
            return context.exec_push6();
        }
        if opcode == 102 {
            // PUSH7
            return context.exec_push7();
        }
        if opcode == 103 {
            // PUSH8
            return context.exec_push8();
        }
        if opcode == 104 {
            // PUSH9
            return context.exec_push9();
        }
        if opcode == 105 {
            // PUSH10
            return context.exec_push10();
        }
        if opcode == 106 {
            // PUSH11
            return context.exec_push11();
        }
        if opcode == 107 {
            // PUSH12
            return context.exec_push12();
        }
        if opcode == 108 {
            // PUSH13
            return context.exec_push13();
        }
        if opcode == 109 {
            // PUSH14
            return context.exec_push14();
        }
        if opcode == 110 {
            // PUSH15
            return context.exec_push15();
        }
        if opcode == 111 {
            // PUSH16
            return context.exec_push16();
        }
        if opcode == 112 {
            // PUSH17
            return context.exec_push17();
        }
        if opcode == 113 {
            // PUSH18
            return context.exec_push18();
        }
        if opcode == 114 {
            // PUSH19
            return context.exec_push19();
        }
        if opcode == 115 {
            // PUSH20
            return context.exec_push20();
        }
        if opcode == 116 {
            // PUSH21
            return context.exec_push21();
        }
        if opcode == 117 {
            // PUSH22
            return context.exec_push22();
        }
        if opcode == 118 {
            // PUSH23
            return context.exec_push23();
        }
        if opcode == 119 {
            // PUSH24
            return context.exec_push24();
        }
        if opcode == 120 {
            // PUSH25
            return context.exec_push25();
        }
        if opcode == 121 {
            // PUSH26
            return context.exec_push26();
        }
        if opcode == 122 {
            // PUSH27
            return context.exec_push27();
        }
        if opcode == 123 {
            // PUSH28
            return context.exec_push28();
        }
        if opcode == 124 {
            // PUSH29
            return context.exec_push29();
        }
        if opcode == 125 {
            // PUSH30
            return context.exec_push30();
        }
        if opcode == 126 {
            // PUSH31
            return context.exec_push31();
        }
        if opcode == 127 {
            // PUSH32
            return context.exec_push32();
        }
        if opcode == 128 {
            // DUP1
            return context.exec_dup1();
        }
        if opcode == 129 {
            // DUP2
            return context.exec_dup2();
        }
        if opcode == 130 {
            // DUP3
            return context.exec_dup3();
        }
        if opcode == 131 {
            // DUP4
            return context.exec_dup4();
        }
        if opcode == 132 {
            // DUP5
            return context.exec_dup5();
        }
        if opcode == 133 {
            // DUP6
            return context.exec_dup6();
        }
        if opcode == 134 {
            // DUP7
            return context.exec_dup7();
        }
        if opcode == 135 {
            // DUP8
            return context.exec_dup8();
        }
        if opcode == 136 {
            // DUP9
            return context.exec_dup9();
        }
        if opcode == 137 {
            // DUP10
            return context.exec_dup10();
        }
        if opcode == 138 {
            // DUP11
            return context.exec_dup11();
        }
        if opcode == 139 {
            // DUP12
            return context.exec_dup12();
        }
        if opcode == 140 {
            // DUP13
            return context.exec_dup13();
        }
        if opcode == 141 {
            // DUP14
            return context.exec_dup14();
        }
        if opcode == 142 {
            // DUP15
            return context.exec_dup15();
        }
        if opcode == 143 {
            // DUP16
            return context.exec_dup16();
        }
        if opcode == 144 {
            // SWAP1
            context.exec_swap1();
        }
        if opcode == 145 {
            // SWAP2
            context.exec_swap2();
        }
        if opcode == 146 {
            // SWAP3
            context.exec_swap3();
        }
        if opcode == 147 {
            // SWAP4
            context.exec_swap4();
        }
        if opcode == 148 {
            // SWAP5
            context.exec_swap5();
        }
        if opcode == 149 {
            // SWAP6
            context.exec_swap6();
        }
        if opcode == 150 {
            // SWAP7
            context.exec_swap7();
        }
        if opcode == 151 {
            // SWAP8
            context.exec_swap8();
        }
        if opcode == 152 {
            // SWAP9
            context.exec_swap9();
        }
        if opcode == 153 {
            // SWAP10
            context.exec_swap10();
        }
        if opcode == 154 {
            // SWAP11
            context.exec_swap11();
        }
        if opcode == 155 {
            // SWAP12
            context.exec_swap12();
        }
        if opcode == 156 {
            // SWAP13
            context.exec_swap13();
        }
        if opcode == 157 {
            // SWAP14
            context.exec_swap14();
        }
        if opcode == 158 {
            // SWAP15
            context.exec_swap15();
        }
        if opcode == 159 {
            // SWAP16
            context.exec_swap16();
        }
        if opcode == 160 {
            // LOG0
            logging_operations::exec_log0(ref context);
        }
        if opcode == 161 {
            // LOG1
            logging_operations::exec_log1(ref context);
        }
        if opcode == 162 {
            // LOG2
            logging_operations::exec_log2(ref context);
        }
        if opcode == 163 {
            // LOG3
            logging_operations::exec_log3(ref context);
        }
        if opcode == 164 {
            // LOG4
            logging_operations::exec_log4(ref context);
        }
        if opcode == 240 {
            // CREATE
            system_operations::exec_create(ref context);
        }
        if opcode == 241 {
            // CALL
            system_operations::exec_call(ref context);
        }
        if opcode == 242 {
            // CALLCODE
            system_operations::exec_callcode(ref context);
        }
        if opcode == 243 {
            // RETURN
            system_operations::exec_return(ref context);
        }
        if opcode == 244 {
            // DELEGATECALL
            system_operations::exec_delegatecall(ref context);
        }
        if opcode == 245 {
            // CREATE2
            system_operations::exec_create2(ref context);
        }
        if opcode == 250 {
            // STATICCALL
            system_operations::exec_staticcall(ref context);
        }
        if opcode == 253 {
            // REVERT
            system_operations::exec_revert(ref context);
        }
        if opcode == 254 {
            // INVALID
            system_operations::exec_invalid(ref context);
        }
        if opcode == 255 {
            // SELFDESTRUCT
            system_operations::exec_selfdestruct(ref context);
        }
        // Unknown opcode
        unknown_opcode(opcode);
        Result::Ok(())
    }
}

/// This function is called when an unknown opcode is encountered.
/// # Arguments
/// * `opcode` - The unknown opcode
/// # TODO
/// * Implement this function and revert execution.
fn unknown_opcode(opcode: u8) {}
