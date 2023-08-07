use kakarot::stack::{Stack, StackTrait};
use kakarot::memory::{Memory, MemoryTrait};
use kakarot::model::Event;
use debug::PrintTrait;
use array::ArrayTrait;
use starknet::{EthAddress, ContractAddress};
use box::BoxTrait;
use nullable::NullableTrait;
use traits::Destruct;

/// The call context.
#[derive(Destruct)]
struct CallContext {
    /// The bytecode to execute.
    bytecode: Span<u8>,
    /// The call data.
    call_data: Span<u8>,
    /// Amount of native token to transfer.
    value: u256,
}

// I think we should not directly access the fields of the call context;
// instead we should use the methods defined in the trait. 
// This is not enforced until there are `pub` and `priv` visibility on struct fields.
trait CallContextTrait {
    fn new(bytecode: Span<u8>, call_data: Span<u8>, value: u256) -> CallContext;
    fn bytecode(self: @CallContext) -> Span<u8>;
    fn call_data(self: @CallContext) -> Span<u8>;
    fn value(self: @CallContext) -> u256;
}

impl CallContextImpl of CallContextTrait {
    fn new(bytecode: Span<u8>, call_data: Span<u8>, value: u256) -> CallContext {
        CallContext { bytecode, call_data, value,  }
    }
    fn bytecode(self: @CallContext) -> Span<u8> {
        *self.bytecode
    }

    fn call_data(self: @CallContext) -> Span<u8> {
        *self.call_data
    }

    fn value(self: @CallContext) -> u256 {
        *self.value
    }
}


/// The execution context.
/// Stores all data relevant to the current execution context.
#[derive(Destruct)]
struct ExecutionContext {
    call_context: CallContext,
    program_counter: u32,
    stack: Stack,
    stopped: bool,
    return_data: Array<felt252>,
    memory: Memory,
    gas_used: u64,
    gas_limit: u64,
    gas_price: u64,
    starknet_address: ContractAddress,
    evm_address: EthAddress,
    calling_context: Nullable<ExecutionContext>,
    sub_context: Nullable<ExecutionContext>,
    destroy_contracts: Array<EthAddress>,
    events: Array<Event>,
    create_addresses: Array<EthAddress>,
    revert_contract_state: Felt252Dict<felt252>,
    reverted: bool,
    read_only: bool,
}


// TODO remove once merged in core library
impl NullableDestruct<T, impl TDestruct: Destruct<T>> of Destruct<Nullable<T>> {
    fn destruct(self: Nullable<T>) nopanic {}
}

// TODO remove once merged in core library
impl BoxDestruct<T, impl TDestruct: Destruct<T>> of Destruct<Box<T>> {
    fn destruct(self: Box<T>) nopanic {}
}

/// `ExecutionContext` implementation.
#[generate_trait]
impl ExecutionContextImpl of ExecutionContextTrait {
    /// Create a new execution context instance.
    #[inline(always)]
    fn new(
        call_context: CallContext,
        starknet_address: ContractAddress,
        evm_address: EthAddress,
        gas_limit: u64,
        gas_price: u64,
        calling_context: Nullable<ExecutionContext>,
        returned_data: Array<felt252>,
        read_only: bool
    ) -> ExecutionContext {
        let mut stack = StackTrait::new();
        ExecutionContext {
            call_context,
            program_counter: 0,
            stack: StackTrait::new(),
            stopped: false,
            return_data: ArrayTrait::new(),
            memory: MemoryTrait::new(),
            gas_used: 0,
            gas_limit,
            gas_price,
            starknet_address,
            evm_address,
            calling_context,
            sub_context: Default::default(),
            destroy_contracts: Default::default(),
            events: Default::default(),
            create_addresses: Default::default(),
            revert_contract_state: Default::default(),
            reverted: false,
            read_only,
        }
    }

    /// Compute the intrinsic gas cost for the current transaction and increase the gas used.
    /// TODO: Implement this. For now we just increase the gas used by a hard coded value.
    fn process_intrinsic_gas_cost(ref self: ExecutionContext) {
        self.gas_used = self.gas_used + 42;
    }

    /// Halts execution.
    /// TODO: implement this.
    fn stop(ref self: ExecutionContext) {}

    /// Debug print the execution context.
    fn print_debug(ref self: ExecutionContext) {
        debug::print_felt252('gas used');
        self.gas_used.print();
    }
}

/// The execution summary.
#[derive(Drop, Copy)]
struct ExecutionSummary {}

