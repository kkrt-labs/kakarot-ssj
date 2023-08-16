//! Environmental Information.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// 0x30 - ADDRESS 
/// Get address of currently executing account.
/// # Specification: https://www.evm.codes/#30?fork=shanghai
fn exec_address(ref context: ExecutionContext) {}

/// 0x31 - BALANCE opcode.
/// Get ETH balance of the specified address.
/// # Specification: https://www.evm.codes/#31?fork=shanghai
fn exec_balance(ref context: ExecutionContext) {}

/// 0x32 - ORIGIN 
/// Get execution origination address.
/// # Specification: https://www.evm.codes/#32?fork=shanghai
fn exec_origin(ref context: ExecutionContext) {}

/// 0x33 - CALLER 
/// Get caller address.
/// # Specification: https://www.evm.codes/#33?fork=shanghai
fn exec_caller(ref context: ExecutionContext) {}

/// 0x34 - CALLVALUE 
/// Get deposited value by the instruction/transaction responsible for this execution.
/// # Specification: https://www.evm.codes/#34?fork=shanghai
fn exec_callvalue(ref context: ExecutionContext) {}

/// 0x35 - CALLDATALOAD 
/// Push a word from the calldata onto the stack.
/// # Specification: https://www.evm.codes/#35?fork=shanghai
fn exec_calldataload(ref context: ExecutionContext) {}

/// 0x36 - CALLDATASIZE 
/// Get the size of return data.
/// # Specification: https://www.evm.codes/#36?fork=shanghai
fn exec_calldatasize(ref context: ExecutionContext) {}

/// 0x37 - CALLDATACOPY operation
/// Save word to memory.
/// # Specification: https://www.evm.codes/#37?fork=shanghai
fn exec_calldatacopy(ref context: ExecutionContext) {}

/// 0x38 - CODESIZE 
/// Get size of bytecode running in current environment.
/// # Specification: https://www.evm.codes/#38?fork=shanghai
fn exec_codesize(ref context: ExecutionContext) {}

/// 0x39 - CODECOPY 
/// Copies slice of bytecode to memory.
/// # Specification: https://www.evm.codes/#39?fork=shanghai
fn exec_codecopy(ref context: ExecutionContext) {}

/// 0x3A - GASPRICE 
/// Get price of gas in current environment.
/// # Specification: https://www.evm.codes/#3a?fork=shanghai
fn exec_gasprice(ref context: ExecutionContext) {}

/// 0x3B - EXTCODESIZE 
/// Get size of an account's code.
/// # Specification: https://www.evm.codes/#3b?fork=shanghai
fn exec_extcodesize(ref context: ExecutionContext) {}

/// 0x3C - EXTCODECOPY 
/// Copy an account's code to memory
/// # Specification: https://www.evm.codes/#3c?fork=shanghai
fn exec_extcodecopy(ref context: ExecutionContext) {}

/// 0x3D - RETURNDATASIZE 
/// Get the size of return data.
/// # Specification: https://www.evm.codes/#3d?fork=shanghai
fn exec_returndatasize(ref context: ExecutionContext) {}

/// 0x3E - RETURNDATACOPY 
/// Save word to memory.
/// # Specification: https://www.evm.codes/#3e?fork=shanghai
fn exec_returndatacopy(ref context: ExecutionContext) {}

/// 0x3F - EXTCODEHASH 
/// Get hash of a contract's code.
/// # Specification: https://www.evm.codes/#3f?fork=shanghai
fn exec_extcodehash(ref context: ExecutionContext) {}
