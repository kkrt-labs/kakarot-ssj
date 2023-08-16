//! Block Information.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// 0x40 - BLOCKHASH 
/// Get the hash of one of the 256 most recent complete blocks.
/// # Specification: https://www.evm.codes/#40?fork=shanghai
fn exec_blockhash(ref context: ExecutionContext) {}

/// 0x41 - COINBASE 
/// Get the block's beneficiary address.
/// # Specification: https://www.evm.codes/#41?fork=shanghai
fn exec_coinbase(ref context: ExecutionContext) {}

/// 0x42 - TIMESTAMP 
/// Get the block’s timestamp
/// # Specification: https://www.evm.codes/#42?fork=shanghai
fn exec_timestamp(ref context: ExecutionContext) {}

/// 0x43 - NUMBER 
/// Get the block number.
/// # Specification: https://www.evm.codes/#43?fork=shanghai
fn exec_number(ref context: ExecutionContext) {}

/// 0x44 - PREVRANDAO 
/// # Specification: https://www.evm.codes/#44?fork=shanghai
fn exec_prevrandao(ref context: ExecutionContext) {}

/// 0x45 - GASLIMIT 
/// Get gas limit
/// # Specification: https://www.evm.codes/#45?fork=shanghai
fn exec_gaslimit(ref context: ExecutionContext) {}

/// 0x46 - CHAINID 
/// Get the chain ID.
/// # Specification: https://www.evm.codes/#46?fork=shanghai
fn exec_chainid(ref context: ExecutionContext) {}

/// 0x47 - SELFBALANCE 
/// Get balance of currently executing contract
/// # Specification: https://www.evm.codes/#47?fork=shanghai
fn exec_selfbalance(ref context: ExecutionContext) {}

/// 0x48 - BASEFEE 
/// Get base fee.
/// # Specification: https://www.evm.codes/#48?fork=shanghai
fn exec_basefee(ref context: ExecutionContext) {}
