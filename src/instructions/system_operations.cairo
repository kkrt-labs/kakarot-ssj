//! System operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// CREATE operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 3
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_create(ref context: ExecutionContext) {}


/// CREATE2 operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 4
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_create2(ref context: ExecutionContext) {}

/// INVALID operation.
/// Designated invalid instruction.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: System Operations
/// - Gas: NaN
/// - Stack consumed elements: 0
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_invalid(ref context: ExecutionContext) {}

/// RETURN operation.
/// Designated invalid instruction.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: System Operations
/// - Gas: NaN
/// - Stack consumed elements: 2
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_return(ref context: ExecutionContext) {}

/// REVERT operation.
/// # Additional informations:
/// - Since:  Byzantium
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 2
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_revert(ref context: ExecutionContext) {}


/// CALL operation.
/// # Additional informations:
/// - Since: Frontier
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 7
/// - Stack produced elements: 1
/// # TODO
/// - Implement me.
fn exec_call(ref context: ExecutionContext) {}


/// STATICCALL operation.
/// # Additional informations:
/// - Since: Homestead
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 6
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_staticcall(ref context: ExecutionContext) {}


/// CALLCODE operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 7
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_callcode(ref context: ExecutionContext) {}

/// DELEGATECALL operation.
/// # Additional informations:
/// - Since:  Byzantium
/// - Group: System Operations
/// - Gas: 0 + dynamic gas
/// - Stack consumed elements: 6
/// - Stack produced elements: 1
/// # TODO
/// - Implement me.
fn exec_delegatecall(ref context: ExecutionContext) {}

/// SELFDESTRUCT operation.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: System Operations
/// - Gas: 3000 + dynamic gas
/// - Stack consumed elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_selfdestruct(ref context: ExecutionContext) {}
