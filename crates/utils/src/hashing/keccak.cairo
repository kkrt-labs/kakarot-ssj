use utils::hashing::hasher::Hasher;
use utils::math::pow;
use utils::types::bytes::Bytes;
use array::{ArrayTrait, SpanTrait};
use keccak::{keccak_u256s_le_inputs, cairo_keccak};
use traits::{Into, TryInto};
use option::OptionTrait;
use starknet::SyscallResultTrait;

#[derive(Drop)]
struct Keccak {}

#[generate_trait]
impl KeccakHasher of KeccakTrait {
    // @notice keccak256 hashes the input, matching Solidity keccak
    // @param input The input to hash, in big endian
    // @return The hash of the input, in little endian
    fn keccak_cairo(bytes: Bytes) -> u256 {
        let n = bytes.len();
        let q = n / 8;
        let r = n % 8;

        let mut keccak_input = ArrayTrait::new();
        let mut i: usize = 0;
        loop {
            if i >= q {
                break ();
            }

            let val = (*bytes.at(8 * i)).into()
                + (*bytes.at(8 * i + 1)).into() * 256
                + (*bytes.at(8 * i + 2)).into() * 65536
                + (*bytes.at(8 * i + 3)).into() * 16777216
                + (*bytes.at(8 * i + 4)).into() * 4294967296
                + (*bytes.at(8 * i + 5)).into() * 1099511627776
                + (*bytes.at(8 * i + 6)).into() * 281474976710656
                + (*bytes.at(8 * i + 7)).into() * 72057594037927936;

            keccak_input.append(val);

            i += 1;
        };

        let mut last_word: u64 = 0;
        let mut k: usize = 0;
        loop {
            if k >= r {
                break ();
            }

            let current: u64 = (*bytes.at(8 * q + k)).into();
            last_word += current * pow(256, k.into());

            k += 1;
        };

        cairo_keccak(ref keccak_input, last_word, r)
    }
}

impl KeccakHasherU256 of Hasher<u256, u256> {
    fn hash_single(a: u256) -> u256 {
        let mut arr = array![a];
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_double(a: u256, b: u256) -> u256 {
        let mut arr = array![a, b];
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_many(input: Span<u256>) -> u256 {
        keccak_u256s_le_inputs(input)
    }
}

impl KeccakHasherSpanU8 of Hasher<Span<u8>, u256> {
    fn hash_single(a: Span<u8>) -> u256 {
        let mut arr = ArrayTrait::new();
        let mut i: usize = 0;
        loop {
            if i >= a.len() {
                break arr.span();
            }
            let current = *a.at(i);
            arr.append(current.into());
            i += 1;
        };
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_double(a: Span<u8>, b: Span<u8>) -> u256 {
        let mut arr = ArrayTrait::new();
        let mut i: usize = 0;
        loop {
            if i >= a.len() {
                break arr.span();
            }
            let current = *a.at(i);
            arr.append(current.into());
            i += 1;
        };

        i = 0;
        loop {
            if i >= b.len() {
                break arr.span();
            }
            let current = *b.at(i);
            arr.append(current.into());
            i += 1;
        };
        keccak_u256s_le_inputs(arr.span())
    }

    fn hash_many(input: Span<Span<u8>>) -> u256 {
        let mut arr = ArrayTrait::new();
        let mut i: usize = 0;
        let mut j: usize = 0;
        loop {
            if i >= input.len() {
                break arr.span();
            }

            let current = *input.at(i);
            loop {
                if j >= current.len() {
                    break;
                }
                let current = *current.at(j);
                arr.append(current.into());
                j += 1;
            };
            i += 1;
        };

        keccak_u256s_le_inputs(arr.span())
    }
}

