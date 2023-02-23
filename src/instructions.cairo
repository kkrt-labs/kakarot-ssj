/// System imports.
use array::ArrayTrait;
use traits::Into;

/// Internal imports.
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionSummary;

/// Sub modules.
mod block_information;
mod comparison_operations;
mod duplication_operations;
mod environmental_information;
mod exchange_operations;
mod logging_operations;
mod memory_operations;
mod push_operations;
mod sha3;
mod stop_and_arithmetic_operations;
mod system_operations;

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
        // TODO: investigate why this is not working. The next line triggers this error:
        // thread 'main' panicked at 'Failed to specialize: `dup<kakarot::context::ExecutionContext>`
        //let pc = context.program_counter;
        //let opcode = context.call_context.bytecode.at(pc);
        //let opcode_felt = (*opcode).into();
        //debug::print_felt(opcode_felt);
        let opcode = 0_u8;
        let opcode_felt = opcode.into();
        match opcode_felt {
            0 => {
                // STOP
                stop_and_arithmetic_operations::stop(ref context);
            },
            _ => {},
        }

        ExecutionSummary {}
    }
}
