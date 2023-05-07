use kakarot::stack::Stack;
use kakarot::stack::StackTrait;
use debug::PrintTrait;
use array::ArrayTrait;

/// The call context.
#[derive(Drop)]
struct CallContext {
    /// The bytecode to execute.
    bytecode: Array<u8>,
    /// The call data.
    call_data: Array<u8>,
    /// Amount of native token to transfer.
    value: felt252,
}

// I think we should not directly access the fields of the call context;
// instead we should use the methods defined in the trait. 
// This is not enforced until there are `pub` and `priv` visibility on struct fields.
trait CallContextTrait {
    fn bytecode(self: @CallContext) -> Span<u8>;
    fn call_data(self: @CallContext) -> Span<u8>;
    fn value(self: @CallContext) -> felt252;
}

impl CallContextImpl of CallContextTrait {
    fn bytecode(self: @CallContext) -> Span<u8> {
        self.bytecode.span()
    }

    fn call_data(self: @CallContext) -> Span<u8> {
        self.call_data.span()
    }

    fn value(self: @CallContext) -> felt252 {
        *self.value
    }
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
            program_counter: 0,
            gas_used: 0,
            stack: stack,
            stopped: false
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

