// Imports, may need adjustments based on actual dependencies and modules
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use debug::PrintTrait;
use traits::PartialEq;
use array::{ArrayTrait, SpanTrait};
use starknet::{EthAddress, ContractAddress};
use starknet::testing::{set_contract_address, set_caller_address};

use kakarot::memory::{Memory, MemoryTrait};
use kakarot::model::Event;
use kakarot::stack::{Stack, StackTrait};
use kakarot::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait,
    DynamicExecutionContextTrait, StaticExecutionContextTrait
};
//TODO remove import once merged in corelib
use kakarot::utils::helpers::{SpanPartialEq, ArrayPartialEq};
use kakarot::tests::test_utils::{setup_call_context, setup_execution_context, CallContextPartialEq};
use kakarot::tests::test_utils;

// TODO remove once no longer required (see https://github.com/starkware-libs/cairo/issues/3863)
#[inline(never)]
fn no_op() {}


#[test]
#[available_gas(1000000)]
fn test_call_context_new() {
    // When
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let call_data: Span<u8> = array![4, 5, 6].span();
    let value: u256 = 100;

    let call_ctx = CallContextTrait::new(bytecode, call_data, value);
    // TODO remove once no longer required (see https://github.com/starkware-libs/cairo/issues/3863)
    no_op();

    // Then
    assert(call_ctx.bytecode() == bytecode, 'wrong bytecode');
    assert(call_ctx.call_data() == call_data, 'wrong call_data');
    assert(call_ctx.value() == value, 'wrong value');
}

#[test]
#[available_gas(500000)]
fn test_execution_context_new() {
    // Given
    let call_context = setup_call_context();
    let program_counter: u32 = 0;
    let stack = StackTrait::new();
    let stopped: bool = false;
    let return_data: Array<u8> = ArrayTrait::new();
    let memory = MemoryTrait::new();
    let gas_used: u64 = 0;
    let gas_limit: u64 = 1000;
    let gas_price: u64 = 10;
    let starknet_address: ContractAddress = 0.try_into().unwrap();
    let evm_address: EthAddress = 0.try_into().unwrap();
    let destroy_contracts: Array<EthAddress> = Default::default();
    let events: Array<Event> = Default::default();
    let create_addresses: Array<EthAddress> = Default::default();
    let revert_contract_state: Felt252Dict<felt252> = Default::default();
    let reverted: bool = false;
    let read_only: bool = false;

    // When
    let execution_context = ExecutionContextTrait::new(
        call_context, starknet_address, evm_address, gas_limit, gas_price, return_data, read_only
    );

    // Then
    let call_context = setup_call_context();
    assert(execution_context.static_context.call_context == call_context, 'wrong call_context');
    assert(execution_context.program_counter == program_counter, 'wrong program_counter');
    assert(execution_context.stack.is_empty(), 'wrong stack');
    assert(execution_context.dynamic_context.stopped == stopped, 'wrong stopped');
    assert(
        execution_context.dynamic_context.return_data == Default::default(), 'wrong return_data'
    );
    assert(execution_context.memory.bytes_len == 0, 'wrong memory');
    assert(
        execution_context.static_context.starknet_address == starknet_address,
        'wrong starknet_address'
    );
    assert(execution_context.static_context.evm_address == evm_address, 'wrong evm_address');
    assert(
        execution_context.dynamic_context.destroy_contracts == destroy_contracts,
        'wrong destroy_contracts'
    );
    assert(execution_context.dynamic_context.events.len() == events.len(), 'wrong events');
    assert(
        execution_context.dynamic_context.create_addresses == create_addresses,
        'wrong create_addresses'
    );
    // Can't verify that reverted_contract_state is empty as we can't compare dictionaries directly
    // But initializing it using `Default`, it will be empty.
    assert(execution_context.dynamic_context.reverted == reverted, 'wrong reverted');
    assert(execution_context.static_context.read_only == read_only, 'wrong read_only');
}

#[test]
#[available_gas(100000)]
fn test_execution_context_stop_and_revert() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    execution_context.stop();

    // Then
    assert(execution_context.dynamic_context.is_stopped() == true, 'should be stopped');
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
    assert(
        execution_context.dynamic_context.get_return_data() == revert_reason, 'wrong revert reason'
    );
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
    // Given
    let mut execution_context = setup_execution_context();

    // When
    set_caller_address(test_utils::starknet_address());
    let is_eoa = execution_context.is_caller_eoa();

    // Then
    assert(is_eoa == true, 'should be an eoa');

    // When
    set_caller_address(test_utils::zero_address());
    let is_eoa = execution_context.is_caller_eoa();

    // Then
    assert(is_eoa == false, 'should not be an eoa');
}
