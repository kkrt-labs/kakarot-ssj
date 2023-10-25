use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextType, ExecutionContextTrait,
    DefaultOptionSpanU8
};
use evm::errors::{EVMError};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::model::{ContractAccountTrait};
use nullable::{match_nullable, FromNullableResult};
use starknet::{
    StorageBaseAddress, storage_base_address_from_felt252, contract_address_try_from_felt252,
    ContractAddress, EthAddress, deploy_syscall, get_contract_address, contract_address_const
};

fn starknet_address() -> ContractAddress {
    contract_address_const::<'starknet_address'>()
}

fn evm_address() -> EthAddress {
    'evm_address'.try_into().unwrap()
}

fn other_evm_address() -> EthAddress {
    0xabde1.try_into().unwrap()
}

fn other_starknet_address() -> ContractAddress {
    contract_address_const::<'other_starknet_address'>()
}

fn storage_base_address() -> StorageBaseAddress {
    storage_base_address_from_felt252('storage_base_address')
}

fn zero_address() -> ContractAddress {
    contract_address_const::<0x00>()
}

fn callvalue() -> u256 {
    123456789
}


fn deploy_fee() -> u128 {
    0x10
}

fn native_token() -> ContractAddress {
    contract_address_const::<'native_token'>()
}

fn chain_id() -> u128 {
    'CHAIN_ID'.try_into().unwrap()
}

fn kakarot_address() -> ContractAddress {
    contract_address_const::<'kakarot'>()
}

fn eoa_address() -> EthAddress {
    let evm_address: EthAddress = 0xe0a.try_into().unwrap();
    evm_address
}

fn setup_call_context() -> CallContext {
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();
    let address = evm_address();
    let read_only = false;
    let gas_price = 0xaaaaaa;
    let gas_limit = 0xffffff;
    let output_offset = 0;
    let output_size = 0;

    CallContextTrait::new(
        address,
        bytecode,
        calldata,
        value,
        read_only,
        gas_limit,
        gas_price,
        output_offset,
        output_size
    )
}

fn setup_execution_context() -> ExecutionContext {
    let context_id = ExecutionContextType::Root;
    let call_ctx = setup_call_context();
    let evm_address: EthAddress = evm_address();
    let return_data = array![1, 2, 3].span();

    ExecutionContextTrait::new(context_id, evm_address, call_ctx, Default::default(), return_data,)
}

fn setup_nested_execution_context() -> ExecutionContext {
    let mut parent_context = setup_execution_context();

    // Second Execution Context
    let context_id = ExecutionContextType::Call(1);
    let mut child_context = setup_execution_context();
    child_context.ctx_type = context_id;
    child_context.parent_ctx = NullableTrait::new(parent_context);
    let mut call_ctx = child_context.call_ctx.unbox();
    call_ctx.caller = other_evm_address();
    child_context.call_ctx = BoxTrait::new(call_ctx);

    return child_context;
}

fn setup_call_context_with_bytecode(bytecode: Span<u8>) -> CallContext {
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();
    let address = evm_address();
    let read_only = false;
    let gas_price = 0xaaaaaa;
    let gas_limit = 0xffffff;
    let output_offset = 0;
    let output_size = 0;

    CallContextTrait::new(
        address,
        bytecode,
        calldata,
        value,
        read_only,
        gas_limit,
        gas_price,
        output_offset,
        output_size
    )
}

fn setup_execution_context_with_bytecode(bytecode: Span<u8>) -> ExecutionContext {
    let context_id = ExecutionContextType::Root;
    let call_ctx = setup_call_context_with_bytecode(bytecode);
    let evm_address: EthAddress = evm_address();
    let return_data = Default::default().span();

    ExecutionContextTrait::new(context_id, evm_address, call_ctx, Default::default(), return_data,)
}


