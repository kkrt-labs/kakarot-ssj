use debug::PrintTrait;
use evm::memory::{Memory, MemoryTrait};
use evm::model::Event;
use evm::stack::{Stack, StackTrait};
use starknet::get_caller_address;
use starknet::{EthAddress, ContractAddress};
use utils::helpers::{ArrayExtension, ArrayExtTrait};
use utils::traits::{SpanDefault, EthAddressDefault, ContractAddressDefault};

#[derive(Drop, Default, Copy, PartialEq)]
enum Status {
    #[default]
    Active,
    Stopped,
    Reverted
}

// *************************************************************************
//                              CallContext
// *************************************************************************
// We should not directly access the fields of the call context;
// instead we should use the methods defined in the trait.
// This is not enforced until there are `pub` and `priv` visibility on struct fields.

/// The call context.
#[derive(Drop, Copy, Default)]
struct CallContext {
    caller: EthAddress,
    /// The bytecode to execute.
    bytecode: Span<u8>,
    /// The call data.
    calldata: Span<u8>,
    /// Amount of native token to transfer.
    value: u256,
    // If the call is read only (cannot modify the state of the chain)
    read_only: bool,
    // Evm gas limit for the call
    gas_limit: u128,
    // Evm gas price for the call
    gas_price: u128,
    // The offset in memory to store the context return
    ret_offset: usize,
    // The size in memory to store the context return
    ret_size: usize,
}

#[generate_trait]
impl CallContextImpl of CallContextTrait {
    #[inline(always)]
    fn new(
        caller: EthAddress,
        bytecode: Span<u8>,
        calldata: Span<u8>,
        value: u256,
        read_only: bool,
        gas_limit: u128,
        gas_price: u128,
        ret_offset: usize,
        ret_size: usize
    ) -> CallContext {
        CallContext {
            caller, bytecode, calldata, value, read_only, gas_limit, gas_price, ret_offset, ret_size
        }
    }


    #[inline(always)]
    fn caller(self: @CallContext) -> EthAddress {
        *self.caller
    }


    #[inline(always)]
    fn bytecode(self: @CallContext) -> Span<u8> {
        *self.bytecode
    }

    #[inline(always)]
    fn calldata(self: @CallContext) -> Span<u8> {
        *self.calldata
    }

    #[inline(always)]
    fn value(self: @CallContext) -> u256 {
        *self.value
    }

    #[inline(always)]
    fn read_only(self: @CallContext) -> bool {
        *self.read_only
    }

    #[inline(always)]
    fn gas_limit(self: @CallContext) -> u128 {
        *self.gas_limit
    }

    #[inline(always)]
    fn gas_price(self: @CallContext) -> u128 {
        *self.gas_price
    }
}

impl DefaultBoxCallContext of Default<Box<CallContext>> {
    fn default() -> Box<CallContext> {
        let call_ctx: CallContext = Default::default();
        BoxTrait::new(call_ctx)
    }
}

impl DefaultOptionSpanU8 of Default<Option<Span<u8>>> {
    fn default() -> Option<Span<u8>> {
        Option::None
    }
}


// *************************************************************************
//                              ExecutionContext
// *************************************************************************

/// The execution context.
/// Stores all data relevant to the current execution context.
#[derive(Drop, Default)]
struct ExecutionContext {
    ctx_type: ExecutionContextType,
    evm_address: EthAddress,
    program_counter: u32,
    status: Status,
    call_ctx: Box<CallContext>,
    destroyed_contracts: Array<EthAddress>,
    events: Array<Event>,
    create_addresses: Array<EthAddress>,
    // Return data of a child context.
    return_data: Span<u8>,
    parent_ctx: Nullable<ExecutionContext>,
}

/// A context is either: the root, a call sub-context or a create sub-context.
/// In the case of call and create, the execution context requires an id number
/// to access their respective Stack and Memory; while the Root context always has
/// id equal to 0.
#[derive(Drop, Default, Copy, PartialEq)]
enum ExecutionContextType {
    #[default]
    Root,
    Call: usize,
    Create: usize
}

impl DefaultBoxExecutionContext of Default<Box<ExecutionContext>> {
    fn default() -> Box<ExecutionContext> {
        let context: ExecutionContext = Default::default();
        BoxTrait::new(context)
    }
}


/// `ExecutionContext` implementation.

#[generate_trait]
impl ExecutionContextImpl of ExecutionContextTrait {
    /// Create a new execution context instance.
    #[inline(always)]
    fn new(
        ctx_type: ExecutionContextType,
        evm_address: EthAddress,
        call_ctx: CallContext,
        parent_ctx: Nullable<ExecutionContext>,
        return_data: Span<u8>,
    ) -> ExecutionContext {
        ExecutionContext {
            ctx_type,
            evm_address,
            program_counter: Default::default(),
            status: Status::Active,
            call_ctx: BoxTrait::new(call_ctx),
            destroyed_contracts: Default::default(),
            events: Default::default(),
            create_addresses: Default::default(),
            return_data,
            parent_ctx,
        }
    }

