use core::box::BoxTrait;
use core::nullable::{NullableTrait, null};
use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextType, ExecutionContextTrait,
    DefaultOptionSpanU8
};
use evm::memory::{Memory, MemoryTrait};
use evm::model::{Event, Address};
use evm::stack::{Stack, StackTrait};
use evm::tests::test_utils::MachineBuilderTrait;
use evm::tests::test_utils::{MachineBuilderImpl, CallContextPartialEq};
use evm::tests::test_utils;
use starknet::testing::{set_contract_address, set_caller_address};
use starknet::{EthAddress, ContractAddress};


use test_utils::{callvalue, test_address};
use traits::PartialEq;

#[test]
#[available_gas(1000000)]
fn test_call_context_new() {
    // When
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();
    let address = test_address();
    let gas_price = 0xabde1;
    let gas_limit = 0xe11a5;
    let read_only = false;
    let output_offset = 0;
    let output_size = 0;

    let call_ctx = CallContextTrait::new(
        address,
        bytecode,
        calldata,
        value,
        read_only,
        gas_limit,
        gas_price,
        output_offset,
        output_size
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
    let mut machine = MachineBuilderImpl::new_with_presets().build();
    // Given
    let call_ctx = machine.current_ctx.unbox().call_ctx();
    let context_id = ExecutionContextType::Root;
    let program_counter: u32 = 0;

    let stopped: bool = false;
    let return_data: Array<u8> = ArrayTrait::new();

    let address: Address = Default::default();
    let destroyed_contracts: Array<EthAddress> = Default::default();
    let events: Array<Event> = Default::default();
    let create_addresses: Array<EthAddress> = Default::default();
    let revert_contract_state: Felt252Dict<felt252> = Default::default();
    let reverted: bool = false;
    let read_only: bool = false;

    let parent_ctx: Nullable<ExecutionContext> = null();

    // When
    let mut execution_context = ExecutionContextTrait::new(
        context_id, address, call_ctx, parent_ctx, return_data.span()
    );

    // Then
    assert(execution_context.call_ctx() == call_ctx, 'wrong call_ctx');
    assert(execution_context.program_counter == program_counter, 'wrong program_counter');
    assert(execution_context.stopped() == stopped, 'wrong stopped');
    assert(execution_context.return_data() == Default::default().span(), 'wrong return_data');
    assert(execution_context.address() == address, 'wrong evm_address');
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
#[available_gas(1000000)]
fn test_execution_context_stop_and_revert() {
    // Given
    let mut machine = MachineBuilderImpl::new_with_presets().build();
    let mut execution_context = machine.current_ctx.unbox();

    // When
    execution_context.set_stopped();

    // Then
    assert(execution_context.stopped() == true, 'should be stopped');
}

#[test]
#[available_gas(1000000)]
fn test_execution_context_revert() {
    // Given
    let mut machine = MachineBuilderImpl::new_with_presets().build();
    let mut execution_context = machine.current_ctx.unbox();

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
    let mut machine = MachineBuilderImpl::new_with_presets()
        .with_bytecode(array![1, 2, 3].span())
        .build();

    // When
    let len = 2;
    let code = machine.current_ctx.unbox().read_code(len);

    // Then
    assert(code == array![1, 2].span(), 'wrong code read'); // Compare with expected slice
}


#[test]
#[available_gas(300000)]
fn test_is_root() {
    // Given
    let mut machine = MachineBuilderImpl::new_with_presets().build();
    let mut execution_context = machine.current_ctx.unbox();

    // When
    let is_root = execution_context.is_root();

    // Then
    assert(is_root, 'should not be a leaf');
}


#[test]
#[available_gas(3000000)]
fn test_origin() {
    // Given
    let mut machine = MachineBuilderImpl::new_with_presets()
        .with_nested_execution_context()
        .build();
    let mut context = machine.current_ctx.unbox();

    // When
    let origin = context.origin();
    // Then
    assert(origin == test_address(), 'wrong origin');
}