fn setup_call_context_with_calldata(calldata: Span<u8>) -> CallContext {
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let value: u256 = callvalue();
    let address = evm_address();
    let read_only = false;
    let gas_price = 0xffffff;
    let gas_limit = 0xffffff;
    let output_offset = 0;
    let output_size = 0;

    CallContextTrait::new(
        address,
        bytecode,
        calldata,
        value,
        read_only,
        gas_price,
        gas_limit,
        output_offset,
        output_size
    )
}

fn setup_execution_context_with_calldata(calldata: Span<u8>) -> ExecutionContext {
    let context_id = ExecutionContextType::Root;
    let call_ctx = setup_call_context_with_calldata(calldata);
    let evm_address: EthAddress = evm_address();
    let return_data = Default::default().span();

    ExecutionContextTrait::new(context_id, evm_address, call_ctx, Default::default(), return_data,)
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
        current_ctx: BoxTrait::new(setup_execution_context()),
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
        error: Option::None
    }
}

fn setup_machine_with_bytecode(bytecode: Span<u8>) -> Machine {
    let current_ctx = BoxTrait::new(setup_execution_context_with_bytecode(bytecode));
    Machine {
        current_ctx,
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
        error: Option::None
    }
}

fn setup_machine_with_calldata(calldata: Span<u8>) -> Machine {
    let current_ctx = BoxTrait::new(setup_execution_context_with_calldata(calldata));
    Machine {
        current_ctx,
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
        error: Option::None
    }
}

fn setup_machine_with_read_only() -> Machine {
    let mut machine = setup_machine();
    let mut current_ctx = machine.current_ctx.unbox();
    let mut current_call_ctx = current_ctx.call_ctx.unbox();
    current_call_ctx.read_only = true;
    current_ctx.call_ctx = BoxTrait::new(current_call_ctx);
    machine.current_ctx = BoxTrait::new(current_ctx);
    machine
}

fn setup_machine_with_nested_execution_context() -> Machine {
    let current_ctx = BoxTrait::new(setup_nested_execution_context());
    Machine {
        current_ctx,
        ctx_count: 1,
        stack: Default::default(),
        memory: Default::default(),
        storage_journal: Default::default(),
        error: Option::None
    }
}

// Simulate return of subcontext where
/// 1. Set `return_data` field of parent context
/// 2. make `parent_ctx` of `current_ctx` the current ctx
fn return_from_subcontext(ref self: Machine, return_data: Span<u8>) {
    self.set_return_data(return_data);
    let current_ctx = self.current_ctx.unbox();
    let parent_ctx = current_ctx.parent_ctx.deref();
    self.current_ctx = BoxTrait::new(parent_ctx);
}

/// Returns the `return_data` field of the parent_ctx of the current_ctx.
fn parent_ctx_return_data(ref self: Machine) -> Span<u8> {
    let mut current_ctx = self.current_ctx.unbox();
    let maybe_parent_ctx = current_ctx.parent_ctx;
    let value = match match_nullable(maybe_parent_ctx) {
        // Due to ownership mechanism, both branches need to explicitly re-bind the parent_ctx.
        FromNullableResult::Null => {
            current_ctx.parent_ctx = Default::default();
            Default::default().span()
        },
        FromNullableResult::NotNull(parent_ctx) => {
            let mut parent_ctx = parent_ctx.unbox();
            let value = parent_ctx.return_data();
            current_ctx.parent_ctx = NullableTrait::new(parent_ctx);
            value
        }
    };
    self.current_ctx = BoxTrait::new(current_ctx);
    value
}

/// Initializes the contract account by setting the bytecode, the storage
/// and incrementing the nonce to 1.
fn initialize_contract_account(
    eth_address: EthAddress, bytecode: Span<u8>, storage: Span<(u256, u256)>
) -> Result<(), EVMError> {
    let mut ca = ContractAccountTrait::deploy(eth_address, bytecode).expect('failed deploying CA');
    // Set the storage of the contract account
    let mut i = 0;
    loop {
        if i == storage.len() {
            break;
        };
        let (key, value) = storage.get(i).unwrap().unbox();
        ca.set_storage_at(*key, *value);
        i += 1;
    };

    Result::Ok(())
}
