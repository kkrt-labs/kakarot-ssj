use contracts::tests::test_utils::{deploy_contract_account};
use evm::context::DefaultBoxExecutionContext;
use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextType, ExecutionContextTrait,
    DefaultOptionSpanU8
};
use evm::errors::{EVMError};
use evm::machine::{Machine, MachineBuilder, MachineTrait};
use evm::model::{ContractAccountTrait, Address, Account, AccountType};
use evm::state::State;
use evm::{stack::{Stack, StackTrait}, memory::{Memory, MemoryTrait}};
use nullable::{match_nullable, FromNullableResult};
use starknet::{
    StorageBaseAddress, storage_base_address_from_felt252, contract_address_try_from_felt252,
    ContractAddress, EthAddress, deploy_syscall, get_contract_address, contract_address_const
};

#[generate_trait]
impl MachineBuilderTestImpl of MachineBuilderTestTrait {
    fn new() -> MachineBuilder {
        MachineBuilder { machine: Default::default() }
    }

    fn new_with_presets() -> MachineBuilder {
        let ctx = preset_execution_context();
        MachineBuilder {
            machine: Machine {
                current_ctx: BoxTrait::new(ctx),
                ctx_count: 1,
                state: Default::default(),
                stack: Default::default(),
                memory: Default::default(),
            }
        }
    }

    fn with_return_data(mut self: MachineBuilder, return_data: Span<u8>) -> MachineBuilder {
        let mut current_ctx = self.machine.current_ctx.unbox();
        current_ctx.return_data = return_data;
        self.machine.current_ctx = BoxTrait::new(current_ctx);
        self
    }

    fn with_caller(mut self: MachineBuilder, address: Address) -> MachineBuilder {
        let mut current_ctx = self.machine.current_ctx.unbox();
        let mut call_ctx = current_ctx.call_ctx();
        call_ctx.caller = address;
        current_ctx.call_ctx = BoxTrait::new(call_ctx);
        self.machine.current_ctx = BoxTrait::new(current_ctx);
        self
    }

    fn with_calldata(mut self: MachineBuilder, calldata: Span<u8>) -> MachineBuilder {
        let mut current_ctx = self.machine.current_ctx.unbox();
        let mut call_ctx = current_ctx.call_ctx();
        call_ctx.calldata = calldata;
        current_ctx.call_ctx = BoxTrait::new(call_ctx);
        self.machine.current_ctx = BoxTrait::new(current_ctx);
        self
    }

    fn with_read_only(mut self: MachineBuilder) -> MachineBuilder {
        let mut current_ctx = self.machine.current_ctx.unbox();
        let mut call_ctx = current_ctx.call_ctx();
        call_ctx.read_only = true;
        current_ctx.call_ctx = BoxTrait::new(call_ctx);
        self.machine.current_ctx = BoxTrait::new(current_ctx);
        self
    }

    fn with_bytecode(mut self: MachineBuilder, bytecode: Span<u8>) -> MachineBuilder {
        let mut current_ctx = self.machine.current_ctx.unbox();
        let mut call_ctx = current_ctx.call_ctx();
        call_ctx.bytecode = bytecode;
        current_ctx.call_ctx = BoxTrait::new(call_ctx);
        self.machine.current_ctx = BoxTrait::new(current_ctx);
        self
    }

    fn with_nested_execution_context(mut self: MachineBuilder) -> MachineBuilder {
        let current_ctx = self.machine.current_ctx.unbox();

        // Second Execution Context
        let context_id = ExecutionContextType::Call(1);
        let mut child_context = preset_execution_context();
        child_context.ctx_type = context_id;
        child_context.parent_ctx = NullableTrait::new(current_ctx);
        let mut call_ctx = child_context.call_ctx();
        call_ctx.caller = other_address();
        child_context.call_ctx = BoxTrait::new(call_ctx);
        self.machine.current_ctx = BoxTrait::new(child_context);
        self
    }

    fn with_target(mut self: MachineBuilder, target: Address) -> MachineBuilder {
        let mut current_ctx = self.machine.current_ctx.unbox();
        current_ctx.address = target;
        self.machine.current_ctx = BoxTrait::new(current_ctx);
        self
    }

    fn build(self: MachineBuilder) -> Machine {
        return self.machine;
    }
}

fn starknet_address() -> ContractAddress {
    contract_address_const::<'starknet_address'>()
}

fn evm_address() -> EthAddress {
    'evm_address'.try_into().unwrap()
}

fn test_address() -> Address {
    Address { evm: evm_address(), starknet: starknet_address() }
}

fn other_evm_address() -> EthAddress {
    'other_evm_address'.try_into().unwrap()
}

fn other_starknet_address() -> ContractAddress {
    contract_address_const::<'other_starknet_address'>()
}

fn other_address() -> Address {
    Address { evm: other_evm_address(), starknet: other_starknet_address() }
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

fn gas_limit() -> u128 {
    0x100000000000000000
}

fn gas_price() -> u128 {
    0xf00000000000000000
}

fn value() -> u256 {
    0xffffffffffffffffffffffffffffffff
}

fn ca_address() -> EthAddress {
    let evm_address: EthAddress = 0xca.try_into().unwrap();
    evm_address
}

fn setup_call_context() -> CallContext {
    let bytecode: Span<u8> = array![0x00].span();
    let calldata: Span<u8> = array![4, 5, 6].span();
    let value: u256 = callvalue();
    let caller = test_address();
    let read_only = false;
    let gas_price = gas_price();
    let gas_limit = gas_limit();
    let output_offset = 0;
    let output_size = 0;

    CallContextTrait::new(
        caller,
        bytecode,
        calldata,
        value,
        read_only,
        gas_limit,
        gas_price,
        output_offset,
        output_size,
    )
}

fn preset_execution_context() -> ExecutionContext {
    let context_id = ExecutionContextType::Root(false);
    let call_ctx = setup_call_context();
    let address = test_address();
    let return_data = array![1, 2, 3].span();

    ExecutionContextTrait::new(context_id, address, call_ctx, Default::default(), return_data,)
}

impl CallContextPartialEq of PartialEq<CallContext> {
    fn eq(lhs: @CallContext, rhs: @CallContext) -> bool {
        lhs.bytecode() == rhs.bytecode() && lhs.calldata == rhs.calldata && lhs.value == rhs.value
    }
    fn ne(lhs: @CallContext, rhs: @CallContext) -> bool {
        !(lhs == rhs)
    }
}

// Simulate return of subcontext where
/// 1. Set `return_data` field of parent context
/// 2. make `parent_ctx` of `current_ctx` the current ctx
fn return_from_subcontext(ref self: Machine, return_data: Span<u8>) {
    let current_ctx = self.current_ctx.unbox();
    let mut parent_ctx = current_ctx.parent_ctx.deref();
    parent_ctx.return_data = return_data;
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
) -> Result<Address, EVMError> {
    let mut ca_address = deploy_contract_account(eth_address, bytecode);
    // Set the storage of the contract account
    let account = Account {
        account_type: AccountType::ContractAccount,
        address: ca_address,
        code: array![0xab, 0xcd, 0xef].span(),
        nonce: 1,
        balance: 0,
        selfdestruct: false
    };
    let mut i = 0;
    loop {
        if i == storage.len() {
            break;
        };
        let (key, value) = storage.get(i).unwrap().unbox();
        account.store_storage(*key, *value).expect('failed init CA');
        i += 1;
    };

    Result::Ok(ca_address)
}
