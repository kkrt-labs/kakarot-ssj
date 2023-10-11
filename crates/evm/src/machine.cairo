use evm::storage_journal::Journal;
use evm::{
    context::{
        ExecutionContext, ExecutionContextTrait, DefaultBoxExecutionContext, CallContext,
        CallContextTrait, Status, Event
    },
    stack::{Stack, StackTrait}, memory::{Memory, MemoryTrait}
};

use starknet::{EthAddress, ContractAddress};

#[derive(Destruct)]
struct Machine {
    current_ctx: Box<ExecutionContext>,
    ctx_count: usize,
    stack: Stack,
    memory: Memory,
    storage_journal: Journal
}

impl DefaultMachine of Default<Machine> {
    fn default() -> Machine {
        Machine {
            current_ctx: Default::default(),
            ctx_count: 1,
            stack: Default::default(),
            memory: Default::default(),
            storage_journal: Default::default(),
        }
    }
}

/// A set of getters and setters for the current context
/// Since current_ctx is a pointer to the current context being executed by the machine we're forced into the following pattern:
///
/// For getters:
/// Unbox the current ExecutionContext
/// Access a value
/// Rebox the current ExecutionContext
///
/// For setters:
/// Unbox the current ExecutionContext into a mut variable
/// Modify the desired field
/// Rebox the modified current ExecutionContext
///
/// Limitations:
/// 1. We're not able to use @Machine as an argument for getters, as the ExecutionContext struct does not derive the Copy trait.
/// 2. We must use a box reference to the current context, as the changes made during execution must be applied
/// to only one ExecutionContext struct instance. Using a pointer ensures we never duplicate structs and thus changes.

#[generate_trait]
impl MachineCurrentContextImpl of MachineCurrentContextTrait {
    /// Sets the current execution context being executed by the machine.
    /// This is an implementation-specific concept that is used
    /// to divide a unique Stack/Memory simulated by a dict into
    /// multiple sub-structures relative to a single context.
    #[inline(always)]
    fn set_current_ctx(ref self: Machine, ctx: ExecutionContext) {
        self.memory.set_active_segment(ctx.id);
        self.stack.set_active_segment(ctx.id);
        self.current_ctx = BoxTrait::new(ctx);
    }

    #[inline(always)]
    fn pc(ref self: Machine) -> usize {
        let current_execution_ctx = self.current_ctx.unbox();
        let pc = current_execution_ctx.pc();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        pc
    }

    #[inline(always)]
    fn set_pc(ref self: Machine, new_pc: u32) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.program_counter = new_pc;
        self.current_ctx = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn revert(ref self: Machine, revert_reason: Span<u8>) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.revert(revert_reason);
        self.current_ctx = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn reverted(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_ctx.unbox();
        let reverted = current_execution_ctx.reverted();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        reverted
    }

    #[inline(always)]
    fn stopped(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_ctx.unbox();
        let stopped = current_execution_ctx.stopped();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        stopped
    }

    #[inline(always)]
    fn status(ref self: Machine) -> Status {
        let current_execution_ctx = self.current_ctx.unbox();
        let status = current_execution_ctx.status();

        self.current_ctx = BoxTrait::new(current_execution_ctx);
        status
    }


    #[inline(always)]
    fn call_ctx(ref self: Machine) -> CallContext {
        let current_execution_ctx = self.current_ctx.unbox();
        let call_ctx = current_execution_ctx.call_ctx.unbox();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        call_ctx
    }

    #[inline(always)]
    fn destroyed_contracts(ref self: Machine) -> Span<EthAddress> {
        let current_execution_ctx = self.current_ctx.unbox();
        let destroyed_contracts = current_execution_ctx.destroyed_contracts.span();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        destroyed_contracts
    }

    #[inline(always)]
    fn events(ref self: Machine) -> Span<Event> {
        let current_execution_ctx = self.current_ctx.unbox();
        let events = current_execution_ctx.events.span();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        events
    }

    #[inline(always)]
    fn create_addresses(ref self: Machine) -> Span<EthAddress> {
        let current_execution_ctx = self.current_ctx.unbox();
        let create_addresses = current_execution_ctx.create_addresses.span();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        create_addresses
    }

    #[inline(always)]
    fn return_data(ref self: Machine) -> Span<u8> {
        let current_execution_ctx = self.current_ctx.unbox();
        let return_data = current_execution_ctx.return_data.span();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn stop(ref self: Machine) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.status = Status::Stopped;
        self.current_ctx = BoxTrait::new(current_execution_ctx);
    }


    #[inline(always)]
    fn evm_address(ref self: Machine) -> EthAddress {
        let current_execution_ctx = self.current_ctx.unbox();
        let evm_address = current_execution_ctx.evm_address();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        evm_address
    }

    #[inline(always)]
    fn starknet_address(ref self: Machine) -> ContractAddress {
        let current_execution_ctx = self.current_ctx.unbox();
        let starknet_address = current_execution_ctx.starknet_address();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        starknet_address
    }

    #[inline(always)]
    fn caller(ref self: Machine) -> EthAddress {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.caller()
    }

    #[inline(always)]
    fn origin(ref self: Machine) -> EthAddress {
        let mut current_execution_ctx = self.current_ctx.unbox();
        let origin = current_execution_ctx.origin();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        origin
    }

    #[inline(always)]
    fn read_only(ref self: Machine) -> bool {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.read_only()
    }

    #[inline(always)]
    fn append_event(ref self: Machine, event: Event) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.append_event(event);
        self.current_ctx = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn gas_limit(ref self: Machine) -> u64 {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.gas_limit()
    }

    #[inline(always)]
    fn gas_price(ref self: Machine) -> u64 {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.gas_price()
    }

    #[inline(always)]
    fn value(ref self: Machine) -> u256 {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.value()
    }

    #[inline(always)]
    fn bytecode(ref self: Machine) -> Span<u8> {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.bytecode()
    }

    #[inline(always)]
    fn calldata(ref self: Machine) -> Span<u8> {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.calldata()
    }

    /// Reads and returns `size` elements from bytecode starting from the current value
    /// `pc`.
    /// # Arguments
    ///
    /// * `self` - The `Machine` instance to read the data from.
    /// * The current execution context is handled implicitly by the Machine.
    /// * `len` - The length of the data to read from the bytecode.
    #[inline(always)]
    fn read_code(ref self: Machine, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let pc = self.pc();
        let code = self.bytecode().slice(pc, len);

        code
    }


    /// Returns whether the current execution context is the root context.
    /// The root is always the first context to be executed, and thus has id 0.
    #[inline(always)]
    fn is_root(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_ctx.unbox();
        let is_root = current_execution_ctx.id == 0;
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        is_root
    }

    #[inline(always)]
    fn set_return_data(ref self: Machine, value: Array<u8>) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.return_data = value;
        self.current_ctx = BoxTrait::new(current_execution_ctx);
    }

    /// Getter for the return data of a child context, accessed from its parent context
    /// Enabler for RETURNDATASIZE and RETURNDATACOPY opcodes
    #[inline(always)]
    fn child_return_data(ref self: Machine) -> Option<Span<u8>> {
        let mut current_execution_ctx = self.current_ctx.unbox();
        let child_return_data = current_execution_ctx.child_return_data();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        child_return_data
    }
}
