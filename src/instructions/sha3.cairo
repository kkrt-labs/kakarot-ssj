//! SHA3.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// SHA3 operation.
/// Hashes n memory elements at m memory offset.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Sha3
/// - Gas: 30
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sha3(ref context: ExecutionContext) {}
