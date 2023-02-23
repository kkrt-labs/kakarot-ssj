//! Block Information.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

/// BLOCKHASH operation.
/// Get the hash of one of the 256 most recent complete blocks.
/// if the block number is not in the valid range.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Block Information
/// - Gas: 20
/// - Stack consumed elements: 1
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_blockhash(ref context: ExecutionContext) {}

/// COINBASE operation.
/// Get the block's beneficiary address.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_coinbase(ref context: ExecutionContext) {}

/// TIMESTAMP operation.
/// Get the block’s timestamp
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_timestamp(ref context: ExecutionContext) {}

/// NUMBER operation.
/// Get the block number.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_number(ref context: ExecutionContext) {}

/// DIFFICULTY operation.
/// Get Difficulty.
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_difficulty(ref context: ExecutionContext) {}

/// GASLIMIT operation.
/// Get gas limit
/// # Additional informations:
/// - Since:  Frontier
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_gaslimit(ref context: ExecutionContext) {}

/// CHAINID operation.
/// Get the chain ID.
/// # Additional informations:
/// - Since:  Instanbul
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_chainid(ref context: ExecutionContext) {}

/// SELFBALANCE operation.
/// Get balance of currently executing contract
/// # Additional informations:
/// - Since: Istanbul
/// - Group: Block Information
/// - Gas: 5
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_selfbalance(ref context: ExecutionContext) {}

/// BASEFEE operation.
/// Get base fee.
/// # Additional informations:
/// - Since: Frontier
/// - Group: Block Information
/// - Gas: 2
/// - Stack consumed elements: 0
/// - Stack produced elements: 1
/// # Arguments
/// * `ctx` - the execution context
/// # TODO
/// - Implement me.
fn exec_basefee(ref context: ExecutionContext) {}
