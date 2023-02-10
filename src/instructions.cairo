use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionSummary;

/// EVM instructions as defined in the Yellow Paper and the EIPs.
#[derive(Drop, Copy)]
struct EVMInstructions {}

trait EVMInstructionsTrait {
    /// Create a new instance of the EVM instructions.
    fn new() -> EVMInstructions;
    /// Execute the EVM instructions and return the execution summary.
    fn execute(ref self: EVMInstructions, ref context: ExecutionContext) -> ExecutionSummary;
}


impl EVMInstructionsImpl of EVMInstructionsTrait {
    /// Create a new instance of the EVM instructions.
    #[inline(always)]
    fn new() -> EVMInstructions {
        EVMInstructions {}
    }

    /// Execute the EVM instructions and return the execution summary.
    /// # Arguments
    /// * `self` - The EVM instructions.
    /// * `context` - The execution context.
    /// # Returns
    /// The execution summary.
    fn execute(ref self: EVMInstructions, ref context: ExecutionContext) -> ExecutionSummary {
        ExecutionSummary {}
    }
}
