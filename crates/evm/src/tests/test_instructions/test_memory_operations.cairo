use evm::instructions::{MemoryOperationTrait, EnvironmentInformationTrait};
use evm::tests::test_utils::{
    setup_execution_context, setup_execution_context_with_bytecode, evm_address, callvalue
};
use evm::stack::StackTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};

use starknet::EthAddressIntoFelt252;
use utils::helpers::{u256_to_bytes_array};
use utils::traits::{EthAddressIntoU256};
use evm::errors::{EVMError, STACK_UNDERFLOW};
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait,
};
use evm::helpers::U256IntoResultU32;
use integer::BoundedInt;


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
fn test_exec_mload_should_load_a_value_from_memory() {
    assert_mload(0x1, 0, 0x1, 32);
}

#[test]
#[available_gas(20000000000)]
fn test_exec_mload_should_load_a_value_from_memory_with_memory_expansion() {
    assert_mload(0x1, 16, 0x100000000000000000000000000000000, 64);
}

#[test]
#[available_gas(20000000000)]
fn test_exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize() {
    assert_mload(0x1, 684, 0x0, 736);
}

fn assert_mload(value: u256, offset: u256, expected_value: u256, expected_memory_size: u32) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.memory.store(value, 0);

    ctx.stack.push(offset);

    // When
    ctx.exec_mload();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == expected_value, 'mload failed');
    assert(ctx.memory.bytes_len == expected_memory_size, 'memory size error');
}

#[test]
#[available_gas(20000000)]
fn test_exec_pop_should_pop_an_item_from_stack() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x01);
    ctx.stack.push(0x02);

    // When
    let result = ctx.exec_pop();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x01, 'stack peek should return 0x01');
}

#[test]
#[available_gas(20000000)]
fn test_exec_pop_should_stack_underflow() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    let result = ctx.exec_pop();

    // Then
    assert(result.is_err(), 'should return Err ');
    assert(
        result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW), 'should return StackUnderflow'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_max_uint256_offset_0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x00);

    // When
    let result = ctx.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 32, 'memory should be 32 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == BoundedInt::<u256>::max(), 'should have stored max_uint256');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_max_uint256_offset_1() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x01);

    // When
    let result = ctx.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 64, 'memory should be 64 bytes long');
    let (stored, _) = ctx.memory.load(1);
    assert(stored == BoundedInt::<u256>::max(), 'should have stored max_uint256');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_uint8_offset_31() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xAB);
    ctx.stack.push(31);

    // When
    let result = ctx.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 32, 'memory should be 32 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0xAB, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_uint8_offset_30() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xAB);
    ctx.stack.push(30);

    // When
    let result = ctx.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 32, 'memory should be 32 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0xAB00, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_uint8_offset_31_then_uint8_offset_30() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xAB);
    ctx.stack.push(30);
    ctx.stack.push(0xCD);
    ctx.stack.push(31);

    // When
    let result1 = ctx.exec_mstore8();
    let result2 = ctx.exec_mstore8();

    // Then
    assert(result1.is_ok() && result2.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 32, 'memory should be 32 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0xABCD, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_last_uint8_offset_31() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x123456789ABCDEF);
    ctx.stack.push(31);

    // When
    let result = ctx.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 32, 'memory should be 32 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0xEF, 'mstore8 failed');
}


#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_last_uint8_offset_63() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x123456789ABCDEF);
    ctx.stack.push(63);

    // When
    let result = ctx.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 64, 'memory should be 64 bytes long');
    let (stored, _) = ctx.memory.load(32);
    assert(stored == 0xEF, 'mstore8 failed');
}


#[test]
#[available_gas(20000000)]
fn test_msize_initial() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    let result = ctx.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 0, 'initial memory size should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_msize_store_max_offset_0() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.memory.store(BoundedInt::<u256>::max(), 0x00);

    // When
    let result = ctx.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 32, 'should 32 bytes after MSTORE');
}

#[test]
#[available_gas(20000000)]
fn test_exec_msize_store_max_offset_1() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.memory.store(BoundedInt::<u256>::max(), 0x01);

    // When
    let result = ctx.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 64, 'should 64 bytes after MSTORE');
}
