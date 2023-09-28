use evm::{
    context::{
        ExecutionContext, ExecutionContextTrait, DefaultBoxExecutionContext, CallContext,
        CallContextTrait, Status, Event
    },
    stack::Stack, memory::Memory
};
use starknet::{EthAddress, ContractAddress};


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
impl MachineCurrentContextImpl of MachineCurrentContext {
    #[inline(always)]
    fn current_ctx_pc(ref self: Machine) -> usize {
        let current_execution_ctx = self.current_context.unbox();
        let pc = current_execution_ctx.program_counter;
        self.current_context = BoxTrait::new(current_execution_ctx);
        pc
    }

    #[inline(always)]
    fn set_pc_current_ctx(ref self: Machine, new_pc: u32) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.program_counter = new_pc;
        self.current_context = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn revert_current_ctx(ref self: Machine, revert_reason: Span<u8>) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.revert(revert_reason);
        self.current_context = BoxTrait::new(current_execution_ctx);
    }

    #[inline(always)]
    fn current_ctx_reverted(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_context.unbox();
        let reverted = current_execution_ctx.reverted();
        self.current_context = BoxTrait::new(current_execution_ctx);
        reverted
    }

    #[inline(always)]
    fn current_ctx_stopped(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_context.unbox();
        let stopped = current_execution_ctx.stopped();
        self.current_context = BoxTrait::new(current_execution_ctx);
        stopped
    }


    #[inline(always)]
    fn current_ctx_call_context(ref self: Machine) -> CallContext {
        let current_execution_ctx = self.current_context.unbox();
        let call_context = current_execution_ctx.call_context.unbox();
        self.current_context = BoxTrait::new(current_execution_ctx);
        call_context
    }

    #[inline(always)]
    fn current_ctx_destroyed_contracts(ref self: Machine) -> Span<EthAddress> {
        let current_execution_ctx = self.current_context.unbox();
        let destroyed_contracts = current_execution_ctx.destroyed_contracts.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        destroyed_contracts
    }

    #[inline(always)]
    fn current_ctx_events(ref self: Machine) -> Span<Event> {
        let current_execution_ctx = self.current_context.unbox();
        let events = current_execution_ctx.events.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        events
    }

    #[inline(always)]
    fn current_ctx_create_addresses(ref self: Machine) -> Span<EthAddress> {
        let current_execution_ctx = self.current_context.unbox();
        let create_addresses = current_execution_ctx.create_addresses.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        create_addresses
    }

    #[inline(always)]
    fn current_ctx_return_data(ref self: Machine) -> Span<u8> {
        let current_execution_ctx = self.current_context.unbox();
        let return_data = current_execution_ctx.return_data.span();
        self.current_context = BoxTrait::new(current_execution_ctx);
        return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn stop_current_ctx(ref self: Machine) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.status = Status::Stopped;
        self.current_context = BoxTrait::new(current_execution_ctx);
    }


    #[inline(always)]
    fn current_ctx_evm_address(ref self: Machine) -> EthAddress {
        let current_execution_ctx = self.current_context.unbox();
        let evm_address = current_execution_ctx.evm_address();
        self.current_context = BoxTrait::new(current_execution_ctx);
        evm_address
    }

    #[inline(always)]
    fn current_ctx_starknet_address(ref self: Machine) -> ContractAddress {
        let current_execution_ctx = self.current_context.unbox();
        let starknet_address = current_execution_ctx.starknet_address();
        self.current_context = BoxTrait::new(current_execution_ctx);
        starknet_address
    }

    #[inline(always)]
    fn current_ctx_caller(ref self: Machine) -> EthAddress {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.caller()
    }

    #[inline(always)]
    fn current_ctx_read_only(ref self: Machine) -> bool {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.read_only()
    }

    #[inline(always)]
    fn current_ctx_gas_limit(ref self: Machine) -> u64 {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.gas_limit()
    }

    #[inline(always)]
    fn current_ctx_gas_price(ref self: Machine) -> u64 {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.gas_price()
    }

    #[inline(always)]
    fn current_ctx_value(ref self: Machine) -> u256 {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.value()
    }

    #[inline(always)]
    fn current_ctx_bytecode(ref self: Machine) -> Span<u8> {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.bytecode()
    }

    #[inline(always)]
    fn current_ctx_calldata(ref self: Machine) -> Span<u8> {
        let current_call_ctx = self.current_ctx_call_context();
        current_call_ctx.calldata()
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
    fn read_code_current_ctx(ref self: Machine, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let pc = self.current_ctx_pc();
        let code = self.current_ctx_call_context().bytecode().slice(pc, len);

        self.set_pc_current_ctx(pc + len);
        code
    }


    #[inline(always)]
    fn current_ctx_is_root(ref self: Machine) -> bool {
        let current_execution_ctx = self.current_context.unbox();
        let is_root = current_execution_ctx.context_id == 0;
        self.current_context = BoxTrait::new(current_execution_ctx);
        is_root
    }

    // TODO: Implement print_debug
    /// Debug print the execution context.
    #[inline(always)]
    fn print_debug(ref self: Machine) {}

    #[inline(always)]
    fn set_return_data_current_ctx(ref self: Machine, value: Array<u8>) {
        let mut current_execution_ctx = self.current_context.unbox();
        current_execution_ctx.return_data = value;
        self.current_context = BoxTrait::new(current_execution_ctx);
    }
}
