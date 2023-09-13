//! Logging Operations.

// Internal imports
use evm::context::{ExecutionContextTrait, ExecutionContext};

mod internal {
    use evm::context::{ExecutionContextTrait, ExecutionContext};

    /// Generic logging operation.
    /// Append log record with n topics.
    fn exec_log_i(ref context: ExecutionContext, topics_len: u8) {}
}

/// 0xA0 - LOG0 operation
/// Append log record with no topic.
/// # Specification: https://www.evm.codes/#a0?fork=shanghai
fn exec_log0(ref context: ExecutionContext) {
    internal::exec_log_i(ref context, 0);
}


/// 0xA1 - LOG1
/// Append log record with one topic.
/// # Specification: https://www.evm.codes/#a1?fork=shanghai
fn exec_log1(ref context: ExecutionContext) {
    internal::exec_log_i(ref context, 1);
}

/// 0xA2 - LOG2
/// Append log record with two topics.
/// # Specification: https://www.evm.codes/#a2?fork=shanghai
fn exec_log2(ref context: ExecutionContext) {
    internal::exec_log_i(ref context, 2);
}

/// 0xA3 - LOG3
/// Append log record with three topics.
/// # Specification: https://www.evm.codes/#a3?fork=shanghai
fn exec_log3(ref context: ExecutionContext) {
    internal::exec_log_i(ref context, 3);
}

/// 0xA4 - LOG4
/// Append log record with 4 topics.
/// # Specification: https://www.evm.codes/#a4?fork=shanghai
fn exec_log4(ref context: ExecutionContext) {
    internal::exec_log_i(ref context, 4);
}
