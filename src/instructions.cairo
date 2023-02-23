/// System imports.
use array::ArrayTrait;
use traits::Into;

/// Internal imports.
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionSummary;
use kakarot::utils;

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
        match get_gas() {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('OOG');
                panic(data);
            }
        }
        // Decode and execute the current opcode.
        self.decode_and_execute(ref context);
        // Check if the execution is complete.
        // TODO: investigate why this is not working. The next line triggers this error:
        // thread 'main' panicked at 'Failed to specialize: `dup<kakarot::context::ExecutionContext>`
        //let stopped = context.stopped;
        // For now we mock values.
        let stopped = true;

        if !stopped {
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
        // TODO: investigate why this is not working. The next line triggers this error:
        // thread 'main' panicked at 'Failed to specialize: `dup<kakarot::context::ExecutionContext>`
        // Retrieve the current program counter.
        // let pc = context.program_counter;
        // let bytecode_len = context.call_context.bytecode.len();
        // let opcode = context.call_context.bytecode.at(pc);
        // For now we mock values.
        let pc = 0_u32;
        let opcode = 0_u8;
        let bytecode_len = 100_u32;

        // Check if PC is not out of bounds.
        if pc >= bytecode_len {
            utils::panic_with_code(0);
        }

        // Call the appropriate function based on the opcode.
        if opcode == 0_u8 {
            // STOP
            stop_and_arithmetic_operations::exec_stop(ref context);
        }
        if opcode == 1_u8 {
            // ADD
            stop_and_arithmetic_operations::exec_add(ref context);
        }
        if opcode == 2_u8 {
            // MUL
            stop_and_arithmetic_operations::exec_mul(ref context);
        }
        if opcode == 3_u8 {
            // SUB
            stop_and_arithmetic_operations::exec_sub(ref context);
        }
        if opcode == 4_u8 {
            // DIV
            stop_and_arithmetic_operations::exec_div(ref context);
        }
        if opcode == 5_u8 {
            // SDIV
            stop_and_arithmetic_operations::exec_sdiv(ref context);
        }
        if opcode == 6_u8 {
            // MOD
            stop_and_arithmetic_operations::exec_mod(ref context);
        }
        if opcode == 7_u8 {
            // SMOD
            stop_and_arithmetic_operations::exec_smod(ref context);
        }
        if opcode == 8_u8 {
            // ADDMOD
            stop_and_arithmetic_operations::exec_addmod(ref context);
        }
        if opcode == 9_u8 {
            // MULMOD
            stop_and_arithmetic_operations::exec_mulmod(ref context);
        }
        if opcode == 10_u8 {
            // EXP
            stop_and_arithmetic_operations::exec_exp(ref context);
        }
        if opcode == 11_u8 {
            // SIGNEXTEND
            stop_and_arithmetic_operations::exec_signextend(ref context);
        }
        if opcode == 16_u8 {
            // LT
            comparison_operations::exec_lt(ref context);
        }
        if opcode == 17_u8 {
            // GT
            comparison_operations::exec_gt(ref context);
        }
        if opcode == 18_u8 {
            // SLT
            comparison_operations::exec_slt(ref context);
        }
        if opcode == 19_u8 {
            // SGT
            comparison_operations::exec_sgt(ref context);
        }
        if opcode == 20_u8 {
            // EQ
            comparison_operations::exec_eq(ref context);
        }
        if opcode == 21_u8 {
            // ISZERO
            comparison_operations::exec_iszero(ref context);
        }
        if opcode == 22_u8 {
            // AND
            comparison_operations::exec_and(ref context);
        }
        if opcode == 23_u8 {
            // OR
            comparison_operations::exec_or(ref context);
        }
        if opcode == 24_u8 {
            // XOR
            comparison_operations::exec_xor(ref context);
        }
        if opcode == 25_u8 {
            // NOT
            comparison_operations::exec_not(ref context);
        }
        if opcode == 26_u8 {
            // BYTE
            comparison_operations::exec_byte(ref context);
        }
        if opcode == 27_u8 {
            // SHL
            comparison_operations::exec_shl(ref context);
        }
        if opcode == 28_u8 {
            // SHR
            comparison_operations::exec_shr(ref context);
        }
        if opcode == 29_u8 {
            // SAR
            comparison_operations::exec_sar(ref context);
        }
        if opcode == 48_u8 {
            // ADDRESS
            environmental_information::exec_address(ref context);
        }
        if opcode == 49_u8 {
            // BALANCE
            environmental_information::exec_balance(ref context);
        }
        if opcode == 50_u8 {
            // ORIGIN
            environmental_information::exec_origin(ref context);
        }
        if opcode == 51_u8 {
            // CALLER
            environmental_information::exec_caller(ref context);
        }
        if opcode == 52_u8 {
            // CALLVALUE
            environmental_information::exec_callvalue(ref context);
        }
        if opcode == 53_u8 {
            // CALLDATALOAD
            environmental_information::exec_calldataload(ref context);
        }
        if opcode == 54_u8 {
            // CALLDATASIZE
            environmental_information::exec_calldatasize(ref context);
        }
        if opcode == 55_u8 {
            // CALLDATACOPY
            environmental_information::exec_calldatacopy(ref context);
        }
        if opcode == 56_u8 {
            // CODESIZE
            environmental_information::exec_codesize(ref context);
        }
        if opcode == 57_u8 {
            // CODECOPY
            environmental_information::exec_codecopy(ref context);
        }
        if opcode == 58_u8 {
            // GASPRICE
            environmental_information::exec_gasprice(ref context);
        }
        if opcode == 59_u8 {
            // EXTCODESIZE
            environmental_information::exec_extcodesize(ref context);
        }
        if opcode == 60_u8 {
            // EXTCODECOPY
            environmental_information::exec_extcodecopy(ref context);
        }
        if opcode == 61_u8 {
            // RETURNDATASIZE
            environmental_information::exec_returndatasize(ref context);
        }
        if opcode == 62_u8 {
            // RETURNDATACOPY
            environmental_information::exec_returndatacopy(ref context);
        }
        if opcode == 63_u8 {
            // EXTCODEHASH
            environmental_information::exec_extcodehash(ref context);
        }
        if opcode == 64_u8 {
            // BLOCKHASH
            block_information::exec_blockhash(ref context);
        }
        if opcode == 65_u8 {
            // COINBASE
            block_information::exec_coinbase(ref context);
        }
        if opcode == 66_u8 {
            // TIMESTAMP
            block_information::exec_timestamp(ref context);
        }
        if opcode == 67_u8 {
            // NUMBER
            block_information::exec_number(ref context);
        }
        if opcode == 68_u8 {
            // DIFFICULTY
            block_information::exec_difficulty(ref context);
        }
        if opcode == 69_u8 {
            // GASLIMIT
            block_information::exec_gaslimit(ref context);
        }
        if opcode == 70_u8 {
            // CHAINID
            block_information::exec_chainid(ref context);
        }
        if opcode == 71_u8 {
            // SELFBALANCE
            block_information::exec_selfbalance(ref context);
        }
        if opcode == 72_u8 {
            // BASEFEE
            block_information::exec_basefee(ref context);
        }
        if opcode == 80_u8 {
            // POP
            memory_operations::exec_pop(ref context);
        }
        if opcode == 81_u8 {
            // MLOAD
            memory_operations::exec_mload(ref context);
        }
        if opcode == 82_u8 {
            // MSTORE
            memory_operations::exec_mstore(ref context);
        }
        if opcode == 83_u8 {
            // MSTORE8
            memory_operations::exec_mstore8(ref context);
        }
        if opcode == 84_u8 {
            // SLOAD
            memory_operations::exec_sload(ref context);
        }
        if opcode == 85_u8 {
            // SSTORE
            memory_operations::exec_sstore(ref context);
        }
        if opcode == 86_u8 {
            // JUMP
            memory_operations::exec_jump(ref context);
        }
        if opcode == 87_u8 {
            // JUMPI
            memory_operations::exec_jumpi(ref context);
        }
        if opcode == 88_u8 {
            // PC
            memory_operations::exec_pc(ref context);
        }
        if opcode == 89_u8 {
            // MSIZE
            memory_operations::exec_msize(ref context);
        }
        if opcode == 90_u8 {
            // GAS
            memory_operations::exec_gas(ref context);
        }
        if opcode == 91_u8 {
            // JUMPDEST
            memory_operations::exec_jumpdest(ref context);
        }
        if opcode == 96_u8 {
            // PUSH1
            push_operations::exec_push1(ref context);
        }
        if opcode == 97_u8 {
            // PUSH2
            push_operations::exec_push2(ref context);
        }
        if opcode == 98_u8 {
            // PUSH3
            push_operations::exec_push3(ref context);
        }
        if opcode == 99_u8 {
            // PUSH4
            push_operations::exec_push4(ref context);
        }
        if opcode == 100_u8 {
            // PUSH5
            push_operations::exec_push5(ref context);
        }
        if opcode == 101_u8 {
            // PUSH6
            push_operations::exec_push6(ref context);
        }
        if opcode == 102_u8 {
            // PUSH7
            push_operations::exec_push7(ref context);
        }
        if opcode == 103_u8 {
            // PUSH8
            push_operations::exec_push8(ref context);
        }
        if opcode == 104_u8 {
            // PUSH9
            push_operations::exec_push9(ref context);
        }
        if opcode == 105_u8 {
            // PUSH10
            push_operations::exec_push10(ref context);
        }
        if opcode == 106_u8 {
            // PUSH11
            push_operations::exec_push11(ref context);
        }
        if opcode == 107_u8 {
            // PUSH12
            push_operations::exec_push12(ref context);
        }
        if opcode == 108_u8 {
            // PUSH13
            push_operations::exec_push13(ref context);
        }
        if opcode == 109_u8 {
            // PUSH14
            push_operations::exec_push14(ref context);
        }
        if opcode == 110_u8 {
            // PUSH15
            push_operations::exec_push15(ref context);
        }
        if opcode == 111_u8 {
            // PUSH16
            push_operations::exec_push16(ref context);
        }
        if opcode == 112_u8 {
            // PUSH17
            push_operations::exec_push17(ref context);
        }
        if opcode == 113_u8 {
            // PUSH18
            push_operations::exec_push18(ref context);
        }
        if opcode == 114_u8 {
            // PUSH19
            push_operations::exec_push19(ref context);
        }
        if opcode == 115_u8 {
            // PUSH20
            push_operations::exec_push20(ref context);
        }
        if opcode == 116_u8 {
            // PUSH21
            push_operations::exec_push21(ref context);
        }
        if opcode == 117_u8 {
            // PUSH22
            push_operations::exec_push22(ref context);
        }
        if opcode == 118_u8 {
            // PUSH23
            push_operations::exec_push23(ref context);
        }
        if opcode == 119_u8 {
            // PUSH24
            push_operations::exec_push24(ref context);
        }
        if opcode == 120_u8 {
            // PUSH25
            push_operations::exec_push25(ref context);
        }
        if opcode == 121_u8 {
            // PUSH26
            push_operations::exec_push26(ref context);
        }
        if opcode == 122_u8 {
            // PUSH27
            push_operations::exec_push27(ref context);
        }
        if opcode == 123_u8 {
            // PUSH28
            push_operations::exec_push28(ref context);
        }
        if opcode == 124_u8 {
            // PUSH29
            push_operations::exec_push29(ref context);
        }
        if opcode == 125_u8 {
            // PUSH30
            push_operations::exec_push30(ref context);
        }
        if opcode == 126_u8 {
            // PUSH31
            push_operations::exec_push31(ref context);
        }
        if opcode == 127_u8 {
            // PUSH32
            push_operations::exec_push32(ref context);
        }
        if opcode == 128_u8 {
            // DUP1
            duplication_operations::exec_dup1(ref context);
        }
        if opcode == 129_u8 {
            // DUP2
            duplication_operations::exec_dup2(ref context);
        }
        if opcode == 130_u8 {
            // DUP3
            duplication_operations::exec_dup3(ref context);
        }
        if opcode == 131_u8 {
            // DUP4
            duplication_operations::exec_dup4(ref context);
        }
        if opcode == 132_u8 {
            // DUP5
            duplication_operations::exec_dup5(ref context);
        }
        if opcode == 133_u8 {
            // DUP6
            duplication_operations::exec_dup6(ref context);
        }
        if opcode == 134_u8 {
            // DUP7
            duplication_operations::exec_dup7(ref context);
        }
        if opcode == 135_u8 {
            // DUP8
            duplication_operations::exec_dup8(ref context);
        }
        if opcode == 136_u8 {
            // DUP9
            duplication_operations::exec_dup9(ref context);
        }
        if opcode == 137_u8 {
            // DUP10
            duplication_operations::exec_dup10(ref context);
        }
        if opcode == 138_u8 {
            // DUP11
            duplication_operations::exec_dup11(ref context);
        }
        if opcode == 139_u8 {
            // DUP12
            duplication_operations::exec_dup12(ref context);
        }
        if opcode == 140_u8 {
            // DUP13
            duplication_operations::exec_dup13(ref context);
        }
        if opcode == 141_u8 {
            // DUP14
            duplication_operations::exec_dup14(ref context);
        }
        if opcode == 142_u8 {
            // DUP15
            duplication_operations::exec_dup15(ref context);
        }
        if opcode == 143_u8 {
            // DUP16
            duplication_operations::exec_dup16(ref context);
        }
        if opcode == 144_u8 {
            // SWAP1
            exchange_operations::exec_swap1(ref context);
        }
        if opcode == 145_u8 {
            // SWAP2
            exchange_operations::exec_swap2(ref context);
        }
        if opcode == 146_u8 {
            // SWAP3
            exchange_operations::exec_swap3(ref context);
        }
        if opcode == 147_u8 {
            // SWAP4
            exchange_operations::exec_swap4(ref context);
        }
        if opcode == 148_u8 {
            // SWAP5
            exchange_operations::exec_swap5(ref context);
        }
        if opcode == 149_u8 {
            // SWAP6
            exchange_operations::exec_swap6(ref context);
        }
        if opcode == 150_u8 {
            // SWAP7
            exchange_operations::exec_swap7(ref context);
        }
        if opcode == 151_u8 {
            // SWAP8
            exchange_operations::exec_swap8(ref context);
        }
        if opcode == 152_u8 {
            // SWAP9
            exchange_operations::exec_swap9(ref context);
        }
        if opcode == 153_u8 {
            // SWAP10
            exchange_operations::exec_swap10(ref context);
        }
        if opcode == 154_u8 {
            // SWAP11
            exchange_operations::exec_swap11(ref context);
        }
        if opcode == 155_u8 {
            // SWAP12
            exchange_operations::exec_swap12(ref context);
        }
        if opcode == 156_u8 {
            // SWAP13
            exchange_operations::exec_swap13(ref context);
        }
        if opcode == 157_u8 {
            // SWAP14
            exchange_operations::exec_swap14(ref context);
        }
        if opcode == 158_u8 {
            // SWAP15
            exchange_operations::exec_swap15(ref context);
        }
        if opcode == 159_u8 {
            // SWAP16
            exchange_operations::exec_swap16(ref context);
        }
        if opcode == 160_u8 {
            // LOG0
            logging_operations::exec_log0(ref context);
        }
        if opcode == 161_u8 {
            // LOG1
            logging_operations::exec_log1(ref context);
        }
        if opcode == 162_u8 {
            // LOG2
            logging_operations::exec_log2(ref context);
        }
        if opcode == 163_u8 {
            // LOG3
            logging_operations::exec_log3(ref context);
        }
        if opcode == 164_u8 {
            // LOG4
            logging_operations::exec_log4(ref context);
        }
        if opcode == 240_u8 {
            // CREATE
            system_operations::exec_create(ref context);
        }
        if opcode == 241_u8 {
            // CALL
            system_operations::exec_call(ref context);
        }
        if opcode == 242_u8 {
            // CALLCODE
            system_operations::exec_callcode(ref context);
        }
        if opcode == 243_u8 {
            // RETURN
            system_operations::exec_return(ref context);
        }
        if opcode == 244_u8 {
            // DELEGATECALL
            system_operations::exec_delegatecall(ref context);
        }
        if opcode == 245_u8 {
            // CREATE2
            system_operations::exec_create2(ref context);
        }
        if opcode == 250_u8 {
            // STATICCALL
            system_operations::exec_staticcall(ref context);
        }
        if opcode == 253_u8 {
            // REVERT
            system_operations::exec_revert(ref context);
        }
        if opcode == 254_u8 {
            // INVALID
            system_operations::exec_invalid(ref context);
        }
        if opcode == 255_u8 {
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
