use core::traits::TryInto;
use starknet::EthAddress;
//! Gas costs for EVM operations
//! Code is based on alloy project
//! Source: <https://github.com/bluealloy/revm/blob/main/crates/interpreter/src/gas/constants.rs>
use utils::helpers;

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
const TRANSACTION_BASE_COST: u128 = 21000;
const TRANSACTION_CREATE_COST: u128 = 32000;

// Berlin EIP-2929 constants
const ACCESS_LIST_ADDRESS: u128 = 2400;
const ACCESS_LIST_STORAGE_KEY: u128 = 1900;
const COLD_SLOAD_COST: u128 = 2100;
const COLD_ACCOUNT_ACCESS_COST: u128 = 2600;
const WARM_ACCESS_COST: u128 = 100;

/// EIP-3860 : Limit and meter initcode
const INITCODE_WORD_COST: u128 = 2;

const CALL_STIPEND: u128 = 2300;

fn max_message_call_gas(gas: u128) -> u128 {
    gas - (gas / 64)
}

/// Calculates the gas cost for allocating memory
/// to the smallest multiple of 32 bytes,
/// such that the allocated size is at least as big as the given size.
///
/// To optimize computations on u128 and avoid overflows, we compute size_in_words / 512
///  instead of size_in_words * size_in_words / 512. Then we recompute the
///  resulting quotient: x^2 = 512q + r becomes
///  x = 512 q0 + r0 => x^2 = 512(512 q0^2 + q0 r0) + r0^2
///  r0^2 = 512 q1 + r1
///  x^2 = 512(512 q0^2 + q0 r0 + q1) + r1
///  q = 512 * q0 * q0 + q0 * r0 + q1
/// # Parameters
///
/// * `size_in_bytes` - The size of the data in bytes.
///
/// # Returns
///
/// * `total_gas_cost` - The gas cost for storing data in memory.
fn calculate_memory_gas_cost(size_in_bytes: usize) -> u128 {
    let _512: NonZero<u128> = 512_u128.try_into().unwrap();
    let size_in_words = size_in_bytes / 32;
    let linear_cost = size_in_words.into() * MEMORY;

    let (q0, r0) = DivRem::div_rem(size_in_words.into(), _512);
    let (q1, r1) = DivRem::div_rem(r0 * r0, _512);
    let quadratic_cost = 512 * q0 * q0 + q0 * r0 + q1;

    linear_cost + quadratic_cost
}


fn memory_expansion_cost(memory_size: usize, max_offset: usize) -> u128 {
    let new_size = helpers::ceil32(memory_size + max_offset);
    if new_size <= memory_size {
        return 0;
    }
    let prev_cost = calculate_memory_gas_cost(memory_size);
    let new_cost = calculate_memory_gas_cost(new_size);
    new_cost - prev_cost
}


/// Calculates the gas to be charged for the init code in CREATE/CREATE2
/// opcodes as well as create transactions.
///
/// # Arguments
///
/// * `code_size` - The size of the init code
///
/// # Returns
///
/// * `init_code_gas` - The gas to be charged for the init code.
#[inline(always)]
fn init_code_cost(code_size: usize) -> u128 {
    let code_size_in_words = helpers::ceil32(code_size) / 32;
    code_size_in_words.into() * INITCODE_WORD_COST
}

/// Calculates the gas that is charged before execution is started.
///
/// The intrinsic cost of the transaction is charged before execution has
/// begun. Functions/operations in the EVM cost money to execute so this
/// intrinsic cost is for the operations that need to be paid for as part of
/// the transaction. Data transfer, for example, is part of this intrinsic
/// cost. It costs ether to send data over the wire and that ether is
/// accounted for in the intrinsic cost calculated in this function. This
/// intrinsic cost must be calculated and paid for before execution in order
/// for all operations to be implemented.
///
/// Reference:
/// https://github.com/ethereum/execution-specs/blob/master/src/ethereum/shanghai/fork.py#L689
fn calculate_intrinsic_gas_cost(target: Option<EthAddress>, mut calldata: Span<u8>) -> u128 {
    let mut data_cost: u128 = 0;
    // TODO(gas): access_list not handled yet
    let mut access_list_cost: u128 = 0;
    let calldata_len = calldata.len();

    loop {
        match calldata.pop_front() {
            Option::Some(data) => {
                data_cost +=
                    if *data == 0 {
                        TRANSACTION_ZERO_DATA
                    } else {
                        TRANSACTION_NON_ZERO_DATA_INIT
                    };
            },
            Option::None => { break; },
        }
    };

    let create_cost = if target.is_none() {
        TRANSACTION_CREATE_COST + init_code_cost(calldata_len)
    } else {
        0
    };

    TRANSACTION_BASE_COST + data_cost + create_cost + access_list_cost
}
