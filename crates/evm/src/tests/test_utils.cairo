use starknet::{contract_address_try_from_felt252, ContractAddress, EthAddress};
use traits::{Into, TryInto};
use option::OptionTrait;
use array::{ArrayTrait, SpanTrait};
use evm::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait,};

fn starknet_address() -> ContractAddress {
    'starknet_address'.try_into().unwrap()
}

fn evm_address() -> EthAddress {
    'evm_address'.try_into().unwrap()
}

fn zero_address() -> ContractAddress {
    0.try_into().unwrap()
}

fn callvalue() -> u256 {
    123456789
}

fn setup_call_context() -> CallContext {
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();

    CallContextTrait::new(bytecode, calldata, value)
}

fn setup_execution_context() -> ExecutionContext {
    let call_context = setup_call_context();
    let starknet_address: ContractAddress = starknet_address();
    let evm_address: EthAddress = evm_address();
    let gas_limit: u64 = 1000;
    let gas_price: u64 = 10;
    let read_only: bool = false;
    let return_data = Default::default();

    ExecutionContextTrait::new(
        call_context, starknet_address, evm_address, gas_limit, gas_price, return_data, read_only
    )
}

fn setup_call_context_with_bytecode(bytecode: Span<u8>) -> CallContext {
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = 100;

    CallContextTrait::new(bytecode, calldata, value)
}

fn setup_execution_context_with_bytecode(bytecode: Span<u8>) -> ExecutionContext {
    let call_context = setup_call_context_with_bytecode(bytecode);
    let starknet_address: ContractAddress = starknet_address();
    let evm_address: EthAddress = evm_address();
    let gas_limit: u64 = 1000;
    let gas_price: u64 = 10;
    let read_only: bool = false;
    let return_data = Default::default();

    ExecutionContextTrait::new(
        call_context, starknet_address, evm_address, gas_limit, gas_price, return_data, read_only
    )
}

impl CallContextPartialEq of PartialEq<CallContext> {
    fn eq(lhs: @CallContext, rhs: @CallContext) -> bool {
        lhs.bytecode() == rhs.bytecode() && lhs.calldata == rhs.calldata && lhs.value == rhs.value
    }
    fn ne(lhs: @CallContext, rhs: @CallContext) -> bool {
        !(lhs == rhs)
    }
}
