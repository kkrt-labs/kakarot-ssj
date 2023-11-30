//! Gas costs for EVM operations
//! Code is based on alloy project
//! Source: <https://github.com/bluealloy/revm/blob/main/crates/interpreter/src/gas/constants.rs>

pub const ZERO: u128 = 0;
pub const BASE: u128 = 2;
pub const VERYLOW: u128 = 3;
pub const LOW: u128 = 5;
pub const MID: u128 = 8;
pub const HIGH: u128 = 10;
pub const JUMPDEST: u128 = 1;
pub const SELFDESTRUCT: u128 = 5000;
pub const CREATE: u128 = 32000;
pub const CALLVALUE: u128 = 9000;
pub const NEWACCOUNT: u128 = 25000;
pub const EXP: u128 = 10;
pub const MEMORY: u128 = 3;
pub const LOG: u128 = 375;
pub const LOGDATA: u128 = 8;
pub const LOGTOPIC: u128 = 375;
pub const KECCAK256: u128 = 30;
pub const KECCAK256WORD: u128 = 6;
pub const COPY: u128 = 3;
pub const BLOCKHASH: u128 = 20;
pub const CODEDEPOSIT: u128 = 200;

pub const SSTORE_SET: u128 = 20000;
pub const SSTORE_RESET: u128 = 5000;
pub const REFUND_SSTORE_CLEARS: u128 = 15000;

pub const TRANSACTION_ZERO_DATA: u128 = 4;
pub const TRANSACTION_NON_ZERO_DATA_INIT: u128 = 16;
pub const TRANSACTION_NON_ZERO_DATA_FRONTIER: u128 = 68;

// Berlin EIP-2929 constants
pub const ACCESS_LIST_ADDRESS: u128 = 2400;
pub const ACCESS_LIST_STORAGE_KEY: u128 = 1900;
pub const COLD_SLOAD_COST: u128 = 2100;
pub const COLD_ACCOUNT_ACCESS_COST: u128 = 2600;
pub const WARM_STORAGE_READ_COST: u128 = 100;

/// EIP-3860 : Limit and meter initcode
pub const INITCODE_WORD_COST: u128 = 2;

pub const CALL_STIPEND: u128 = 2300;

pub fn max_message_call_gas(gas: u128) -> u128 {
    gas - (gas / 64)
}
