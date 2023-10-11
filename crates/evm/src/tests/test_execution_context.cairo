use core::nullable::{NullableTrait, null};
use debug::PrintTrait;
use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait, DefaultOptionSpanU8
};
use evm::memory::{Memory, MemoryTrait};
use evm::model::Event;
use evm::stack::{Stack, StackTrait};
use evm::tests::test_utils::{
    setup_call_context, setup_execution_context, setup_nested_execution_context,
    CallContextPartialEq
};
use evm::tests::test_utils;
use starknet::testing::{set_contract_address, set_caller_address};
use starknet::{EthAddress, ContractAddress};


use test_utils::{callvalue, evm_address};
use traits::PartialEq;

// TODO remove once no longer required (see https://github.com/starkware-libs/cairo/issues/3863)
#[inline(never)]
fn no_op() {}


#[test]
#[available_gas(1000000)]
fn test_call_context_new() {
    // When
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();
    let address = evm_address();
    let gas_price = 0xabde1;
    let gas_limit = 0xe11a5;
    let read_only = false;

    let call_ctx = CallContextTrait::new(
        address, bytecode, calldata, value, read_only, gas_limit, gas_price
    );

    // Then
    assert(call_ctx.bytecode() == bytecode, 'wrong bytecode');
    assert(call_ctx.calldata() == calldata, 'wrong calldata');
    assert(call_ctx.value() == callvalue(), 'wrong value');
    assert(call_ctx.gas_limit() == gas_limit, 'wrong gas_limit');
    assert(call_ctx.gas_price() == gas_price, 'wrong gas_price');
    assert(call_ctx.read_only() == read_only, 'wrong read_only');
}

#[test]
#[available_gas(500000)]
fn test_execution_context_new() {
    // Given
    let call_ctx = setup_call_context();
    let context_id = 0;
    let program_counter: u32 = 0;

    let stopped: bool = false;
    let return_data: Array<u8> = ArrayTrait::new();

    let starknet_address: ContractAddress = 0.try_into().unwrap();
    let evm_address: EthAddress = 0.try_into().unwrap();
    let destroyed_contracts: Array<EthAddress> = Default::default();
    let events: Array<Event> = Default::default();
    let create_addresses: Array<EthAddress> = Default::default();
    let revert_contract_state: Felt252Dict<felt252> = Default::default();
    let reverted: bool = false;
    let read_only: bool = false;

    let parent_ctx: Nullable<ExecutionContext> = null();

    // When
    let mut execution_context = ExecutionContextTrait::new(
        context_id, evm_address, starknet_address, call_ctx, parent_ctx, return_data.span()
    );

    // Then
    let call_ctx = setup_call_context();
    assert(execution_context.call_ctx() == call_ctx, 'wrong call_ctx');
    assert(execution_context.program_counter == program_counter, 'wrong program_counter');
    assert(execution_context.stopped() == stopped, 'wrong stopped');
    assert(execution_context.return_data() == Default::default().span(), 'wrong return_data');
    assert(execution_context.starknet_address() == starknet_address, 'wrong starknet_address');
    assert(execution_context.evm_address() == evm_address, 'wrong evm_address');
    assert(
        execution_context.destroyed_contracts() == destroyed_contracts.span(),
        'wrong destroyed_contracts'
    );
    assert(execution_context.events().len() == events.len(), 'wrong events');
    assert(
        execution_context.create_addresses() == create_addresses.span(), 'wrong create_addresses'
    );
    assert(execution_context.reverted() == reverted, 'wrong reverted');
}

#[test]
#[available_gas(100000)]
fn test_execution_context_stop_and_revert() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    execution_context.set_stopped();

    // Then
    assert(execution_context.stopped() == true, 'should be stopped');
}

#[test]
#[available_gas(1000000)]
fn test_execution_context_revert() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    let revert_reason = array![0, 1, 2, 3].span();
    execution_context.set_reverted();

    // Then
    assert(execution_context.reverted() == true, 'should be reverted');
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
}


#[test]
#[available_gas(300000)]
fn test_is_root() {
    // Given
    let mut execution_context = setup_execution_context();

    // When
    let is_root = execution_context.is_root();

    // Then
    assert(is_root, 'should not be a leaf');
}


#[test]
#[available_gas(300000)]
fn test_origin() {
    // Given
    let mut execution_context = setup_nested_execution_context();

    // When
    let origin = execution_context.origin();

    // Then
    assert(origin == evm_address(), 'wrong origin');
}
