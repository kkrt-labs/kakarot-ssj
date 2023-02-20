// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// @notice 0x00 - STOP
/// @dev Halts execution
/// @custom:since Frontier
/// @custom:group Stop and Arithmetic Operations
/// @custom:gas 0
/// # Arguments
/// * ctx The pointer to the execution context
fn stop(ref context: ExecutionContext) {
    context.stop();
}
