/// System imports.
use array::ArrayTrait;
use array::SpanTrait;
use traits::Into;

/// Internal imports.
// TODO remove destruct imports when no longer required
use kakarot::context::{ExecutionContext, NullableDestruct, BoxDestruct};
use kakarot::context::CallContextTrait;
use kakarot::context::ExecutionSummary;
use kakarot::utils;
use kakarot::errors;

/// Sub modules.
mod block_information;
mod comparison_operations;
mod duplication_operations;
mod environmental_information;
mod exchange_operations;
mod logging_operations;
mod memory_operations;
mod push_operations;
mod sha3;
mod stop_and_arithmetic_operations;
mod system_operations;

/// EVM instructions as defined in the Yellow Paper and the EIPs.
#[derive(Drop, Copy)]
struct EVMInstructions {}

trait EVMInstructionsTrait {
    /// Create a new instance of the EVM instructions.
    fn new() -> EVMInstructions;
    /// Execute the EVM bytecode.
    fn run(ref self: EVMInstructions, ref context: ExecutionContext);
    /// Decode the current opcode and execute associated function.
    fn decode_and_execute(ref self: EVMInstructions, ref context: ExecutionContext);
}


impl EVMInstructionsImpl of EVMInstructionsTrait {
    /// Create a new instance of the EVM instructions.
    #[inline(always)]
    fn new() -> EVMInstructions {
        EVMInstructions {}
    }

    /// Execute the EVM bytecode.
    fn run(ref self: EVMInstructions, ref context: ExecutionContext) {
        // Decode and execute the current opcode.
        self.decode_and_execute(ref context);
        // Check if the execution is complete.
        if !*(@context).stopped {
            // Execute the next opcode.
            self.run(ref context);
        }
    }

