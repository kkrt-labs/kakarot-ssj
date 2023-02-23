//! Stop and Arithmetic Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// STOP operation.
/// Halts the execution of the current program.
/// # Additional informations:
/// - Since:  Frontier
/// - Group:
/// - Gas: 
/// - Stack consumed elements: 
/// - Stack produced elements: 
/// # Arguments
/// * `ctx_ptr` - the execution context
/// # TODO
/// - Implement me.
fn exec_stop(ref context: ExecutionContext) {
    context.stop();
}

/// 0x01 - ADD
/// Addition operation
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - The pointer to the execution context.
/// # TODO
/// - Implement me.
fn exec_add(ref context: ExecutionContext) {}

/// 0x02 - MUL operation.
/// Multiplication operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 5
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_mul(ref context: ExecutionContext) {}

/// 0x03 - SUB
/// Subtraction operation
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sub(ref context: ExecutionContext) {}

/// DIV operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 5
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_div(ref context: ExecutionContext) {}

/// SDIV operation.
/// Signed division operation
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 5
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sdiv(ref context: ExecutionContext) {}

/// MOD operation.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 5
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_mod(ref context: ExecutionContext) {}

/// SMOD operation.
/// Signed modulo operation
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 5
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_smod(ref context: ExecutionContext) {}

/// ADDMOD operation.
/// Addition modulo operation
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 8
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_addmod(ref context: ExecutionContext) {}

/// MULMOD operation.
/// Multiplication modulo operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 8
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_mulmod(ref context: ExecutionContext) {}

/// EXP operation.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 10
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_exp(ref context: ExecutionContext) {}

/// SIGNEXTEND - 0x0B
/// Exp operation
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stop and Arithmetic Operations
/// - Gas: 5
/// - Stack consumed elements: 2
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_signextend(ref context: ExecutionContext) {}
