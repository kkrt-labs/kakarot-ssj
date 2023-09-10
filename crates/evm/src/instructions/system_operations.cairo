//! System operations.

// Internal imports
use evm::context::ExecutionContext;
use evm::context::ExecutionContextTrait;

/// CREATE
/// # Specification: https://www.evm.codes/#f0?fork=shanghai
fn exec_create(ref context: ExecutionContext) {}


/// CREATE2
/// # Specification: https://www.evm.codes/#f5?fork=shanghai
fn exec_create2(ref context: ExecutionContext) {}

/// INVALID
/// # Specification: https://www.evm.codes/#fe?fork=shanghai
fn exec_invalid(ref context: ExecutionContext) {}

/// RETURN
/// # Specification: https://www.evm.codes/#f3?fork=shanghai
fn exec_return(ref context: ExecutionContext) {}

/// REVERT
/// # Specification: https://www.evm.codes/#fd?fork=shanghai
fn exec_revert(ref context: ExecutionContext) {}

/// CALL
/// # Specification: https://www.evm.codes/#f1?fork=shanghai
fn exec_call(ref context: ExecutionContext) {}

/// STATICCALL
/// # Specification: https://www.evm.codes/#fa?fork=shanghai
fn exec_staticcall(ref context: ExecutionContext) {}

/// CALLCODE
/// # Specification: https://www.evm.codes/#f2?fork=shanghai
fn exec_callcode(ref context: ExecutionContext) {}

/// DELEGATECALL
/// # Specification: https://www.evm.codes/#f4?fork=shanghai
fn exec_delegatecall(ref context: ExecutionContext) {}

/// SELFDESTRUCT
/// # Specification: https://www.evm.codes/#ff?fork=shanghai
fn exec_selfdestruct(ref context: ExecutionContext) {}
