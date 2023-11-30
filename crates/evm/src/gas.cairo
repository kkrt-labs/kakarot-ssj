//! Gas costs for EVM operations
//! Code is based on alloy project
//! Source: <https://github.com/bluealloy/revm/blob/main/crates/interpreter/src/gas/constants.rs>

const ZERO: u128 = 0;
const BASE: u128 = 2;
const VERYLOW: u128 = 3;
const LOW: u128 = 5;
const MID: u128 = 8;
const HIGH: u128 = 10;
const JUMPDEST: u128 = 1;
const SELFDESTRUCT: u128 = 5000;
const CREATE: u128 = 32000;
const CALLVALUE: u128 = 9000;
const NEWACCOUNT: u128 = 25000;
const EXP: u128 = 10;
const MEMORY: u128 = 3;
const LOG: u128 = 375;
const LOGDATA: u128 = 8;
const LOGTOPIC: u128 = 375;
const KECCAK256: u128 = 30;
const KECCAK256WORD: u128 = 6;
const COPY: u128 = 3;
const BLOCKHASH: u128 = 20;
const CODEDEPOSIT: u128 = 200;

const SSTORE_SET: u128 = 20000;
const SSTORE_RESET: u128 = 5000;
const REFUND_SSTORE_CLEARS: u128 = 15000;

const TRANSACTION_ZERO_DATA: u128 = 4;
const TRANSACTION_NON_ZERO_DATA_INIT: u128 = 16;
const TRANSACTION_NON_ZERO_DATA_FRONTIER: u128 = 68;

// Berlin EIP-2929 constants
const ACCESS_LIST_ADDRESS: u128 = 2400;
const ACCESS_LIST_STORAGE_KEY: u128 = 1900;
const COLD_SLOAD_COST: u128 = 2100;
const COLD_ACCOUNT_ACCESS_COST: u128 = 2600;
const WARM_STORAGE_READ_COST: u128 = 100;

/// EIP-3860 : Limit and meter initcode
const INITCODE_WORD_COST: u128 = 2;

const CALL_STIPEND: u128 = 2300;

fn max_message_call_gas(gas: u128) -> u128 {
    gas - (gas / 64)
}
