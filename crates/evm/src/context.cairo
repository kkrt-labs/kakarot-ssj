use evm::stack::{Stack, StackTrait};
use evm::memory::{Memory, MemoryTrait};
use evm::model::Event;
use debug::PrintTrait;
use array::{ArrayTrait, SpanTrait};
use utils::helpers::{ArrayExtension, ArrayExtensionTrait};
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


// *************************************************************************
//                              CallContext
// *************************************************************************

// We should not directly access the fields of the call context;
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
    #[inline(always)]
    fn default() -> CallContext {
        CallContext {
            bytecode: Default::default().span(),
            call_data: Default::default().span(),
            value: Default::default(),
        }
    }
}

// *************************************************************************
//                              StaticExecutionContext
// *************************************************************************

#[derive(Drop, Copy)]
struct StaticExecutionContext {
    call_context: CallContext,
    starknet_address: ContractAddress,
    evm_address: EthAddress,
    read_only: bool,
    gas_limit: u64,
}

impl DefaultStaticExecutionContext of Default<StaticExecutionContext> {
    #[inline(always)]
    fn default() -> StaticExecutionContext {
        StaticExecutionContext {
            call_context: Default::default(),
            starknet_address: Default::default(),
            evm_address: Default::default(),
            read_only: false,
            gas_limit: 0,
        }
    }
}

#[generate_trait]
impl StaticExecutionContextImpl of StaticExecutionContextTrait {
    #[inline(always)]
    fn new(
        call_context: CallContext,
        starknet_address: ContractAddress,
        evm_address: EthAddress,
        read_only: bool,
        gas_limit: u64
    ) -> StaticExecutionContext {
        StaticExecutionContext { call_context, starknet_address, evm_address, read_only, gas_limit }
    }
}

// *************************************************************************
//                              DynamicExecutionContext
// *************************************************************************

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
    #[inline(always)]
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

// *************************************************************************
//                              ExecutionContext
// *************************************************************************

/// The execution context.
/// Stores all data relevant to the current execution context.
#[derive(Destruct)]
struct ExecutionContext {
    static_context: Box<StaticExecutionContext>,
    dynamic_context: Box<DynamicExecutionContext>,
    program_counter: u32,
    stack: Stack,
    memory: Memory,
// TODO: refactor using smart pointers
// once compiler supports it
//calling_context: Nullable<ExecutionContext>,
//sub_context: Nullable<ExecutionContext>,
}

