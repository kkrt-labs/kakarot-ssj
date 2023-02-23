//! Duplication Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

///Generic DUP operation
/// Duplicate the top i-th stack item to the top of the stack.
/// # Arguments
/// * `ctx` - the execution context
/// * `i` - the i-th stack item to duplicate
/// # TODO
/// - Implement me.
fn exec_dup_i(ref context: ExecutionContext, i: u8) {}

/// DUP1 operation
/// Duplicate the top stack item to the top of the stack.
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup1(ref context: ExecutionContext) {
    exec_dup_i(ref context, 1_u8);
}

/// DUP2 operation
/// Duplicate the top 2nd stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup2(ref context: ExecutionContext) {
    exec_dup_i(ref context, 2_u8);
}

/// DUP3 operation
/// Duplicate the top 3nd stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup3(ref context: ExecutionContext) {
    exec_dup_i(ref context, 3_u8);
}


/// DUP2 operation
/// Duplicate the top 4nd stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup4(ref context: ExecutionContext) {
    exec_dup_i(ref context, 4_u8);
}


/// DUP5 operation
/// Duplicate the top 5th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup5(ref context: ExecutionContext) {
    exec_dup_i(ref context, 5_u8);
}


/// DUP6 operation
/// Duplicate the top 6th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup6(ref context: ExecutionContext) {
    exec_dup_i(ref context, 6_u8);
}


/// DUP7 operation
/// Duplicate the top 7th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup7(ref context: ExecutionContext) {
    exec_dup_i(ref context, 7_u8);
}


/// DUP8 operation
/// Duplicate the top 8th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 9
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup8(ref context: ExecutionContext) {
    exec_dup_i(ref context, 8_u8);
}

/// DUP9 operation
/// Duplicate the top 9th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup9(ref context: ExecutionContext) {
    exec_dup_i(ref context, 9_u8);
}


/// DUP10 operation
/// Duplicate the top 10th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup10(ref context: ExecutionContext) {
    exec_dup_i(ref context, 10_u8);
}

/// DUP11 operation
/// Duplicate the top 11th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup11(ref context: ExecutionContext) {
    exec_dup_i(ref context, 11_u8);
}

/// DUP12 operation
/// Duplicate the top 12th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup12(ref context: ExecutionContext) {
    exec_dup_i(ref context, 12_u8);
}

/// DUP13 operation
/// Duplicate the top 13th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup13(ref context: ExecutionContext) {
    exec_dup_i(ref context, 13_u8);
}

/// DUP14 operation
/// Duplicate the top 14th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup14(ref context: ExecutionContext) {
    exec_dup_i(ref context, 14_u8);
}

/// DUP15 operation
/// Duplicate the top 15th stack item to the top of the stack.\
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup15(ref context: ExecutionContext) {
    exec_dup_i(ref context, 15_u8);
}
/// DUP16 operation
/// Duplicate the top 16th stack item to the top of the stack.
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_dup16(ref context: ExecutionContext) {
    exec_dup_i(ref context, 16_u8);
}
