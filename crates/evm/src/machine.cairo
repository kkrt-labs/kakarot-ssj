use evm::errors::{EVMError, MISSING_PARENT_CONTEXT};
use evm::model::Address;
use evm::state::State;
use evm::{
    context::{
        ExecutionContext, ExecutionContextType, ExecutionContextTrait, DefaultBoxExecutionContext,
        CallContext, CallContextTrait, Status, Event
    },
    stack::{Stack, StackTrait}, memory::{Memory, MemoryTrait}
};

use nullable::{match_nullable, FromNullableResult};

use starknet::{EthAddress, ContractAddress};

#[derive(Destruct)]
struct Machine {
    current_ctx: Box<ExecutionContext>,
    ctx_count: usize,
    stack: Stack,
    memory: Memory,
    state: State,
}

impl DefaultMachine of Default<Machine> {
    fn default() -> Machine {
        Machine {
            current_ctx: Default::default(),
            ctx_count: 1,
            stack: Default::default(),
            memory: Default::default(),
            state: Default::default(),
        }
    }
}

#[derive(Destruct)]
struct MachineBuilder {
    machine: Machine
}

#[generate_trait]
impl MachineBuilderImpl of MachineBuilderTrait {
    fn new() -> MachineBuilder {
        MachineBuilder { machine: Default::default() }
    }

    #[inline(always)]
    fn set_ctx(mut self: MachineBuilder, ctx: ExecutionContext) -> MachineBuilder {
        self.machine.current_ctx = BoxTrait::new(ctx);
        self
    }

    #[inline(always)]
    fn set_state(mut self: MachineBuilder, state: State) -> MachineBuilder {
        self.machine.state = state;
        self
    }

    #[inline(always)]
    fn build(self: MachineBuilder) -> Machine {
        self.machine
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
impl MachineImpl of MachineTrait {
    #[inline(always)]
    fn new(ctx: ExecutionContext) -> Machine {
        Machine {
            current_ctx: BoxTrait::new(ctx),
            ctx_count: 1,
            stack: Default::default(),
            memory: Default::default(),
            state: Default::default(),
        }
    }

    #[inline(always)]
    fn id(ref self: Machine) -> usize {
        let current_execution_ctx = self.current_ctx.unbox();
        let id = current_execution_ctx.id();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        id
    }

    /// Sets the current execution context being executed by the machine.
    /// This is an implementation-specific concept that is used
    /// to divide a unique Stack/Memory simulated by a dict into
    /// multiple sub-structures relative to a single context.
    #[inline(always)]
    fn set_current_ctx(ref self: Machine, ctx: ExecutionContext) {
        self.memory.set_active_segment(ctx.id());
        self.stack.set_active_segment(ctx.id());
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
    fn set_reverted(ref self: Machine) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.set_reverted();
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

    /// Returns from the sub context by setting the current context
    /// to the parent context.
    ///
    /// # Errors
    /// - InvalidMachineState: when the parent context is Null.
    #[inline(always)]
    fn return_to_parent_ctx(ref self: Machine) -> Result<(), EVMError> {
        let mut current_ctx = self.current_ctx.unbox();
        let return_data = current_ctx.return_data();
        let maybe_parent_ctx = current_ctx.parent_ctx;
        match match_nullable(maybe_parent_ctx) {
            FromNullableResult::Null => {
                // These two lines are used to satisfy the compiler,
                // otherwise we get a `Value Was Previously Moved` Error
                current_ctx.parent_ctx = Default::default();
                self.current_ctx = BoxTrait::new(current_ctx);
                return Result::Err(EVMError::InvalidMachineState(MISSING_PARENT_CONTEXT));
            },
            FromNullableResult::NotNull(parent_ctx) => {
                let mut parent_ctx = parent_ctx.unbox();
                parent_ctx.return_data = return_data;
                current_ctx = parent_ctx;
            },
        };
        self.current_ctx = BoxTrait::new(current_ctx);
        Result::Ok(())
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
        let return_data = current_execution_ctx.return_data;
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn set_stopped(ref self: Machine) {
        let mut current_execution_ctx = self.current_ctx.unbox();
        current_execution_ctx.status = Status::Stopped;
        self.current_ctx = BoxTrait::new(current_execution_ctx);
    }


    #[inline(always)]
    fn address(ref self: Machine) -> Address {
        let current_execution_ctx = self.current_ctx.unbox();
        let evm_address = current_execution_ctx.address();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        evm_address
    }

    #[inline(always)]
    fn caller(ref self: Machine) -> Address {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.caller()
    }

    #[inline(always)]
    fn origin(ref self: Machine) -> Address {
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
    fn gas_limit(ref self: Machine) -> u128 {
        let current_call_ctx = self.call_ctx();
        current_call_ctx.gas_limit()
    }

    #[inline(always)]
    fn gas_price(ref self: Machine) -> u128 {
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

    /// Returns the current execution context type (root, call or create).
    #[inline(always)]
    fn ctx_type(ref self: Machine) -> ExecutionContextType {
        let current_execution_ctx = self.current_ctx.unbox();
        let ctx_type = current_execution_ctx.ctx_type();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        ctx_type
    }

    /// Returns whether the current execution context is the root context.
    #[inline(always)]
    fn is_root(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_ctx.unbox();
        let is_root = current_execution_ctx.is_root();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        is_root
    }

    /// Returns whether the current execution context is a call context.
    #[inline(always)]
    fn is_call(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_ctx.unbox();
        let is_call = current_execution_ctx.is_call();
        self.current_ctx = BoxTrait::new(current_execution_ctx);
        is_call
    }

    /// Sets the `return_data` field of the appropriate execution context,
    /// taking into acount EVM specs: If the current context is the root
    /// context, sets the return_data field of the root context.  If the current
    /// context is a subcontext, sets the return_data field of the parent.
    /// Should be called when returning from a context.
    #[inline(always)]
    fn set_return_data(ref self: Machine, value: Span<u8>) {
        let mut current_ctx = self.current_ctx.unbox();
        current_ctx.return_data = value;
        self.current_ctx = BoxTrait::new(current_ctx);
    }
}
