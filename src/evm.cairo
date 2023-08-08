use kakarot::context::CallContext;
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionSummary;
use kakarot::context::ExecutionContextTrait;
use kakarot::instructions::EVMInstructionsTrait;

/// Execute EVM bytecode.
fn execute(call_context: CallContext) {
    /// TODO: implement the execute function. 
    /// TODO: This function should run the given bytecode with the given calldata and parameters.
    // Create new execution context.
    let mut ctx = ExecutionContextTrait::new(call_context);
    // Compute the intrinsic gas cost for the current transaction and increase the gas used.
    ctx.process_intrinsic_gas_cost();
    // Print the execution context.
    ctx.print_debug();
    let mut evm_instructions = EVMInstructionsTrait::new();
    // Execute the transaction.
    evm_instructions.run(ref ctx)
}