impl BoxDynamicExecutionContextDestruct of Destruct<Box<DynamicExecutionContext>> {
    fn destruct(self: Box<DynamicExecutionContext>) nopanic {
        self.unbox().destruct();
    }
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
            static_context: BoxTrait::new(
                StaticExecutionContextTrait::new(
                    call_context, starknet_address, evm_address, read_only, gas_limit
                )
            ),
            dynamic_context: BoxTrait::new(DynamicExecutionContextTrait::new(returned_data)),
            program_counter: 0,
            stack: Default::default(),
            memory: Default::default(),
        // calling_context,
        // sub_context: Default::default(),
        }
    }

    // *************************************************************************
    //                      DynamicExecutionContext getters
    // *************************************************************************

    #[inline(always)]
    fn reverted(ref self: ExecutionContext) -> bool {
        let dyn_ctx = self.dynamic_context.unbox();
        let reverted = dyn_ctx.reverted;
        self.dynamic_context = BoxTrait::new(dyn_ctx);
        reverted
    }

    #[inline(always)]
    fn stopped(ref self: ExecutionContext) -> bool {
        let dyn_ctx = self.dynamic_context.unbox();
        let stopped = dyn_ctx.stopped;
        self.dynamic_context = BoxTrait::new(dyn_ctx);
        stopped
    }

    #[inline(always)]
    fn call_context(self: @ExecutionContext) -> CallContext {
        (*self.static_context).unbox().call_context
    }

    #[inline(always)]
    fn destroyed_contracts(ref self: ExecutionContext) -> Span<EthAddress> {
        let dyn_ctx = self.dynamic_context.unbox();
        let destroyed_contracts = dyn_ctx.destroyed_contracts.span();
        self.dynamic_context = BoxTrait::new(dyn_ctx);
        destroyed_contracts
    }

    #[inline(always)]
    fn events(ref self: ExecutionContext) -> Span<Event> {
        let dyn_ctx = self.dynamic_context.unbox();
        let events = dyn_ctx.events.span();
        self.dynamic_context = BoxTrait::new(dyn_ctx);
        events
    }

    #[inline(always)]
    fn create_addresses(ref self: ExecutionContext) -> Span<EthAddress> {
        let dyn_ctx = self.dynamic_context.unbox();
        let create_addresses = dyn_ctx.create_addresses.span();
        self.dynamic_context = BoxTrait::new(dyn_ctx);
        create_addresses
    }

    #[inline(always)]
    fn return_data(ref self: ExecutionContext) -> Span<u8> {
        let dyn_ctx = self.dynamic_context.unbox();
        let return_data = dyn_ctx.return_data.span();
        self.dynamic_context = BoxTrait::new(dyn_ctx);
        return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn stop(ref self: ExecutionContext) {
        let mut dyn_ctx = self.dynamic_context.unbox();
        dyn_ctx.stopped = true;
        self.dynamic_context = BoxTrait::new(dyn_ctx)
    }

    /// Revert the current execution context.
    /// 
    /// When the execution context is reverted, no more instructions can be executed 
    /// (it is stopped) and contract creation and contract storage writes are 
    /// reverted on its finalization.
    #[inline(always)]
    fn revert(ref self: ExecutionContext, revert_reason: Span<u8>) {
        let mut dyn_ctx = self.dynamic_context.unbox();
        dyn_ctx.reverted = true;
        ArrayExtensionTrait::concat(ref dyn_ctx.return_data, revert_reason);
        self.dynamic_context = BoxTrait::new(dyn_ctx);
    }

    // *************************************************************************
    //                        StaticExecutionContext getters
    // *************************************************************************

    #[inline(always)]
    fn starknet_address(self: @ExecutionContext) -> ContractAddress {
        (*self.static_context).unbox().starknet_address
    }

    #[inline(always)]
    fn evm_address(self: @ExecutionContext) -> EthAddress {
        (*self.static_context).unbox().evm_address
    }

    #[inline(always)]
    fn read_only(self: @ExecutionContext) -> bool {
        (*self.static_context).unbox().read_only
    }

    #[inline(always)]
    fn gas_limit(self: @ExecutionContext) -> u64 {
        (*self.static_context).unbox().gas_limit
    }

    // *************************************************************************
    //                          ExecutionContext methods
    // *************************************************************************

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
        let code = self
            .static_context
            .unbox()
            .call_context
            .bytecode()
            .slice(self.program_counter, len);

        self.program_counter += len;
        code
    }

    /// Returns if starknet contract address is an EOA
    #[inline(always)]
    fn is_caller_eoa(self: @ExecutionContext) -> bool {
        if get_caller_address() == self.starknet_address() {
            return true;
        };
        false
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
    #[inline(always)]
    fn default() -> ExecutionContext {
        ExecutionContext {
            static_context: BoxTrait::new(Default::default()),
            dynamic_context: BoxTrait::new(Default::default()),
            program_counter: 0,
            stack: Default::default(),
            memory: Default::default(),
        // calling_context: Default::default(),
        // sub_context: Default::default(),

        }
    }
}

impl DefaultEthAddress of Default<EthAddress> {
    #[inline(always)]
    fn default() -> EthAddress {
        0.try_into().unwrap()
    }
}

impl DefaultContractAddress of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        0.try_into().unwrap()
    }
}

/// The execution summary.
#[derive(Drop, Copy)]
struct ExecutionSummary {}
