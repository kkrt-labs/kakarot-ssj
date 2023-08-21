use kakarot::stack::{Stack, StackTrait};
use kakarot::memory::{Memory, MemoryTrait};
use kakarot::model::Event;
use debug::PrintTrait;
use array::{ArrayTrait, SpanTrait};
use kakarot::utils::helpers::{ArrayExtension, ArrayExtensionTrait};
use starknet::{EthAddress, ContractAddress};
use box::BoxTrait;
use nullable::NullableTrait;
use traits::{Into, TryInto, Destruct};
use option::OptionTrait;
use starknet::get_caller_address;

/// The call context.
#[derive(Drop, Copy)]
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
    #[inline(always)]
    fn new(bytecode: Span<u8>, call_data: Span<u8>, value: u256) -> CallContext {
        CallContext { bytecode, call_data, value, }
    }

    #[inline(always)]
    fn bytecode(self: @CallContext) -> Span<u8> {
        *self.bytecode
    }

    #[inline(always)]
    fn call_data(self: @CallContext) -> Span<u8> {
        *self.call_data
    }

    #[inline(always)]
    fn value(self: @CallContext) -> u256 {
        *self.value
    }
}

impl DefaultCallContextImpl of Default<CallContext> {
    fn default() -> CallContext {
        CallContext {
            bytecode: Default::default().span(),
            call_data: Default::default().span(),
            value: Default::default(),
        }
    }
}


#[derive(Drop, Copy)]
struct StaticExecutionContext {
    call_context: CallContext,
    starknet_address: ContractAddress,
    evm_address: EthAddress,
    read_only: bool,
}

impl DefaultStaticExecutionContext of Default<StaticExecutionContext> {
    fn default() -> StaticExecutionContext {
        StaticExecutionContext {
            call_context: Default::default(),
            starknet_address: Default::default(),
            evm_address: Default::default(),
            read_only: false,
        }
    }
}

#[generate_trait]
impl StaticExecutionContextImpl of StaticExecutionContextTrait {
    fn new(
        call_context: CallContext,
        starknet_address: ContractAddress,
        evm_address: EthAddress,
        read_only: bool
    ) -> StaticExecutionContext {
        StaticExecutionContext { call_context, starknet_address, evm_address, read_only, }
    }
}

#[derive(Destruct)]
struct DynamicExecutionContext {
    destroyed_contracts: Array<EthAddress>,
    events: Array<Event>,
    create_addresses: Array<EthAddress>,
    revert_contract_state: Felt252Dict<felt252>,
    return_data: Array<u8>,
    reverted: bool,
    stopped: bool,
}

#[generate_trait]
impl DynamicExecutionContextImpl of DynamicExecutionContextTrait {
    #[inline(always)]
    fn new(return_data: Array<u8>) -> DynamicExecutionContext {
        DynamicExecutionContext {
            destroyed_contracts: Default::default(),
            events: Default::default(),
            create_addresses: Default::default(),
            revert_contract_state: Default::default(),
            return_data,
            reverted: false,
            stopped: false
        }
    }
}

impl DefaultDynamicExecutionContext of Default<DynamicExecutionContext> {
    fn default() -> DynamicExecutionContext {
        DynamicExecutionContext {
            destroyed_contracts: Default::default(),
            events: Default::default(),
            create_addresses: Default::default(),
            revert_contract_state: Default::default(),
            return_data: Default::default(),
            reverted: false,
            stopped: false,
        }
    }
}


