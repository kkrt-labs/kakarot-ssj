use evm::instructions::EnvironmentInformationTrait;
use evm::tests::test_utils::{
    setup_execution_context, setup_execution_context_max_stack_depth, evm_address, callvalue
};
use evm::stack::StackTrait;
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
use evm::context::BoxDynamicExecutionContextDestruct;
use utils::helpers::EthAddressIntoU256;
use evm::errors::{EVMError, STACK_OVERFLOW};
use utils::constants;

#[test]
#[available_gas(20000000)]
fn test_address_basic() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_address();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == evm_address().into(), 'should be `evm_address`');
}

#[test]
#[available_gas(20000000)]
#[ignore]
fn test_address_nested_call() { // A (EOA) -(calls)-> B (smart contract) -(calls)-> C (smart contract)
// TODO: Once we have ability to do nested smart contract calls, check that in `C`s context `ADDRESS` should return address `B`
// ref: https://github.com/kkrt-labs/kakarot-ssj/issues/183
}

#[test]
#[available_gas(120000)]
fn test__exec_callvalue() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_callvalue();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == callvalue(), 'should be `123456789');
}

#[test]
#[available_gas(30000000)]
fn test__exec_callvalue_overflow_should_propagate() {
    // Given
    let mut ctx = setup_execution_context_max_stack_depth();

    // When
    let res = ctx.exec_callvalue();

    // Then
    assert(ctx.stack.len() == constants::STACK_MAX_DEPTH, 'wrong length');
    assert(res.is_err(), 'should return error');
    assert(res.unwrap_err() == EVMError::StackError(STACK_OVERFLOW), 'should return StackOverflow');
}
