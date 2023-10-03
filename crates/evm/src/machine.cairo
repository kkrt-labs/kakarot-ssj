use evm::{
    context::{
        ExecutionContext, ExecutionContextTrait, DefaultBoxExecutionContext, CallContext,
        CallContextTrait, Status, Event
    },
    stack::{Stack, StackTrait}, memory::{Memory, MemoryTrait}
};
use starknet::{EthAddress, ContractAddress};


/// The Journal tracks the changes applied to storage during the execution of a transaction.
/// Local changes tracks the changes applied inside a single execution context.
/// Global changes tracks the changes applied in the entire transaction.
/// Upon exiting an execution context, local changes must be finalized into global changes
/// Upon exiting the transaction, global changes must be finalized into storage updates.
#[derive(Destruct, Default)]
struct Journal {
    local_changes: Felt252Dict<felt252>,
    local_keys: Array<felt252>,
    global_changes: Felt252Dict<felt252>,
    global_keys: Array<felt252>
}

#[derive(Destruct)]
struct Machine {
    current_context: Box<ExecutionContext>,
    ctx_count: usize,
    stack: Stack,
    memory: Memory,
    storage_journal: Journal
}

impl DefaultMachine of Default<Machine> {
    fn default() -> Machine {
        Machine {
            current_context: Default::default(),
            ctx_count: 1,
            stack: Default::default(),
            memory: Default::default(),
            storage_journal: Default::default(),
        }
    }
}

/// A set of getters and setters for the current context
/// Since current_context is a pointer to the current context being executed by the machine we're forced into the following pattern:
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
    fn set_current_context(ref self: Machine, ctx: ExecutionContext) {
        self.memory.set_active_segment(ctx.id);
        self.stack.set_active_segment(ctx.id);
        self.current_context = BoxTrait::new(ctx);
    }

    #[inline(always)]
    fn pc(ref self: Machine) -> usize {
        let current_execution_ctx = self.current_context.unbox();
        let pc = current_execution_ctx.pc();
        self.current_context = BoxTrait::new(current_execution_ctx);
        pc
    }

    #[inline(always)]
    fn set_pc(ref self: Machine, new_pc: u32) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.program_counter = new_pc;
        self.current_context = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn revert(ref self: Machine, revert_reason: Span<u8>) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.revert(revert_reason);
        self.current_context = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn reverted(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_context.unbox();
        let reverted = current_execution_ctx.reverted();
        self.current_context = BoxTrait::new(current_execution_ctx);
        reverted
    }

    #[inline(always)]
    fn stopped(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_context.unbox();
        let stopped = current_execution_ctx.stopped();
        self.current_context = BoxTrait::new(current_execution_ctx);
        stopped
    }


    #[inline(always)]
    fn call_context(ref self: Machine) -> CallContext {
        let current_execution_ctx = self.current_context.unbox();
        let call_context = current_execution_ctx.call_context.unbox();
        self.current_context = BoxTrait::new(current_execution_ctx);
        call_context
    }

    #[inline(always)]
    fn destroyed_contracts(ref self: Machine) -> Span<EthAddress> {
        let current_execution_ctx = self.current_context.unbox();
        let destroyed_contracts = current_execution_ctx.destroyed_contracts.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        destroyed_contracts
    }

    #[inline(always)]
    fn events(ref self: Machine) -> Span<Event> {
        let current_execution_ctx = self.current_context.unbox();
        let events = current_execution_ctx.events.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        events
    }

    #[inline(always)]
    fn create_addresses(ref self: Machine) -> Span<EthAddress> {
        let current_execution_ctx = self.current_context.unbox();
        let create_addresses = current_execution_ctx.create_addresses.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        create_addresses
    }

    #[inline(always)]
    fn return_data(ref self: Machine) -> Span<u8> {
        let current_execution_ctx = self.current_context.unbox();
        let return_data = current_execution_ctx.return_data.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn stop(ref self: Machine) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.status = Status::Stopped;
        self.current_context = BoxTrait::new(current_execution_ctx);
    }


    #[inline(always)]
    fn evm_address(ref self: Machine) -> EthAddress {
        let current_execution_ctx = self.current_context.unbox();
        let evm_address = current_execution_ctx.evm_address();
        self.current_context = BoxTrait::new(current_execution_ctx);
        evm_address
    }

    #[inline(always)]
    fn starknet_address(ref self: Machine) -> ContractAddress {
        let current_execution_ctx = self.current_context.unbox();
        let starknet_address = current_execution_ctx.starknet_address();
        self.current_context = BoxTrait::new(current_execution_ctx);
        starknet_address
    }

    #[inline(always)]
    fn caller(ref self: Machine) -> EthAddress {
        let current_call_ctx = self.call_context();
        current_call_ctx.caller()
    }

    #[inline(always)]
    fn read_only(ref self: Machine) -> bool {
        let current_call_ctx = self.call_context();
        current_call_ctx.read_only()
    }

    #[inline(always)]
    fn append_event(ref self: Machine, event: Event) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.append_event(event);
        self.current_context = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn gas_limit(ref self: Machine) -> u64 {
        let current_call_ctx = self.call_context();
        current_call_ctx.gas_limit()
    }

    #[inline(always)]
    fn gas_price(ref self: Machine) -> u64 {
        let current_call_ctx = self.call_context();
        current_call_ctx.gas_price()
    }

    #[inline(always)]
    fn value(ref self: Machine) -> u256 {
        let current_call_ctx = self.call_context();
        current_call_ctx.value()
    }

    #[inline(always)]
    fn bytecode(ref self: Machine) -> Span<u8> {
        let current_call_ctx = self.call_context();
        current_call_ctx.bytecode()
    }

    #[inline(always)]
    fn calldata(ref self: Machine) -> Span<u8> {
        let current_call_ctx = self.call_context();
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
        let current_execution_ctx = self.current_context.unbox();
        let is_root = current_execution_ctx.id == 0;
        self.current_context = BoxTrait::new(current_execution_ctx);
        is_root
    }

    #[inline(always)]
    fn set_return_data(ref self: Machine, value: Array<u8>) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.return_data = value;
        self.current_context = BoxTrait::new(current_execution_ctx);
    }
}
