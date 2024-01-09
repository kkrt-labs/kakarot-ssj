use alexandria_data_structures::vec::VecTrait;
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::array::SpanTrait;
use core::dict::Felt252DictTrait;
use core::traits::Destruct;
use core::traits::TryInto;
use utils::helpers::{U64Trait, Felt252VecTrait, Felt252VecU8Trait};

type Word = u64;
type DoubleWord = u128;
const WORD_BYTES: usize = 8;
const WORD_BITS: usize = 64;
// 2**64
const BASE: DoubleWord = 18446744073709551616;

/// Multi-precision natural number, represented in base `Word::MAX + 1 = 2^WORD_BITS`.
/// The digits are stored in little-endian order, i.e. digits[0] is the least
/// significant digit.
struct MPNat {
    digits: Felt252Vec<u64>
}


#[generate_trait]
impl MPNatTraitImpl of MPNatTrait {
    fn from_big_endian(bytes: Span<u8>) -> MPNat {
        if bytes.is_empty() {
            return MPNat { digits: Felt252VecImpl::new() };
        }

        // Remainder on division by WORD_BYTES
        let r = bytes.len() & (WORD_BYTES - 1);
        let n_digits: usize = if r == 0 {
            bytes.len() / WORD_BYTES
        } else {
            // Need an extra digit for the remainder
            (bytes.len() / WORD_BYTES) + 1
        };

        let mut digits: Felt252Vec<u64> = Felt252VecImpl::new();
        // safe unwrap, since n_digits >= 0;
        digits.expand(n_digits).unwrap();

        // buffer to hold Word-sized slices of the input bytes
        let mut buf: Felt252Vec<u8> = Felt252VecImpl::new();
        // safe unwrap, since WORD_BYTES > 0
        buf.expand(WORD_BYTES).unwrap();

        let mut i = n_digits - 1;
        if r != 0 {
            // safe unwrap, since we know index is in bound + no overflow
            buf.copy_from_span((WORD_BYTES - r), bytes.slice(0, r)).unwrap();

            // safe unwrap, since we know that bytes won't overflow
            let word = U64Trait::from_be_bytes(buf.to_bytes()).unwrap();
            digits.set(i, word);

            if i == 0 {
                // Special case where there is just one digit
                return MPNat { digits };
            }

            i -= 1;
        };

        let mut j = r;
        loop {
            let next_j = j + WORD_BYTES;
            // safe unwrap, since we know index is in bound + no overflow
            buf.copy_from_span(0, bytes.slice(j, next_j)).unwrap();

            // safe unwrap, since we know that bytes won't overflow
            let word = U64Trait::from_be_bytes(buf.to_bytes()).unwrap();
            digits.set(i, word);

            if i == 0 {
                break;
            }

            i -= 1;
            j = next_j;
        };

        digits.remove_trailing_zeroes_le();
        MPNat { digits }
    }
}
