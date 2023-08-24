use evm::instructions::EnvironmentInformationTrait;
use evm::tests::test_utils::{setup_execution_context, evm_address};
use evm::stack::StackTrait;
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
use evm::context::BoxDynamicExecutionContextDestruct;

#[test]
#[available_gas(20000000)]
fn test_address_basic() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_address();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    let expected_address: felt252 = evm_address().into();
    let expected_address: u256 = expected_address.into();
    assert(ctx.stack.pop().unwrap() == expected_address, '');
}

#[test]
#[available_gas(20000000)]
#[ignore]
fn test_address_nested_call() { // TODO: Figure out a way to do nested calls
}
