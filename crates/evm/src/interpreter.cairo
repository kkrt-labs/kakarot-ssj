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
    duplication_operations, environmental_information, exchange_operations, logging_operations,
    memory_operations, sha3, StopAndArithmeticOperationsTrait, ComparisonAndBitwiseOperationsTrait,
    system_operations, BlockInformationTrait, DuplicationOperationsTrait,
    EnvironmentInformationTrait, PushOperationsTrait
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
            context.exec_stop()?;
        }
        if opcode == 1 {
            // ADD
            context.exec_add()?;
        }
        if opcode == 2 {
            // MUL
            context.exec_mul()?;
        }
        if opcode == 3 {
            // SUB
            context.exec_sub()?;
        }
        if opcode == 4 {
            // DIV
            context.exec_div()?;
        }
        if opcode == 5 {
            // SDIV
            context.exec_sdiv()?;
        }
        if opcode == 6 {
            // MOD
            context.exec_mod()?;
        }
        if opcode == 7 {
            // SMOD
            context.exec_smod()?;
        }
        if opcode == 8 {
            // ADDMOD
            context.exec_addmod()?;
        }
        if opcode == 9 {
            // MULMOD
            context.exec_mulmod()?;
        }
        if opcode == 10 {
            // EXP
            context.exec_exp()?;
        }
        if opcode == 11 {
            // SIGNEXTEND
            context.exec_signextend()?;
        }
        if opcode == 16 {
            // LT
            context.exec_lt()?;
        }
        if opcode == 17 {
            // GT
            context.exec_gt()?;
        }
        if opcode == 18 {
            // SLT
            context.exec_slt()?;
        }
        if opcode == 19 {
            // SGT
            context.exec_sgt()?;
        }
        if opcode == 20 {
            // EQ
            context.exec_eq()?;
        }
        if opcode == 21 {
            // ISZERO
            context.exec_iszero()?;
        }
        if opcode == 22 {
            // AND
            context.exec_and()?;
        }
        if opcode == 23 {
            // OR
            context.exec_or()?;
        }
        if opcode == 24 {
            // XOR
            context.exec_xor()?;
        }
        if opcode == 25 {
            // NOT
            context.exec_not()?;
        }
        if opcode == 26 {
            // BYTE
            context.exec_byte()?;
        }
        if opcode == 27 {
            // SHL
            context.exec_shl()?;
        }
        if opcode == 28 {
            // SHR
            context.exec_shr()?;
        }
        if opcode == 29 {
            // SAR
            context.exec_sar()?;
        }
        if opcode == 48 {
            // ADDRESS
            context.exec_address()?;
        }
        if opcode == 49 {
            // BALANCE
            context.exec_balance()?;
        }
        if opcode == 50 {
            // ORIGIN
            context.exec_origin()?;
        }
        if opcode == 51 {
            // CALLER
            context.exec_caller()?;
        }
        if opcode == 52 {
            // CALLVALUE
            context.exec_callvalue()?;
        }
        if opcode == 53 {
            // CALLDATALOAD
            context.exec_calldataload()?;
        }
        if opcode == 54 {
            // CALLDATASIZE
            context.exec_calldatasize()?;
        }
        if opcode == 55 {
            // CALLDATACOPY
            context.exec_calldatacopy()?;
        }
        if opcode == 56 {
            // CODESIZE
            context.exec_codesize()?;
        }
        if opcode == 57 {
            // CODECOPY
            context.exec_codecopy()?;
        }
        if opcode == 58 {
            // GASPRICE
            context.exec_gasprice()?;
        }
        if opcode == 59 {
            // EXTCODESIZE
            context.exec_extcodesize()?;
        }
        if opcode == 60 {
            // EXTCODECOPY
            context.exec_extcodecopy()?;
        }
        if opcode == 61 {
            // RETURNDATASIZE
            context.exec_returndatasize()?;
        }
        if opcode == 62 {
            // RETURNDATACOPY
            context.exec_returndatacopy()?;
        }
        if opcode == 63 {
            // EXTCODEHASH
            context.exec_extcodehash()?;
        }
        if opcode == 64 {
            // BLOCKHASH
            context.exec_blockhash()?;
        }
        if opcode == 65 {
            // COINBASE
            context.exec_coinbase()?;
        }
        if opcode == 66 {
            // TIMESTAMP
            context.exec_timestamp()?;
        }
        if opcode == 67 {
            // NUMBER
            context.exec_number()?;
        }
        if opcode == 68 {
            // PREVRANDAO
            context.exec_prevrandao()?;
        }
        if opcode == 69 {
            // GASLIMIT
            context.exec_gaslimit()?;
        }
        if opcode == 70 {
            // CHAINID
            context.exec_chainid()?;
        }
        if opcode == 71 {
            // SELFBALANCE
            context.exec_selfbalance()?;
        }
        if opcode == 72 {
            // BASEFEE
            context.exec_basefee()?;
        }
        if opcode == 80 {
            // POP
            memory_operations::exec_pop(ref context);
        }
        if opcode == 81 {
            // MLOAD
            memory_operations::exec_mload(ref context);
        }
        if opcode == 82 {
            // MSTORE
            memory_operations::exec_mstore(ref context);
        }
        if opcode == 83 {
            // MSTORE8
            memory_operations::exec_mstore8(ref context);
        }
        if opcode == 84 {
            // SLOAD
            memory_operations::exec_sload(ref context);
        }
        if opcode == 85 {
            // SSTORE
            memory_operations::exec_sstore(ref context);
        }
        if opcode == 86 {
            // JUMP
            memory_operations::exec_jump(ref context);
        }
        if opcode == 87 {
            // JUMPI
            memory_operations::exec_jumpi(ref context);
        }
        if opcode == 88 {
            // PC
            memory_operations::exec_pc(ref context);
        }
        if opcode == 89 {
            // MSIZE
            memory_operations::exec_msize(ref context);
        }
        if opcode == 90 {
            // GAS
            memory_operations::exec_gas(ref context);
        }
        if opcode == 91 {
            // JUMPDEST
            memory_operations::exec_jumpdest(ref context);
        }
        if opcode == 95 {
            // PUSH0
            context.exec_push0()?;
        }
        if opcode == 96 {
            // PUSH1
            context.exec_push1()?;
        }
        if opcode == 97 {
            // PUSH2
            context.exec_push2()?;
        }
        if opcode == 98 {
            // PUSH3
            context.exec_push3()?;
        }
        if opcode == 99 {
            // PUSH4
            context.exec_push4()?;
        }
        if opcode == 100 {
            // PUSH5
            context.exec_push5()?;
        }
        if opcode == 101 {
            // PUSH6
            context.exec_push6()?;
        }
        if opcode == 102 {
            // PUSH7
            context.exec_push7()?;
        }
        if opcode == 103 {
            // PUSH8
            context.exec_push8()?;
        }
        if opcode == 104 {
            // PUSH9
            context.exec_push9()?;
        }
        if opcode == 105 {
            // PUSH10
            context.exec_push10()?;
        }
        if opcode == 106 {
            // PUSH11
            context.exec_push11()?;
        }
        if opcode == 107 {
            // PUSH12
            context.exec_push12()?;
        }
        if opcode == 108 {
            // PUSH13
            context.exec_push13()?;
        }
        if opcode == 109 {
            // PUSH14
            context.exec_push14()?;
        }
        if opcode == 110 {
            // PUSH15
            context.exec_push15()?;
        }
        if opcode == 111 {
            // PUSH16
            context.exec_push16()?;
        }
        if opcode == 112 {
            // PUSH17
            context.exec_push17()?;
        }
        if opcode == 113 {
            // PUSH18
            context.exec_push18()?;
        }
        if opcode == 114 {
            // PUSH19
            context.exec_push19()?;
        }
        if opcode == 115 {
            // PUSH20
            context.exec_push20()?;
        }
        if opcode == 116 {
            // PUSH21
            context.exec_push21()?;
        }
        if opcode == 117 {
            // PUSH22
            context.exec_push22()?;
        }
        if opcode == 118 {
            // PUSH23
            context.exec_push23()?;
        }
        if opcode == 119 {
            // PUSH24
            context.exec_push24()?;
        }
        if opcode == 120 {
            // PUSH25
            context.exec_push25()?;
        }
        if opcode == 121 {
            // PUSH26
            context.exec_push26()?;
        }
        if opcode == 122 {
            // PUSH27
            context.exec_push27()?;
        }
        if opcode == 123 {
            // PUSH28
            context.exec_push28()?;
        }
        if opcode == 124 {
            // PUSH29
            context.exec_push29()?;
        }
        if opcode == 125 {
            // PUSH30
            context.exec_push30()?;
        }
        if opcode == 126 {
            // PUSH31
            context.exec_push31()?;
        }
        if opcode == 127 {
            // PUSH32
            context.exec_push32()?;
        }
        if opcode == 128 {
            // DUP1
            context.exec_dup1()?;
        }
        if opcode == 129 {
            // DUP2
            context.exec_dup2()?;
        }
        if opcode == 130 {
            // DUP3
            context.exec_dup3()?;
        }
        if opcode == 131 {
            // DUP4
            context.exec_dup4()?;
        }
        if opcode == 132 {
            // DUP5
            context.exec_dup5()?;
        }
        if opcode == 133 {
            // DUP6
            context.exec_dup6()?;
        }
        if opcode == 134 {
            // DUP7
            context.exec_dup7()?;
        }
        if opcode == 135 {
            // DUP8
            context.exec_dup8()?;
        }
        if opcode == 136 {
            // DUP9
            context.exec_dup9()?;
        }
        if opcode == 137 {
            // DUP10
            context.exec_dup10()?;
        }
        if opcode == 138 {
            // DUP11
            context.exec_dup11()?;
        }
        if opcode == 139 {
            // DUP12
            context.exec_dup12()?;
        }
        if opcode == 140 {
            // DUP13
            context.exec_dup13()?;
        }
        if opcode == 141 {
            // DUP14
            context.exec_dup14()?;
        }
        if opcode == 142 {
            // DUP15
            context.exec_dup15()?;
        }
        if opcode == 143 {
            // DUP16
            context.exec_dup16()?;
        }
        if opcode == 144 {
            // SWAP1
            exchange_operations::exec_swap1(ref context);
        }
        if opcode == 145 {
            // SWAP2
            exchange_operations::exec_swap2(ref context);
        }
        if opcode == 146 {
            // SWAP3
            exchange_operations::exec_swap3(ref context);
        }
        if opcode == 147 {
            // SWAP4
            exchange_operations::exec_swap4(ref context);
        }
        if opcode == 148 {
            // SWAP5
            exchange_operations::exec_swap5(ref context);
        }
        if opcode == 149 {
            // SWAP6
            exchange_operations::exec_swap6(ref context);
        }
        if opcode == 150 {
            // SWAP7
            exchange_operations::exec_swap7(ref context);
        }
        if opcode == 151 {
            // SWAP8
            exchange_operations::exec_swap8(ref context);
        }
        if opcode == 152 {
            // SWAP9
            exchange_operations::exec_swap9(ref context);
        }
        if opcode == 153 {
            // SWAP10
            exchange_operations::exec_swap10(ref context);
        }
        if opcode == 154 {
            // SWAP11
            exchange_operations::exec_swap11(ref context);
        }
        if opcode == 155 {
            // SWAP12
            exchange_operations::exec_swap12(ref context);
        }
        if opcode == 156 {
            // SWAP13
            exchange_operations::exec_swap13(ref context);
        }
        if opcode == 157 {
            // SWAP14
            exchange_operations::exec_swap14(ref context);
        }
        if opcode == 158 {
            // SWAP15
            exchange_operations::exec_swap15(ref context);
        }
        if opcode == 159 {
            // SWAP16
            exchange_operations::exec_swap16(ref context);
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
