use evm::instructions::{MemoryOperationTrait, EnvironmentInformationTrait};
use evm::tests::test_utils::{
    setup_execution_context, setup_execution_context_with_bytecode, evm_address, callvalue
};
use evm::stack::StackTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
use utils::helpers::{EthAddressIntoU256, u256_to_bytes_array};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait,
};


#[test]
#[available_gas(20000000)]
fn test_pc_basic() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_pc();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 0, 'PC should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_pc_gets_updated_properly_1() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.set_pc(9000);
    ctx.exec_pc();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 9000, 'updating PC failed');
}

// 0x51 - MLOAD

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('MLOAD not implement yet',))]
fn test_exec_mload_should_load_a_value_from_memory() {
    assert_mload(0x1, 0, 0x1, 32);
}

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('MLOAD not implement yet',))]
fn test_exec_mload_should_load_a_value_from_memory_with_memory_expansion() {
    assert_mload(0x1, 16, 0x100000000000000000000000000000000, 64);
}

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('MLOAD not implement yet',))]
fn test_exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize() {
    assert_mload(0x1, 684, 0x0, 736);
}

fn assert_mload(value: u256, output: u256, expected_value: u256, expected_memory_size: u32) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.memory.store(value, 0);

    ctx.stack.push(output);

    // When
    ctx.exec_mload();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == expected_value, 'mload failed');
    assert(ctx.memory.bytes_len == expected_memory_size, 'memory size error');
}
