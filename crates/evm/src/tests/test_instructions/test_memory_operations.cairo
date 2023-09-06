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