    // *************************************************************************
    //                      DynamicContext getters
    // *************************************************************************

    #[inline(always)]
    fn reverted(self: @ExecutionContext) -> bool {
        if (*self.status == Status::Reverted) {
            return true;
        }
        false
    }

    #[inline(always)]
    fn stopped(self: @ExecutionContext) -> bool {
        // A context is considered stopped if it has status Stopped or Reverted
        if (*self.status == Status::Active) {
            return false;
        }
        true
    }

    #[inline(always)]
    fn status(self: @ExecutionContext) -> Status {
        *self.status
    }

    #[inline(always)]
    fn call_ctx(self: @ExecutionContext) -> CallContext {
        (*self.call_ctx).unbox()
    }

    #[inline(always)]
    fn destroyed_contracts(self: @ExecutionContext) -> Span<EthAddress> {
        self.destroyed_contracts.span()
    }

    #[inline(always)]
    fn events(self: @ExecutionContext) -> Span<Event> {
        self.events.span()
    }

    #[inline(always)]
    fn create_addresses(self: @ExecutionContext) -> Span<EthAddress> {
        self.create_addresses.span()
    }

    #[inline(always)]
    fn return_data(self: @ExecutionContext) -> Span<u8> {
        *self.return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn set_stopped(ref self: ExecutionContext) {
        self.status = Status::Stopped;
    }

    /// Revert the current execution context.
    ///
    /// When the execution context is reverted, no more instructions can be executed
    /// (it is stopped) and contract creation and contract storage writes are
    /// reverted on its finalization.
    #[inline(always)]
    fn set_reverted(ref self: ExecutionContext) {
        self.status = Status::Reverted;
    }

    // *************************************************************************
    //                        StaticExecutionContext getters
    // *************************************************************************

    #[inline(always)]
    fn evm_address(self: @ExecutionContext) -> EthAddress {
        *self.evm_address
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
    fn read_code(self: @ExecutionContext, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let code = (*self.call_ctx).unbox().bytecode().slice(self.pc(), len);

        code
    }

    /// Returns the read only field for the current call context
    ///
    /// # Arguments
    ///
    /// * `self` - The `ExecutionContext` instance to read the data from.
    #[inline(always)]
    fn read_only(self: @ExecutionContext) -> bool {
        let read_only = (*self.call_ctx).unbox().read_only();

        read_only
    }

    #[inline(always)]
    fn is_call(self: @ExecutionContext) -> bool {
        match *self.ctx_type {
            ExecutionContextType::Root(_) => false,
            ExecutionContextType::Call(_) => true,
            ExecutionContextType::Create(_) => false,
        }
    }

    #[inline(always)]
    fn is_root(self: @ExecutionContext) -> bool {
        *self.ctx_type == ExecutionContextType::Root
    }

    #[inline(always)]
    fn ctx_type(self: @ExecutionContext) -> ExecutionContextType {
        *self.ctx_type
    }

    #[inline(always)]
    fn id(self: @ExecutionContext) -> usize {
        match *self.ctx_type {
            ExecutionContextType::Root => 0,
            ExecutionContextType::Call(id) => id,
            ExecutionContextType::Create(id) => id,
        }
    }

    // TODO: Implement print_debug
    /// Debug print the execution context.
    #[inline(always)]
    fn print_debug(ref self: ExecutionContext) {
        // debug::print_felt252('gas used');
        // self.gas_used.print();
        'print debug'.print();
    }

    #[inline(always)]
    fn set_pc(ref self: ExecutionContext, value: u32) {
        self.program_counter = value;
    }

    #[inline(always)]
    fn pc(self: @ExecutionContext) -> u32 {
        *self.program_counter
    }


    #[inline(always)]
    fn append_event(ref self: ExecutionContext, event: Event) {
        self.events.append(event);
    }

    fn origin(ref self: ExecutionContext) -> EthAddress {
        if (self.is_root()) {
            return self.call_ctx().caller();
        }
        // If the current execution context is not root, then it MUST have a parent_context
        // We're able to deref the nullable pointer without risk of panic
        let mut parent_context = self.parent_ctx.deref();

        // Entering a recursion
        let origin = parent_context.origin();

        // Recursively reboxing parent contexts
        self.parent_ctx = NullableTrait::new(parent_context);

        // Return self.call_context().caller() where self is the root context
        origin
    }
}
