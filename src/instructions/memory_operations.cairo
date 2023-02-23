//! Stack Memory Storage and Flow Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// MLOAD operation.
/// Load word from memory and push to stack.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory and Flow operations.
/// - Gas: 3 + dynamic gas
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_mload(ref context: ExecutionContext) {}

/// MSTORE operation.
/// Save word to memory.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Gas: 3 + dynamic gas
/// - Stack consumed elements: 2
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_mstore(ref context: ExecutionContext) {}

/// PC operation
/// Get the value of the program counter prior to the increment.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_pc(ref context: ExecutionContext) {}

/// MSIZE operation.
/// Get the value of memory size.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_msize(ref context: ExecutionContext) {}

/// JUMP operation
/// The JUMP instruction changes the pc counter. The new pc target has to be a JUMPDEST opcode.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory and Flow operations.
/// - Gas: 8
/// - Stack consumed elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_jump(ref context: ExecutionContext) {}

/// JUMPI operation.
/// Change the pc counter under a provided certain condition.
/// The new pc target has to be a JUMPDEST opcode.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stack Memory and Flow operations.
/// - Gas: 10
/// - Stack consumed elements: 2
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_jumpi(ref context: ExecutionContext) {}

/// JUMPDEST operation
/// Serves as a check that JUMP or JUMPI was executed correctly. We only update gas used.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_jumpdest(ref context: ExecutionContext) {}

/// POP operation.
/// Pops the first item on the stack (top of the stack).
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Stack consumed elements: 1
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_pop(ref context: ExecutionContext) {}

/// MSTORE8 operation.
/// Save single byte to memory
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_mstore8(ref context: ExecutionContext) {}

/// SSTORE operation
/// Save word to storage.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Gas: 3
/// - Stack consumed elements: 2
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sstore(ref context: ExecutionContext) {}

/// SLOAD operation
/// Load from storage.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Gas: 3
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_sload(ref context: ExecutionContext) {}

/// GAS operation
/// Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_gas(ref context: ExecutionContext) {}