    ///  Decode the current opcode and execute associated function.
    /// # Arguments
    /// * `self` - The EVM instructions.
    /// * `context` - The execution context.
    /// # Returns
    /// The execution summary.
    fn decode_and_execute(ref self: EVMInstructions, ref context: ExecutionContext) {
        // Retrieve the current program counter.
        let pc = context.program_counter;
        let bytecode = (@context).call_context.bytecode(); //Note: here, bytecode returns a Span
        let bytecode_len = bytecode.len();

        // Check if PC is not out of bounds.
        if pc >= bytecode_len {
            utils::panic_with_code(errors::PC_OUT_OF_BOUNDS);
        }

        let opcode: u8 = *bytecode.at(pc);

        // Call the appropriate function based on the opcode.
        if opcode == 0 {
            // STOP
            stop_and_arithmetic_operations::exec_stop(ref context);
        }
        if opcode == 1 {
            // ADD
            stop_and_arithmetic_operations::exec_add(ref context);
        }
        if opcode == 2 {
            // MUL
            stop_and_arithmetic_operations::exec_mul(ref context);
        }
        if opcode == 3 {
            // SUB
            stop_and_arithmetic_operations::exec_sub(ref context);
        }
        if opcode == 4 {
            // DIV
            stop_and_arithmetic_operations::exec_div(ref context);
        }
        if opcode == 5 {
            // SDIV
            stop_and_arithmetic_operations::exec_sdiv(ref context);
        }
        if opcode == 6 {
            // MOD
            stop_and_arithmetic_operations::exec_mod(ref context);
        }
        if opcode == 7 {
            // SMOD
            stop_and_arithmetic_operations::exec_smod(ref context);
        }
        if opcode == 8 {
            // ADDMOD
            stop_and_arithmetic_operations::exec_addmod(ref context);
        }
        if opcode == 9 {
            // MULMOD
            stop_and_arithmetic_operations::exec_mulmod(ref context);
        }
        if opcode == 10 {
            // EXP
            stop_and_arithmetic_operations::exec_exp(ref context);
        }
        if opcode == 11 {
            // SIGNEXTEND
            stop_and_arithmetic_operations::exec_signextend(ref context);
        }
        if opcode == 16 {
            // LT
            comparison_operations::exec_lt(ref context);
        }
        if opcode == 17 {
            // GT
            comparison_operations::exec_gt(ref context);
        }
        if opcode == 18 {
            // SLT
            comparison_operations::exec_slt(ref context);
        }
        if opcode == 19 {
            // SGT
            comparison_operations::exec_sgt(ref context);
        }
        if opcode == 20 {
            // EQ
            comparison_operations::exec_eq(ref context);
        }
        if opcode == 21 {
            // ISZERO
            comparison_operations::exec_iszero(ref context);
        }
        if opcode == 22 {
            // AND
            comparison_operations::exec_and(ref context);
        }
        if opcode == 23 {
            // OR
            comparison_operations::exec_or(ref context);
        }
        if opcode == 24 {
            // XOR
            comparison_operations::exec_xor(ref context);
        }
        if opcode == 25 {
            // NOT
            comparison_operations::exec_not(ref context);
        }
        if opcode == 26 {
            // BYTE
            comparison_operations::exec_byte(ref context);
        }
        if opcode == 27 {
            // SHL
            comparison_operations::exec_shl(ref context);
        }
        if opcode == 28 {
            // SHR
            comparison_operations::exec_shr(ref context);
        }
        if opcode == 29 {
            // SAR
            comparison_operations::exec_sar(ref context);
        }
        if opcode == 48 {
            // ADDRESS
            environmental_information::exec_address(ref context);
        }
        if opcode == 49 {
            // BALANCE
            environmental_information::exec_balance(ref context);
        }
        if opcode == 50 {
            // ORIGIN
            environmental_information::exec_origin(ref context);
        }
        if opcode == 51 {
            // CALLER
            environmental_information::exec_caller(ref context);
        }
        if opcode == 52 {
            // CALLVALUE
            environmental_information::exec_callvalue(ref context);
        }
        if opcode == 53 {
            // CALLDATALOAD
            environmental_information::exec_calldataload(ref context);
        }
        if opcode == 54 {
            // CALLDATASIZE
            environmental_information::exec_calldatasize(ref context);
        }
        if opcode == 55 {
            // CALLDATACOPY
            environmental_information::exec_calldatacopy(ref context);
        }
        if opcode == 56 {
            // CODESIZE
            environmental_information::exec_codesize(ref context);
        }
        if opcode == 57 {
            // CODECOPY
            environmental_information::exec_codecopy(ref context);
        }
        if opcode == 58 {
            // GASPRICE
            environmental_information::exec_gasprice(ref context);
        }
        if opcode == 59 {
            // EXTCODESIZE
            environmental_information::exec_extcodesize(ref context);
        }
        if opcode == 60 {
            // EXTCODECOPY
            environmental_information::exec_extcodecopy(ref context);
        }
        if opcode == 61 {
            // RETURNDATASIZE
            environmental_information::exec_returndatasize(ref context);
        }
        if opcode == 62 {
            // RETURNDATACOPY
            environmental_information::exec_returndatacopy(ref context);
        }
        if opcode == 63 {
            // EXTCODEHASH
            environmental_information::exec_extcodehash(ref context);
        }
        if opcode == 64 {
            // BLOCKHASH
            block_information::exec_blockhash(ref context);
        }
        if opcode == 65 {
            // COINBASE
            block_information::exec_coinbase(ref context);
        }
        if opcode == 66 {
            // TIMESTAMP
            block_information::exec_timestamp(ref context);
        }
        if opcode == 67 {
            // NUMBER
            block_information::exec_number(ref context);
        }
        if opcode == 68 {
            // DIFFICULTY
            block_information::exec_difficulty(ref context);
        }
        if opcode == 69 {
            // GASLIMIT
            block_information::exec_gaslimit(ref context);
        }
        if opcode == 70 {
            // CHAINID
            block_information::exec_chainid(ref context);
        }
        if opcode == 71 {
            // SELFBALANCE
            block_information::exec_selfbalance(ref context);
        }
        if opcode == 72 {
            // BASEFEE
            block_information::exec_basefee(ref context);
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
        if opcode == 96 {
            // PUSH1
            push_operations::exec_push1(ref context);
        }
        if opcode == 97 {
            // PUSH2
            push_operations::exec_push2(ref context);
        }
        if opcode == 98 {
            // PUSH3
            push_operations::exec_push3(ref context);
        }
        if opcode == 99 {
            // PUSH4
            push_operations::exec_push4(ref context);
        }
        if opcode == 100 {
            // PUSH5
            push_operations::exec_push5(ref context);
        }
        if opcode == 101 {
            // PUSH6
            push_operations::exec_push6(ref context);
        }
        if opcode == 102 {
            // PUSH7
            push_operations::exec_push7(ref context);
        }
        if opcode == 103 {
            // PUSH8
            push_operations::exec_push8(ref context);
        }
        if opcode == 104 {
            // PUSH9
            push_operations::exec_push9(ref context);
        }
        if opcode == 105 {
            // PUSH10
            push_operations::exec_push10(ref context);
        }
        if opcode == 106 {
            // PUSH11
            push_operations::exec_push11(ref context);
        }
        if opcode == 107 {
            // PUSH12
            push_operations::exec_push12(ref context);
        }
        if opcode == 108 {
            // PUSH13
            push_operations::exec_push13(ref context);
        }
        if opcode == 109 {
            // PUSH14
            push_operations::exec_push14(ref context);
        }
        if opcode == 110 {
            // PUSH15
            push_operations::exec_push15(ref context);
        }
        if opcode == 111 {
            // PUSH16
            push_operations::exec_push16(ref context);
        }
        if opcode == 112 {
            // PUSH17
            push_operations::exec_push17(ref context);
        }
        if opcode == 113 {
            // PUSH18
            push_operations::exec_push18(ref context);
        }
        if opcode == 114 {
            // PUSH19
            push_operations::exec_push19(ref context);
        }
        if opcode == 115 {
            // PUSH20
            push_operations::exec_push20(ref context);
        }
        if opcode == 116 {
            // PUSH21
            push_operations::exec_push21(ref context);
        }
        if opcode == 117 {
            // PUSH22
            push_operations::exec_push22(ref context);
        }
        if opcode == 118 {
            // PUSH23
            push_operations::exec_push23(ref context);
        }
        if opcode == 119 {
            // PUSH24
            push_operations::exec_push24(ref context);
        }
        if opcode == 120 {
            // PUSH25
            push_operations::exec_push25(ref context);
        }
        if opcode == 121 {
            // PUSH26
            push_operations::exec_push26(ref context);
        }
        if opcode == 122 {
            // PUSH27
            push_operations::exec_push27(ref context);
        }
        if opcode == 123 {
            // PUSH28
            push_operations::exec_push28(ref context);
        }
        if opcode == 124 {
            // PUSH29
            push_operations::exec_push29(ref context);
        }
        if opcode == 125 {
            // PUSH30
            push_operations::exec_push30(ref context);
        }
        if opcode == 126 {
            // PUSH31
            push_operations::exec_push31(ref context);
        }
        if opcode == 127 {
            // PUSH32
            push_operations::exec_push32(ref context);
        }
        if opcode == 128 {
            // DUP1
            duplication_operations::exec_dup1(ref context);
        }
        if opcode == 129 {
            // DUP2
            duplication_operations::exec_dup2(ref context);
        }
        if opcode == 130 {
            // DUP3
            duplication_operations::exec_dup3(ref context);
        }
        if opcode == 131 {
            // DUP4
            duplication_operations::exec_dup4(ref context);
        }
        if opcode == 132 {
            // DUP5
            duplication_operations::exec_dup5(ref context);
        }
        if opcode == 133 {
            // DUP6
            duplication_operations::exec_dup6(ref context);
        }
        if opcode == 134 {
            // DUP7
            duplication_operations::exec_dup7(ref context);
        }
        if opcode == 135 {
            // DUP8
            duplication_operations::exec_dup8(ref context);
        }
        if opcode == 136 {
            // DUP9
            duplication_operations::exec_dup9(ref context);
        }
        if opcode == 137 {
            // DUP10
            duplication_operations::exec_dup10(ref context);
        }
        if opcode == 138 {
            // DUP11
            duplication_operations::exec_dup11(ref context);
        }
        if opcode == 139 {
            // DUP12
            duplication_operations::exec_dup12(ref context);
        }
        if opcode == 140 {
            // DUP13
            duplication_operations::exec_dup13(ref context);
        }
        if opcode == 141 {
            // DUP14
            duplication_operations::exec_dup14(ref context);
        }
        if opcode == 142 {
            // DUP15
            duplication_operations::exec_dup15(ref context);
        }
        if opcode == 143 {
            // DUP16
            duplication_operations::exec_dup16(ref context);
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
    }
}

/// This function is called when an unknown opcode is encountered.
/// # Arguments
/// * `opcode` - The unknown opcode
/// # TODO
/// * Implement this function and revert execution.
fn unknown_opcode(opcode: u8) {}
