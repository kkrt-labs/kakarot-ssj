//! Logging Operations.

// Internal imports
use evm::machine::Machine;

mod internal {
    use evm::machine::Machine;

    /// Generic logging operation.
    /// Append log record with n topics.
    fn exec_log_i(ref machine: Machine, topics_len: u8) {}
}

/// 0xA0 - LOG0 operation
/// Append log record with no topic.
/// # Specification: https://www.evm.codes/#a0?fork=shanghai
fn exec_log0(ref machine: Machine) {
    internal::exec_log_i(ref machine, 0);
}


/// 0xA1 - LOG1
/// Append log record with one topic.
/// # Specification: https://www.evm.codes/#a1?fork=shanghai
fn exec_log1(ref machine: Machine) {
    internal::exec_log_i(ref machine, 1);
}

/// 0xA2 - LOG2
/// Append log record with two topics.
/// # Specification: https://www.evm.codes/#a2?fork=shanghai
fn exec_log2(ref machine: Machine) {
    internal::exec_log_i(ref machine, 2);
}

/// 0xA3 - LOG3
/// Append log record with three topics.
/// # Specification: https://www.evm.codes/#a3?fork=shanghai
fn exec_log3(ref machine: Machine) {
    internal::exec_log_i(ref machine, 3);
}

/// 0xA4 - LOG4
/// Append log record with 4 topics.
/// # Specification: https://www.evm.codes/#a4?fork=shanghai
fn exec_log4(ref machine: Machine) {
    internal::exec_log_i(ref machine, 4);
}
