use kakarot::stack::Stack;
use kakarot::stack::StackTrait;

/// The call context.
#[derive(Drop)]
struct CallContext {
    /// The bytecode to execute.
    bytecode: Array::<u8>,
    /// The call data.
    call_data: Array::<u8>,
    /// Amount of native token to transfer.
    value: felt252,
}


/// The execution context.
/// Stores all data relevant to the current execution context.
#[derive(Destruct)]
struct ExecutionContext {
    /// The call context.
    call_context: CallContext,
    /// The current program counter.
    program_counter: u32,
    /// The gas used.
    gas_used: u64,
    /// The stack.
    stack: Stack,
    /// Whether the execution context is halted.
    stopped: bool,
}

/// Execution context trait.
trait ExecutionContextTrait {
    /// Create a new execution context.
    fn new(call_context: CallContext) -> ExecutionContext;
    /// Compute the intrinsic gas cost for the current transaction and increase the gas used.
    fn process_intrinsic_gas_cost(ref self: ExecutionContext);
    /// Debug print the execution context.
    fn print_debug(ref self: ExecutionContext);
    /// Halts execution.
    fn stop(ref self: ExecutionContext);
}

/// `ExecutionContext` implementation.
impl ExecutionContextImpl of ExecutionContextTrait {
    /// Create a new execution context instance.
    #[inline(always)]
    fn new(call_context: CallContext) -> ExecutionContext {
        let mut stack = StackTrait::new();
        ExecutionContext {
            call_context: call_context,
            program_counter: 0_u32,
            gas_used: 0_u64,
            stack: stack,
            stopped: false
        }
    }

    /// Compute the intrinsic gas cost for the current transaction and increase the gas used.
    /// TODO: Implement this. For now we just increase the gas used by a hard coded value.
    fn process_intrinsic_gas_cost(ref self: ExecutionContext) {
        // Deconstruct self.
        let ExecutionContext{call_context,
        program_counter,
        gas_used: mut gas_used,
        stack,
        stopped } =
            self;
        // TODO: debug `Failed to specialize: `dup<kakarot::context::ExecutionContext>` error
        //let new_gas_used = gas_used + 42_u64;
        // Reconstruct self.
        self = ExecutionContext {
            call_context, program_counter, gas_used: 42_u64, stack, stopped, 
        };
    }

    /// Halts execution.
    /// TODO: implement this.
    fn stop(ref self: ExecutionContext) {}

    /// Debug print the execution context.
    fn print_debug(ref self: ExecutionContext) { // debug::print_felt252('gas used');
    // TODO: debug `Failed to specialize: `dup<kakarot::context::ExecutionContext>` error
    //debug::print_felt252(u64_to_felt252(self.gas_used));
    }
}

/// The execution summary.
#[derive(Drop, Copy)]
struct ExecutionSummary {}

