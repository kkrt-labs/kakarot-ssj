//! Exchange Operations.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait};

mod internal {
    use evm::context::{ExecutionContext, ExecutionContextTrait};

    /// Generic SWAP operation
    /// Exchange 1st and i-th stack items
    fn exec_swap_i(ref context: ExecutionContext, i: u8) {}
}


/// 0x90 - SWAP1 operation
/// Exchange 1st and 2nd stack items.
/// # Specification: https://www.evm.codes/#90?fork=shanghai
fn exec_swap1(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 1);
}

/// 0x91 - SWAP2 operation
/// Exchange 1st and 3rd stack items.
/// # Specification: https://www.evm.codes/#91?fork=shanghai
fn exec_swap2(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 2);
}

/// 0x92 - SWAP3 operation
/// Exchange 1st and 4th stack items.
/// # Specification: https://www.evm.codes/#92?fork=shanghai
fn exec_swap3(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 3);
}

/// 0x93 - SWAP4 operation
/// Exchange 1st and 5th stack items.
/// # Specification: https://www.evm.codes/#93?fork=shanghai
fn exec_swap4(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 4);
}

/// 0x94 - SWAP5 operation
/// Exchange 1st and 6th stack items.
/// # Specification: https://www.evm.codes/#94?fork=shanghai
fn exec_swap5(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 5);
}

/// 0x95 - SWAP6 operation
/// Exchange 1st and 7th stack items.
/// # Specification: https://www.evm.codes/#95?fork=shanghai
fn exec_swap6(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 6);
}

/// 0x96 - SWAP7 operation
/// Exchange 1st and 8th stack items.
/// # Specification: https://www.evm.codes/#96?fork=shanghai
fn exec_swap7(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 7);
}

/// 0x97 - SWAP8 operation
/// Exchange 1st and 9th stack items.
/// # Specification: https://www.evm.codes/#97?fork=shanghai
fn exec_swap8(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 8);
}

/// 0x98 - SWAP9 operation
/// Exchange 1st and 10th stack items.
/// # Specification: https://www.evm.codes/#98?fork=shanghai
fn exec_swap9(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 9);
}

/// 0x99 - SWAP10 operation
/// Exchange 1st and 11th stack items.
/// # Specification: https://www.evm.codes/#99?fork=shanghai
fn exec_swap10(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 10);
}

/// 0x9A - SWAP11 operation
/// Exchange 1st and 12th stack items.
/// # Specification: https://www.evm.codes/#9a?fork=shanghai
fn exec_swap11(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 11);
}

/// 0x9B - SWAP12 operation
/// Exchange 1st and 13th stack items.
/// # Specification: https://www.evm.codes/#9b?fork=shanghai
fn exec_swap12(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 12);
}

/// 0x9C - SWAP13 operation
/// Exchange 1st and 14th stack items.
/// # Specification: https://www.evm.codes/#9c?fork=shanghai
fn exec_swap13(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 13);
}

/// 0x9D - SWAP14 operation
/// Exchange 1st and 15th stack items.
/// # Specification: https://www.evm.codes/#9d?fork=shanghai
fn exec_swap14(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 14);
}

/// 0x9E - SWAP15 operation
/// Exchange 1st and 16th stack items.
/// # Specification: https://www.evm.codes/#9e?fork=shanghai
fn exec_swap15(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 15);
}

/// 0x9F - SWAP16 operation
/// Exchange 1st and 16th stack items.
/// # Specification: https://www.evm.codes/#9f?fork=shanghai
fn exec_swap16(ref context: ExecutionContext) {
    internal::exec_swap_i(ref context, 16);
}