/// The execution context.
/// Stores all data relevant to the current execution context.
#[derive(Destruct)]
struct ExecutionContext {
    static_context: StaticExecutionContext,
    dynamic_context: DynamicExecutionContext,
    program_counter: u32,
    stack: Stack,
    memory: Memory,
// TODO: refactor using smart pointers
// once compiler supports it
//calling_context: Nullable<ExecutionContext>,
//sub_context: Nullable<ExecutionContext>,
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
        // calling_context: Nullable<ExecutionContext>,
        returned_data: Array<u8>,
        read_only: bool
    ) -> ExecutionContext {
        ExecutionContext {
            static_context: StaticExecutionContextTrait::new(
                call_context, starknet_address, evm_address, read_only
            ),
            dynamic_context: DynamicExecutionContextTrait::new(returned_data),
            program_counter: 0,
            stack: Default::default(),
            memory: Default::default(),
        // calling_context,
        // sub_context: Default::default(),
        }
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn stop(ref self: ExecutionContext) {
        self.dynamic_context.stopped = true;
    }

    /// Revert the current execution context.
    /// 
    /// When the execution context is reverted, no more instructions can be executed 
    /// (it is stopped) and contract creation and contract storage writes are 
    /// reverted on its finalization.
    #[inline(always)]
    fn revert(ref self: ExecutionContext, revert_reason: Span<u8>) {
        self.dynamic_context.reverted = true;
        ArrayExtensionTrait::concat(ref self.dynamic_context.return_data, revert_reason);
    }

    /// Reads and return data from bytecode.
    /// The program counter is incremented accordingly.
    /// 
    /// # Arguments
    /// 
    /// * `self` - The `ExecutionContext` instance to read the data from.
    /// * `len` - The length of the data to read from the bytecode.
    #[inline(always)]
    fn read_code(ref self: ExecutionContext, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let code = self.static_context.call_context.bytecode().slice(self.program_counter, len);

        self.program_counter += len;
        code
    }


    #[inline(always)]
    fn is_root(self: @ExecutionContext) { //TODO: implement this (returns a bool)
    // self.calling_context.is_null()
    // true
    }
    #[inline(always)]
    fn is_leaf(self: @ExecutionContext) { //TODO implement this(returns a bool)
    // self.sub_context.is_null()
    }

    #[inline(always)]
    fn reverted(self: @ExecutionContext) -> bool {
        *self.dynamic_context.reverted
    }

    #[inline(always)]
    fn stopped(self: @ExecutionContext) -> bool {
        *self.dynamic_context.stopped
    }

    #[inline(always)]
    fn call_context(self: @ExecutionContext) -> CallContext {
        *self.static_context.call_context
    }

    #[inline(always)]
    fn destroyed_contracts(self: @ExecutionContext) -> Span<EthAddress> {
        self.dynamic_context.destroyed_contracts.span()
    }

    #[inline(always)]
    fn events(self: @ExecutionContext) -> Span<Event> {
        self.dynamic_context.events.span()
    }

    #[inline(always)]
    fn create_addresses(self: @ExecutionContext) -> Span<EthAddress> {
        self.dynamic_context.create_addresses.span()
    }

    #[inline(always)]
    fn return_data(self: @ExecutionContext) -> Span<u8> {
        self.dynamic_context.return_data.span()
    }

    #[inline(always)]
    fn starknet_address(self: @ExecutionContext) -> ContractAddress {
        *self.static_context.starknet_address
    }

    #[inline(always)]
    fn evm_address(self: @ExecutionContext) -> EthAddress {
        *self.static_context.evm_address
    }

    #[inline(always)]
    fn read_only(self: @ExecutionContext) -> bool {
        *self.static_context.read_only
    }

    /// Returns if starknet contract address is an EOA
    #[inline(always)]
    fn is_caller_eoa(self: @ExecutionContext) -> bool {
        if get_caller_address() == self.starknet_address() {
            return true;
        };
        false
    }

    // TODO: Implement print_debug
    /// Debug print the execution context.
    #[inline(always)]
    fn print_debug(ref self: ExecutionContext) {
        // debug::print_felt252('gas used');
        // self.gas_used.print();
        'print debug'.print();
    }
}

impl DefaultExecutionContext of Default<ExecutionContext> {
    fn default() -> ExecutionContext {
        ExecutionContext {
            static_context: Default::default(),
            dynamic_context: Default::default(),
            program_counter: 0,
            stack: Default::default(),
            memory: Default::default(),
        // calling_context: Default::default(),
        // sub_context: Default::default(),

        }
    }
}

impl DefaultEthAddress of Default<EthAddress> {
    fn default() -> EthAddress {
        0.try_into().unwrap()
    }
}

impl DefaultContractAddress of Default<ContractAddress> {
    fn default() -> ContractAddress {
        0.try_into().unwrap()
    }
}

/// The execution summary.
#[derive(Drop, Copy)]
struct ExecutionSummary {}
