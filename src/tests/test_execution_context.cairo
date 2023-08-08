// Imports, may need adjustments based on actual dependencies and modules
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use debug::PrintTrait;
use array::{ArrayTrait, SpanTrait};
use kakarot::memory::{Memory, MemoryTrait};
use kakarot::model::Event;
use kakarot::stack::{Stack, StackTrait};
use kakarot::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait};
use kakarot::utils::helpers::{SpanPartialEq};
use traits::PartialEq;
use starknet::{EthAddress, ContractAddress};
use kakarot::tests::utils;
use starknet::testing::{set_contract_address, set_caller_address};

fn setup_call_context() -> CallContext {
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let call_data: Span<u8> = array![4, 5, 6].span();
    let value: u256 = 100;

    CallContextTrait::new(bytecode, call_data, value)
}

fn setup_execution_context() -> ExecutionContext {
    let call_context = setup_call_context();
    let starknet_address: ContractAddress = utils::starknet_address();
    let evm_address: EthAddress = utils::evm_address();
    let gas_limit: u64 = 1000;
    let gas_price: u64 = 10;
    let read_only: bool = false;
    let returned_data = Default::default();

    ExecutionContextTrait::new(
        call_context, starknet_address, evm_address, gas_limit, gas_price, returned_data, read_only
    )
}


#[test]
#[available_gas(1000000)]
fn test_call_context_new() {
    // When
    let call_context = setup_call_context();
// Then
// TODO: uncomment once cairo-test bug is solved

// assert(call_context.bytecode() == bytecode, 'wrong bytecode');
// assert(call_context.value() == value, 'wrong value');
// assert(call_context.call_data() == call_data, 'wrong call_data');
}


#[test]
#[available_gas(100000)]
fn test_execution_context_new_and_intrinsic_gas() {
    // Given
    let mut execution_context = setup_execution_context();

    // Then
    execution_context.process_intrinsic_gas_cost();
    //TODO update checked value once the intrinsic gas cost is implemented in a dynamic way
    assert(execution_context.gas_used == 42, 'wrong gas used');
}

#[test]
#[available_gas(100000)]
fn test_execution_context_stop_and_revert() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    execution_context.stop();

    // Then
    assert(execution_context.is_stopped() == true, 'should be stopped');
}

#[test]
#[available_gas(1000000)]
fn test_execution_context_revert() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    let revert_reason = array![0, 1, 2, 3].span();
    execution_context.revert(revert_reason);

    // Then
    assert(execution_context.is_reverted() == true, 'should be reverted');
}

#[test]
#[available_gas(300000)]
fn test_execution_context_read_code() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    let len = 2;
    let code = execution_context.read_code(len);

    // Then
    assert(code == array![1, 2].span(), 'wrong code read'); // Compare with expected slice
    assert(execution_context.program_counter == len, 'wrong program counter');
}

#[test]
#[available_gas(300000)]
#[ignore]
fn test_is_leaf() {
    // TODO: finish this test once subcontexts are implemented
    // Given
    let mut execution_context = setup_execution_context();
    // execution_context.calling_context = Default::default();

    // When
    let is_leaf = execution_context.is_leaf();
// Then
// assert(is_leaf == false, 'should not be a leaf');
}

#[test]
#[available_gas(300000)]
#[ignore]
fn test_is_root() {
    // TODO: finish this test once calling_contexts are implemented
    // Given
    let mut execution_context = setup_execution_context();

    // When
    let is_root = execution_context.is_root();
// Then
// assert(is_root == true, 'should not be a leaf');
}

#[test]
#[available_gas(300000)]
fn test_is_caller_eoa() {
    // TODO: finish this test once calling_contexts are implemented
    // Given
    let mut execution_context = setup_execution_context();

    // When
    set_caller_address(utils::starknet_address());
    let is_eoa = execution_context.is_caller_eoa();

    // Then
    assert(is_eoa == true, 'should be an eoa');

    // When
    set_caller_address(utils::zero_address());
    let is_eoa = execution_context.is_caller_eoa();

    // Then
    assert(is_eoa == false, 'should not be an eoa');
}
