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
#[derive(Destruct, Copy)]
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

impl DefaultCallContextImpl of Default<CallContext> {
    fn default() -> CallContext {
        CallContext {
            bytecode: Default::default().span(),
            call_data: Default::default().span(),
            value: Default::default(),
        }
    }
}


#[derive(Destruct, Copy)]
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
            starknet_address: 0.try_into().unwrap(),
            evm_address: 0.try_into().unwrap(),
            read_only: false,
        }
    }
}

#[generate_trait]
impl StaticExecutionContextImpl of StaticExecutionContextTrait {
    #[inline(always)]
    fn get_call_context(self: @StaticExecutionContext) -> CallContext {
        *self.call_context
    }

    #[inline(always)]
    fn get_starknet_address(self: @StaticExecutionContext) -> ContractAddress {
        *self.starknet_address
    }

    #[inline(always)]
    fn get_evm_address(self: @StaticExecutionContext) -> EthAddress {
        *self.evm_address
    }

    #[inline(always)]
    fn is_read_only(self: @StaticExecutionContext) -> bool {
        *self.read_only
    }
}

#[derive(Destruct)]
struct DynamicExecutionContext {
    destroy_contracts: Array<EthAddress>,
    events: Array<Event>,
    create_addresses: Array<EthAddress>,
    revert_contract_state: Felt252Dict<felt252>,
    return_data: Array<u8>,
    reverted: bool,
    stopped: bool,
}

#[generate_trait]
impl DynamicExecutionContextImpl of DynamicExecutionContextTrait {
    fn new(return_data: Array<u8>) -> DynamicExecutionContext {
        DynamicExecutionContext {
            destroy_contracts: Default::default(),
            events: Default::default(),
            create_addresses: Default::default(),
            revert_contract_state: Default::default(),
            return_data,
            reverted: false,
            stopped: false
        }
    }

    #[inline(always)]
    fn get_destroy_contracts(self: @DynamicExecutionContext) -> Span<EthAddress> {
        self.destroy_contracts.span()
    }

    #[inline(always)]
    fn get_events(self: @DynamicExecutionContext) -> Span<Event> {
        self.events.span()
    }

    #[inline(always)]
    fn get_create_addresses(self: @DynamicExecutionContext) -> Span<EthAddress> {
        self.create_addresses.span()
    }

    //TODO: Check if this will make make self Out of Context
    #[inline(always)]
    fn get_revert_contract_state(self: @DynamicExecutionContext) -> @Felt252Dict<felt252> {
        self.revert_contract_state
    }

    #[inline(always)]
    fn get_return_data(self: @DynamicExecutionContext) -> Span<u8> {
        self.return_data.span()
    }

    #[inline(always)]
    fn is_reverted(self: @DynamicExecutionContext) -> bool {
        *self.reverted
    }

    #[inline(always)]
    fn is_stopped(self: @DynamicExecutionContext) -> bool {
        *self.stopped
    }
}

impl DefaultDynamicExecutionContext of Default<DynamicExecutionContext> {
    fn default() -> DynamicExecutionContext {
        DynamicExecutionContext {
            destroy_contracts: Default::default(),
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
            static_context: Default::default(),
            dynamic_context: Default::default(),
            program_counter: 0,
            stack: Default::default(),
            memory: Default::default(),
        // calling_context,
        // sub_context: Default::default(),
        }
    }

    //TODO: Check if this should be here or within dynamic_context
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

        // Update program counter
        self.program_counter += len;
        code
    }


    #[inline(always)]
    fn is_root(self: @ExecutionContext) { //TODO: implement this (returns a bool)
    // self.calling_context.is_null()
    // true
    }

    fn is_leaf(self: @ExecutionContext) { //TODO implement this(returns a bool)
    // self.sub_context.is_null()
    }

    fn is_reverted(self: @ExecutionContext) -> bool {
        *self.dynamic_context.reverted
    }

    fn is_stopped(self: @ExecutionContext) -> bool {
        *self.dynamic_context.stopped
    }
    
    /// Returns if starknet contract address is an EOA
    fn is_caller_eoa(self: @ExecutionContext) -> bool {
        if get_caller_address() == *self.static_context.starknet_address {
            return true;
        };
        false
    }


    /// Debug print the execution context.
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

/// The execution summary.
#[derive(Drop, Copy)]
struct ExecutionSummary {}
