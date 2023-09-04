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

#[test]
#[available_gas(20000000)]
fn test_pc_gets_updated_properly_2() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.set_pc(42);
    ctx.exec_pc();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 42, 'updating PC failed');
}

#[test]
#[available_gas(20000000)]
fn test_pc_gets_updated_properly_3() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.set_pc(7);
    ctx.exec_pc();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == 7, 'updating PC failed');
}
