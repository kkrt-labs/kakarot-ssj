use core::starknet::EthAddress;
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
const CHAIN_ID: u128 = 1263227476;

// STACK
const STACK_MAX_DEPTH: usize = 1024;

// CODE
const MAX_CODE_SIZE: usize = 0x6000;
const MAX_INITCODE_SIZE: usize = 0x6000 * 2;

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

const BURN_ADDRESS: felt252 = 0xdead;

//PRECOMPILES
pub fn precompile_addresses() -> Set<EthAddress> {
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

pub const POW_256_REV: [
    u256
    ; 17] = [
    pow!(256, 16),
    pow!(256, 15),
    pow!(256, 14),
    pow!(256, 13),
    pow!(256, 12),
    pow!(256, 11),
    pow!(256, 10),
    pow!(256, 9),
    pow!(256, 8),
    pow!(256, 7),
    pow!(256, 6),
    pow!(256, 5),
    pow!(256, 4),
    pow!(256, 3),
    pow!(256, 2),
    pow!(256, 1),
    pow!(256, 0)
];

pub const POW_2: [
    u128
    ; 128] = [
    pow!(2, 0),
    pow!(2, 1),
    pow!(2, 2),
    pow!(2, 3),
    pow!(2, 4),
    pow!(2, 5),
    pow!(2, 6),
    pow!(2, 7),
    pow!(2, 8),
    pow!(2, 9),
    pow!(2, 10),
    pow!(2, 11),
    pow!(2, 12),
    pow!(2, 13),
    pow!(2, 14),
    pow!(2, 15),
    pow!(2, 16),
    pow!(2, 17),
    pow!(2, 18),
    pow!(2, 19),
    pow!(2, 20),
    pow!(2, 21),
    pow!(2, 22),
    pow!(2, 23),
    pow!(2, 24),
    pow!(2, 25),
    pow!(2, 26),
    pow!(2, 27),
    pow!(2, 28),
    pow!(2, 29),
    pow!(2, 30),
    pow!(2, 31),
    pow!(2, 32),
    pow!(2, 33),
    pow!(2, 34),
    pow!(2, 35),
    pow!(2, 36),
    pow!(2, 37),
    pow!(2, 38),
    pow!(2, 39),
    pow!(2, 40),
    pow!(2, 41),
    pow!(2, 42),
    pow!(2, 43),
    pow!(2, 44),
    pow!(2, 45),
    pow!(2, 46),
    pow!(2, 47),
    pow!(2, 48),
    pow!(2, 49),
    pow!(2, 50),
    pow!(2, 51),
    pow!(2, 52),
    pow!(2, 53),
    pow!(2, 54),
    pow!(2, 55),
    pow!(2, 56),
    pow!(2, 57),
    pow!(2, 58),
    pow!(2, 59),
    pow!(2, 60),
    pow!(2, 61),
    pow!(2, 62),
    pow!(2, 63),
    pow!(2, 64),
    pow!(2, 65),
    pow!(2, 66),
    pow!(2, 67),
    pow!(2, 68),
    pow!(2, 69),
    pow!(2, 70),
    pow!(2, 71),
    pow!(2, 72),
    pow!(2, 73),
    pow!(2, 74),
    pow!(2, 75),
    pow!(2, 76),
    pow!(2, 77),
    pow!(2, 78),
    pow!(2, 79),
    pow!(2, 80),
    pow!(2, 81),
    pow!(2, 82),
    pow!(2, 83),
    pow!(2, 84),
    pow!(2, 85),
    pow!(2, 86),
    pow!(2, 87),
    pow!(2, 88),
    pow!(2, 89),
    pow!(2, 90),
    pow!(2, 91),
    pow!(2, 92),
    pow!(2, 93),
    pow!(2, 94),
    pow!(2, 95),
    pow!(2, 96),
    pow!(2, 97),
    pow!(2, 98),
    pow!(2, 99),
    pow!(2, 100),
    pow!(2, 101),
    pow!(2, 102),
    pow!(2, 103),
    pow!(2, 104),
    pow!(2, 105),
    pow!(2, 106),
    pow!(2, 107),
    pow!(2, 108),
    pow!(2, 109),
    pow!(2, 110),
    pow!(2, 111),
    pow!(2, 112),
    pow!(2, 113),
    pow!(2, 114),
    pow!(2, 115),
    pow!(2, 116),
    pow!(2, 117),
    pow!(2, 118),
    pow!(2, 119),
    pow!(2, 120),
    pow!(2, 121),
    pow!(2, 122),
    pow!(2, 123),
    pow!(2, 124),
    pow!(2, 125),
    pow!(2, 126),
    pow!(2, 127)
];


const MAX_ADDRESS: u256 = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
