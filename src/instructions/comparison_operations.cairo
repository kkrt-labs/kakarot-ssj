//! Comparison & Bitwise Logic Operations

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// LT operation
/// Comparison operation
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_lt(ref context: ExecutionContext) {}

/// GT operation.
/// Comparison operation.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_gt(ref context: ExecutionContext) {}


/// SLT operation.
/// Comparison operation.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context 
/// # TODO
/// - Implement me.
fn exec_slt(ref context: ExecutionContext) {}

/// SGT operation.
/// Comparison operation.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sgt(ref context: ExecutionContext) {}


/// EQ operation.
/// Comparison operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_eq(ref context: ExecutionContext) {}

/// ISZERO operation.
/// Comparison operation
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_iszero(ref context: ExecutionContext) {}

/// 0x16 - AND
/// Comparison operation
/// # Additional informations:
/// - Since: Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_and(ref context: ExecutionContext) {}

/// OR operation.
/// Comparison operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_or(ref context: ExecutionContext) {}

/// XOR operation
/// Comparison operation
/// # Additional informations:
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_xor(ref context: ExecutionContext) {}

/// BYTE operation.
/// Bitwise operation.
/// # Additional informations: 
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_byte(ref context: ExecutionContext) {}

/// SHL operation.
/// Bitwise operation.
/// # Additional informations:
/// - Since:  Constantinople
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_shl(ref context: ExecutionContext) {}

/// SHR operation.
/// Bitwise operation.
/// # Additional informations:
/// - Since:  Constantinople
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_shr(ref context: ExecutionContext) {}

/// SAR operation.
/// Bitwise operation
/// # Additional informations:
/// - Since:  Constantinople
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sar(ref context: ExecutionContext) {}

/// NOT operation.
/// Bitwise operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Comparison & Bitwise Logic Operations
/// - Gas: 3
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_not(ref context: ExecutionContext) {}
