use starknet::EthAddress;
use utils::set::{Set};
use utils::traits::{U8IntoEthAddress};
// FELT PRIME
// 2^251 + 17 * 2^192 + 1
const FELT252_PRIME: u256 = 0x800000000000011000000000000000000000000000000000000000000000001;

// Prefix used to compute the address of a Starknet contract being deployed.
// <https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/core/os/contract_address/contract_address.cairo>
const CONTRACT_ADDRESS_PREFIX: felt252 = 'STARKNET_CONTRACT_ADDRESS';


// BLOCK
//TODO(gas): determine correct block gas limit
const BLOCK_GAS_LIMIT: u128 = 30_000_000;
// CHAIN_ID = KKRT (0x4b4b5254) in ASCII
const CHAIN_ID: u256 = 1263227476;

// STACK
const STACK_MAX_DEPTH: usize = 1024;

// CODE
const MAX_CODE_SIZE: usize = 0x6000;
const MAX_INITCODE_SIZE: usize = consteval_int!(0x6000 * 2);

// KECCAK
// The empty keccak256 hash, Solidity equivalent:
// contract EmptyHash {
//     function emptyHash() public pure returns(bytes32) {
//         return keccak256("");
//     }
// }
// Reproducing link:
// <https://emn178.github.io/online-tools/keccak_256.html?input=&input_type=hex>
const EMPTY_KECCAK: u256 = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

//PRECOMPILES
fn precompile_addresses() -> Set<EthAddress> {
    let inner: Array<EthAddress> = array![
        0x01_u8.into(),
        0x02_u8.into(),
        0x03_u8.into(),
        0x04_u8.into(),
        0x05_u8.into(),
        0x06_u8.into(),
        0x07_u8.into(),
        0x08_u8.into(),
        0x09_u8.into()
    ];
    Set { inner }
}

// Numeric constants
const POW_256_0: u128 = 0x1;
const POW_256_1: u128 = 0x100;
const POW_256_2: u128 = 0x10000;
const POW_256_3: u128 = 0x1000000;
const POW_256_4: u128 = 0x100000000;
const POW_256_5: u128 = 0x10000000000;
const POW_256_6: u128 = 0x1000000000000;
const POW_256_7: u128 = 0x100000000000000;
const POW_256_8: u128 = 0x10000000000000000;
const POW_256_9: u128 = 0x1000000000000000000;
const POW_256_10: u128 = 0x100000000000000000000;
const POW_256_11: u128 = 0x10000000000000000000000;
const POW_256_12: u128 = 0x1000000000000000000000000;
const POW_256_13: u128 = 0x100000000000000000000000000;
const POW_256_14: u128 = 0x10000000000000000000000000000;
const POW_256_15: u128 = 0x1000000000000000000000000000000;
const POW_256_16: u256 = 0x100000000000000000000000000000000;

const POW_2_0: u128 = 0x1;
const POW_2_8: u128 = 0x100;
const POW_2_16: u128 = 0x10000;
const POW_2_24: u128 = 0x1000000;
const POW_2_32: u128 = 0x100000000;
const POW_2_40: u128 = 0x10000000000;
const POW_2_48: u128 = 0x1000000000000;
const POW_2_56: u128 = 0x100000000000000;
const POW_2_64: u128 = 0x10000000000000000;
const POW_2_72: u128 = 0x1000000000000000000;
const POW_2_80: u128 = 0x100000000000000000000;
const POW_2_88: u128 = 0x10000000000000000000000;
const POW_2_96: u128 = 0x1000000000000000000000000;
const POW_2_104: u128 = 0x100000000000000000000000000;
const POW_2_112: u128 = 0x10000000000000000000000000000;
const POW_2_120: u128 = 0x1000000000000000000000000000000;
const POW_2_127: u128 = 0x80000000000000000000000000000000;

const MAX_ADDRESS: u256 = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

// EVM GAS
const GAS_INIT_CODE_WORD_COST: usize = 2;

// TRANSACTION GAS COSTS
const TX_BASE_COST: u128 = 21000;
const TX_CREATE_COST: u128 = 32000;
const TX_DATA_COST_PER_ZERO: u128 = 4;
const TX_DATA_COST_PER_NON_ZERO: u128 = 16;
