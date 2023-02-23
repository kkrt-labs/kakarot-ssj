//! Logging Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// Generic logging operation.
/// Append log record with n topics.
/// # Arguments
/// * `ctx` - the execution context.
/// * `topics_len` - The Topic length.
/// # TODO
/// - Implement me.
fn exec_log_i(ref context: ExecutionContext, topics_len: u8) {}

/// LOG0 operation
/// Append log record with no topic.
/// - Since:  Frontier
/// - Group: Logging Operations
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_log0(ref context: ExecutionContext) {
    exec_log_i(ref context, 0_u8);
}


/// LOG1 operation
/// Append log record with one topic.
/// - Since:  Frontier
/// - Group: Logging Operations
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_log1(ref context: ExecutionContext) {
    exec_log_i(ref context, 1_u8);
}

/// LOG2 operation
/// Append log record with two topics.
/// - Since:  Frontier
/// - Group: Logging Operations
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_log2(ref context: ExecutionContext) {
    exec_log_i(ref context, 2_u8);
}

/// LOG3 operation
/// Append log record with three topics.
/// - Since:  Frontier
/// - Group: Logging Operations
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_log3(ref context: ExecutionContext) {
    exec_log_i(ref context, 3_u8);
}

/// LOG4 operation
/// Append log record with 4 topics.
/// - Since:  Frontier
/// - Group: Logging Operations
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_log4(ref context: ExecutionContext) {
    exec_log_i(ref context, 4_u8);
}
