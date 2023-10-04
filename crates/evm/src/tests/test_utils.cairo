use evm::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait,};

use evm::machine::Machine;
use starknet::{contract_address_try_from_felt252, ContractAddress, EthAddress};

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
    let address = evm_address();
    let read_only = false;
    let gas_price = 0xaaaaaa;
    let gas_limit = 0xffffff;

    CallContextTrait::new(address, bytecode, calldata, value, read_only, gas_limit, gas_price)
}

fn setup_execution_context() -> ExecutionContext {
    let context_id = 0;
    let call_context = setup_call_context();
    let starknet_address: ContractAddress = starknet_address();
    let evm_address: EthAddress = evm_address();
    let return_data = Default::default();

    ExecutionContextTrait::new(
        context_id,
        evm_address,
        starknet_address,
        call_context,
        Default::default(),
        Default::default(),
        return_data,
    )
}

fn setup_call_context_with_bytecode(bytecode: Span<u8>) -> CallContext {
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();
    let address = evm_address();
    let read_only = false;
    let gas_price = 0xaaaaaa;
    let gas_limit = 0xffffff;

    CallContextTrait::new(address, bytecode, calldata, value, read_only, gas_limit, gas_price)
}

fn setup_execution_context_with_bytecode(bytecode: Span<u8>) -> ExecutionContext {
    let context_id = 0;
    let call_context = setup_call_context_with_bytecode(bytecode);
    let starknet_address: ContractAddress = starknet_address();
    let evm_address: EthAddress = evm_address();
    let return_data = Default::default();

    ExecutionContextTrait::new(
        context_id,
        evm_address,
        starknet_address,
        call_context,
        Default::default(),
        Default::default(),
        return_data,
    )
}


fn setup_call_context_with_calldata(calldata: Span<u8>) -> CallContext {
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let value: u256 = callvalue();
    let address = evm_address();
    let read_only = false;
    let gas_price = 0xffffff;
    let gas_limit = 0xffffff;

    CallContextTrait::new(address, bytecode, calldata, value, read_only, gas_price, gas_limit)
}

fn setup_execution_context_with_calldata(calldata: Span<u8>) -> ExecutionContext {
    let context_id = 0;
    let call_context = setup_call_context_with_calldata(calldata);
    let starknet_address: ContractAddress = starknet_address();
    let evm_address: EthAddress = evm_address();
    let return_data = Default::default();

    ExecutionContextTrait::new(
        context_id,
        evm_address,
        starknet_address,
        call_context,
        Default::default(),
        Default::default(),
        return_data,
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

fn setup_machine() -> Machine {
    Machine {
        current_context: BoxTrait::new(setup_execution_context()),
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
    }
}

fn setup_machine_with_bytecode(bytecode: Span<u8>) -> Machine {
    let current_context = BoxTrait::new(setup_execution_context_with_bytecode(bytecode));
    Machine {
        current_context,
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
    }
}

fn setup_machine_with_calldata(calldata: Span<u8>) -> Machine {
    let current_context = BoxTrait::new(setup_execution_context_with_calldata(calldata));
    Machine {
        current_context,
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
    }
}

fn setup_machine_with_read_only() -> Machine {
    let mut machine = setup_machine();
    let mut current_ctx = machine.current_context.unbox();
    let mut current_call_ctx = current_ctx.call_context.unbox();
    current_call_ctx.read_only = true;
    current_ctx.call_context = BoxTrait::new(current_call_ctx);
    machine.current_context = BoxTrait::new(current_ctx);
    machine
}
