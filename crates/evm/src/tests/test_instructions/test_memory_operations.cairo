use evm::instructions::{MemoryOperationTrait, EnvironmentInformationTrait};
use evm::tests::test_utils::{
    setup_execution_context, setup_execution_context_with_bytecode, evm_address, callvalue
};
use evm::stack::StackTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
use utils::helpers::{EthAddressIntoU256, u256_to_bytes_array};
use evm::errors::{EVMError, STACK_UNDERFLOW};
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait,
};
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
    assert(result.is_ok(), 'should have succeed');
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
fn test_exec_mstore_should_store_only_F_offset_0() {
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
    assert(stored == BoundedInt::<u256>::max(), 'should have store only Fs');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_only_F_offset_1() {
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
    assert(stored == BoundedInt::<u256>::max(), 'should have store only Fs');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_1_offset_1() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x01);
    ctx.stack.push(0x01);

    // When
    let result = ctx.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 64, 'memory should be 64 bytes long');
    let (stored, _) = ctx.memory.load(1);
    assert(stored == 0x01, 'should have store 0x01');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_0xFF_offset_1() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xFF);
    ctx.stack.push(0x01);

    // When
    let result = ctx.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 64, 'memory should be 64 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0x00, 'should be 0s');
    let (stored, _) = ctx.memory.load(2);
    assert(stored == 0xFF00, 'should be 0xFF00');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_0xFF00_offset_1() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xFF00);
    ctx.stack.push(0x01);

    // When
    let result = ctx.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 64, 'memory should be 64 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0xFF, 'should be 0xFF');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_0xFF00_offset_0x20() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xFF00);
    ctx.stack.push(0x20);

    // When
    let result = ctx.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.memory.bytes_len == 96, 'memory should be 96 bytes long');
    let (stored, _) = ctx.memory.load(0);
    assert(stored == 0x00, 'should be 0x00');
    let (stored, _) = ctx.memory.load(0x20);
    assert(stored == 0xFF00, 'should be 0xFF00');
    let (stored, _) = ctx.memory.load(0xF9);
    assert(stored == 0xFF00, 'should be 0xFF');
}
