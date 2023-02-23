//! Environmental Information.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// ADDRESS operation.
/// Get address of currently executing account.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_address(ref context: ExecutionContext) {}

/// BALANCE opcode.
/// Get ETH balance of the specified address.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 100 || 2600
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_balance(ref context: ExecutionContext) {}

/// ORIGIN operation.
/// Get execution origination address.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_origin(ref context: ExecutionContext) {}

/// CALLER operation.
/// Get caller address.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_caller(ref context: ExecutionContext) {}

/// CALLVALUE operation.
/// Get deposited value by the instruction/transaction responsible for this execution.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_callvalue(ref context: ExecutionContext) {}

/// CALLDATALOAD operation.
/// Push a word from the calldata onto the stack.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 3
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_calldataload(ref context: ExecutionContext) {}

/// CALLDATASIZE operation.
/// Get the size of return data.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_calldatasize(ref context: ExecutionContext) {}

/// CALLDATACOPY operation
/// Save word to memory.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Gas: 3
/// - Stack consumed elements: 3
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_calldatacopy(ref context: ExecutionContext) {}

/// CODESIZE operation.
/// Get size of bytecode running in current environment.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 3
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_codesize(ref context: ExecutionContext) {}

/// CODECOPY (0x39) operation.
/// Copies slice of bytecode to memory.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 3
/// - Stack consumed elements: 3
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_codecopy(ref context: ExecutionContext) {}

/// GASPRICE operation.
/// Get price of gas in current environment.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_gasprice(ref context: ExecutionContext) {}

/// EXTCODESIZE operation.
/// Get size of an account's code.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Environmental Information
/// - Gas: 100 || 2600
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_extcodesize(ref context: ExecutionContext) {}

/// EXTCODECOPY operation
/// Copy an account's code to memory
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 100 || 2600
/// - Stack consumed elements: 4
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_extcodecopy(ref context: ExecutionContext) {}

/// RETURNDATASIZE operation.
/// Get the size of return data.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_returndatasize(ref context: ExecutionContext) {}

/// RETURNDATACOPY operation.
/// Save word to memory.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Stack Memory Storage and Flow operations.
/// - Gas: 3
/// - Stack consumed elements: 3
/// - Stack produced elements: 0
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_returndatacopy(ref context: ExecutionContext) {}

/// EXTCODEHASH operation.
/// Get hash of a contract's code.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Environmental Information
/// - Gas: 100 || 2600
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_extcodehash(ref context: ExecutionContext) {}
