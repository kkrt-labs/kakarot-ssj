//! Duplication Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;


mod internal {
    use kakarot::context::ExecutionContext;
    use kakarot::context::ExecutionContextTrait;
    use kakarot::stack::StackTrait;
    use traits::Into;

    /// Generic DUP operation
    fn exec_dup_i(ref context: ExecutionContext, i: u8) {
        if i == 0 {
            panic_with_felt252('Shouldnt be call with 0');
        }

        let item = context.stack.peek_at((i - 1).into());
        context.stack.push(item);
    }
}

/// 0x80 - DUP1 operation
fn exec_dup1(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 1);
}

/// 0x81 - DUP2 operation
fn exec_dup2(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 2);
}

/// 0x82 - DUP3 operation
fn exec_dup3(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 3);
}


/// 0x83 - DUP2 operation
fn exec_dup4(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 4);
}


/// 0x84 - DUP5 operation
fn exec_dup5(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 5);
}


/// 0x85 - DUP6 operation
fn exec_dup6(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 6);
}


/// 0x86 - DUP7 operation
fn exec_dup7(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 7);
}


/// 0x87 - DUP8 operation
fn exec_dup8(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 8);
}

/// 0x88 - DUP9 operation
fn exec_dup9(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 9);
}


/// 0x89 - DUP10 operation
fn exec_dup10(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 10);
}

/// 0x8A - DUP11 operation
fn exec_dup11(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 11);
}

/// 0x8B - DUP12 operation
fn exec_dup12(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 12);
}

/// 0x8C - DUP13 operation
fn exec_dup13(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 13);
}

/// 0x8D - DUP14 operation
fn exec_dup14(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 14);
}

/// 0x8E - DUP15 operation
fn exec_dup15(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 15);
}
/// 0x8F - DUP16 operation
fn exec_dup16(ref context: ExecutionContext) {
    internal::exec_dup_i(ref context, 16);
}
