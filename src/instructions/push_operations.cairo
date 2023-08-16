//! Push Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

mod internal {
    use kakarot::context::ExecutionContext;
    use kakarot::context::ExecutionContextTrait;

    /// Place i bytes items on stack.
    fn exec_push_i(ref context: ExecutionContext, i: u8) {}
}


/// 0x60 - PUSH1 operation
/// # Specification: https://www.evm.codes/#60?fork=shanghai
fn exec_push1(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 1);
}


/// 0x61 - PUSH2 operation
/// # Specification: https://www.evm.codes/#61?fork=shanghai
fn exec_push2(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 2);
}


/// 0x62 - PUSH3 operation
/// # Specification: https://www.evm.codes/#62?fork=shanghai
fn exec_push3(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 3);
}

/// 0x63 - PUSH4 operation
/// # Specification: https://www.evm.codes/#63?fork=shanghai
fn exec_push4(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 4);
}

/// 0x64 - PUSH5 operation
/// # Specification: https://www.evm.codes/#64?fork=shanghai
fn exec_push5(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 5);
}

/// 0x65 - PUSH6 operation
/// # Specification: https://www.evm.codes/#65?fork=shanghai
fn exec_push6(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 6);
}

/// 0x66 - PUSH7 operation
/// # Specification: https://www.evm.codes/#66?fork=shanghai
fn exec_push7(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 7);
}

/// 0x67 - PUSH8 operation
/// # Specification: https://www.evm.codes/#67?fork=shanghai
fn exec_push8(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 8);
}


/// 0x68 - PUSH9 operation
/// # Specification: https://www.evm.codes/#68?fork=shanghai
fn exec_push9(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 9);
}

/// 0x69 - PUSH10 operation
/// # Specification: https://www.evm.codes/#69?fork=shanghai
fn exec_push10(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 10);
}

/// 0x6A - PUSH11 operation
/// # Specification: https://www.evm.codes/#6a?fork=shanghai
fn exec_push11(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 11);
}

/// 0x6B - PUSH12 operation
/// # Specification: https://www.evm.codes/#6b?fork=shanghai
fn exec_push12(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 12);
}


/// 0x6C - PUSH13 operation
/// # Specification: https://www.evm.codes/#6c?fork=shanghai
fn exec_push13(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 13);
}

/// 0x6D - PUSH14 operation
/// # Specification: https://www.evm.codes/#6d?fork=shanghai
fn exec_push14(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 14);
}


/// 0x6E - PUSH15 operation
/// # Specification: https://www.evm.codes/#6e?fork=shanghai
fn exec_push15(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 15);
}

/// 0x6F - PUSH16 operation
/// # Specification: https://www.evm.codes/#6f?fork=shanghai
fn exec_push16(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 16);
}

/// 0x70 - PUSH17 operation
/// # Specification: https://www.evm.codes/#70?fork=shanghai
fn exec_push17(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 17);
}

/// 0x71 - PUSH18 operation
/// # Specification: https://www.evm.codes/#71?fork=shanghai
fn exec_push18(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 18);
}


/// 0x72 - PUSH19 operation
/// # Specification: https://www.evm.codes/#72?fork=shanghai
fn exec_push19(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 19);
}

/// 0x73 - PUSH20 operation
/// # Specification: https://www.evm.codes/#73?fork=shanghai
fn exec_push20(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 20);
}


/// 0x74 - PUSH21 operation
/// # Specification: https://www.evm.codes/#74?fork=shanghai
fn exec_push21(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 21);
}


/// 0x75 - PUSH22 operation
/// # Specification: https://www.evm.codes/#75?fork=shanghai
fn exec_push22(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 22);
}


/// 0x76 - PUSH23 operation
/// # Specification: https://www.evm.codes/#76?fork=shanghai
fn exec_push23(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 23);
}


/// 0x77 - PUSH24 operation
/// # Specification: https://www.evm.codes/#77?fork=shanghai
fn exec_push24(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 24);
}


/// 0x78 - PUSH21 operation
/// # Specification: https://www.evm.codes/#78?fork=shanghai
fn exec_push25(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 25);
}


/// 0x79 - PUSH26 operation
/// # Specification: https://www.evm.codes/#79?fork=shanghai
fn exec_push26(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 26);
}


/// 0x7A - PUSH27 operation
/// # Specification: https://www.evm.codes/#7a?fork=shanghai
fn exec_push27(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 27);
}

/// 0x7B - PUSH28 operation
/// # Specification: https://www.evm.codes/#7b?fork=shanghai
fn exec_push28(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 28);
}


/// 0x7C - PUSH29 operation
/// # Specification: https://www.evm.codes/#7c?fork=shanghai
fn exec_push29(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 29);
}


/// 0x7D - PUSH30 operation
/// # Specification: https://www.evm.codes/#7d?fork=shanghai
fn exec_push30(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 31);
}


/// 0x7E - PUSH31 operation
/// # Specification: https://www.evm.codes/#7e?fork=shanghai
fn exec_push31(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 31);
}


/// 0x7F - PUSH32 operation
/// # Specification: https://www.evm.codes/#7f?fork=shanghai
fn exec_push32(ref context: ExecutionContext) {
    internal::exec_push_i(ref context, 32);
}
