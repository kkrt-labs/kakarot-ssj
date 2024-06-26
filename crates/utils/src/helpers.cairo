use alexandria_data_structures::vec::VecTrait;
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use cmp::min;
use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::hash::{HashStateExTrait, HashStateTrait};
use core::num::traits::{Zero, One, BitSize};
use core::pedersen::{HashState, PedersenTrait};
use core::traits::TryInto;

use integer::{BoundedInt, u32_as_non_zero, U32TryIntoNonZero};
use integer::{u32_overflowing_add};
use keccak::{cairo_keccak, u128_split};
use starknet::{
    EthAddress, EthAddressIntoFelt252, ContractAddress, ClassHash,
    eth_signature::{Signature as EthSignature}
};
use traits::DivRem;
use utils::constants::{
    POW_256_0, POW_256_1, POW_256_2, POW_256_3, POW_256_4, POW_256_5, POW_256_6, POW_256_7,
    POW_256_8, POW_256_9, POW_256_10, POW_256_11, POW_256_12, POW_256_13, POW_256_14, POW_256_15,
    POW_256_16,
};
use utils::constants::{CONTRACT_ADDRESS_PREFIX, MAX_ADDRESS};
use utils::eth_transaction::{TransactionType};
use utils::math::{Bitshift, WrappingBitshift, Exponentiation, SaturatingAdd};
use utils::traits::{U256TryIntoContractAddress, EthAddressIntoU256, TryIntoResult, BoolIntoNumeric};

/// Converts a value to the next closest multiple of 32
///
/// # Arguments
/// * `value` - The value to ceil to the next multiple of 32
///
/// # Returns
/// The same value if it's a perfect multiple of 32
/// else it returns the smallest multiple of 32
/// that is greater than `value`.
///
/// # Examples
/// ceil32(2) = 32
/// ceil32(34) = 64
fn ceil32(value: usize) -> usize {
    let ceiling = 32_u32;
    let (_q, r) = DivRem::div_rem(value, ceiling.try_into().unwrap());
    if r == 0_u8.into() {
        return value;
    } else {
        return (value + ceiling - r).into();
    }
}

/// Computes 256 ** (16 - i) for 0 <= i <= 16.
fn pow256_rev(i: usize) -> u256 {
    if (i > 16) {
        panic_with_felt252('pow256_rev: i > 16');
    }

    if i == 0 {
        return POW_256_16;
    } else if i == 1 {
        return POW_256_15.into();
    } else if i == 2 {
        return POW_256_14.into();
    } else if i == 3 {
        return POW_256_13.into();
    } else if i == 4 {
        return POW_256_12.into();
    } else if i == 5 {
        return POW_256_11.into();
    } else if i == 6 {
        return POW_256_10.into();
    } else if i == 7 {
        return POW_256_9.into();
    } else if i == 8 {
        return POW_256_8.into();
    } else if i == 9 {
        return POW_256_7.into();
    } else if i == 10 {
        return POW_256_6.into();
    } else if i == 11 {
        return POW_256_5.into();
    } else if i == 12 {
        return POW_256_4.into();
    } else if i == 13 {
        return POW_256_3.into();
    } else if i == 14 {
        return POW_256_2.into();
    } else if i == 15 {
        return POW_256_1.into();
    } else {
        return POW_256_0.into();
    }
}

// Computes 2**pow for 0 <= pow < 128.
fn pow2(pow: usize) -> u128 {
    if pow == 0 {
        return 0x1;
    } else if pow == 1 {
        return 0x2;
    } else if pow == 2 {
        return 0x4;
    } else if pow == 3 {
        return 0x8;
    } else if pow == 4 {
        return 0x10;
    } else if pow == 5 {
        return 0x20;
    } else if pow == 6 {
        return 0x40;
    } else if pow == 7 {
        return 0x80;
    } else if pow == 8 {
        return 0x100;
    } else if pow == 9 {
        return 0x200;
    } else if pow == 10 {
        return 0x400;
    } else if pow == 11 {
        return 0x800;
    } else if pow == 12 {
        return 0x1000;
    } else if pow == 13 {
        return 0x2000;
    } else if pow == 14 {
        return 0x4000;
    } else if pow == 15 {
        return 0x8000;
    } else if pow == 16 {
        return 0x10000;
    } else if pow == 17 {
        return 0x20000;
    } else if pow == 18 {
        return 0x40000;
    } else if pow == 19 {
        return 0x80000;
    } else if pow == 20 {
        return 0x100000;
    } else if pow == 21 {
        return 0x200000;
    } else if pow == 22 {
        return 0x400000;
    } else if pow == 23 {
        return 0x800000;
    } else if pow == 24 {
        return 0x1000000;
    } else if pow == 25 {
        return 0x2000000;
    } else if pow == 26 {
        return 0x4000000;
    } else if pow == 27 {
        return 0x8000000;
    } else if pow == 28 {
        return 0x10000000;
    } else if pow == 29 {
        return 0x20000000;
    } else if pow == 30 {
        return 0x40000000;
    } else if pow == 31 {
        return 0x80000000;
    } else if pow == 32 {
        return 0x100000000;
    } else if pow == 33 {
        return 0x200000000;
    } else if pow == 34 {
        return 0x400000000;
    } else if pow == 35 {
        return 0x800000000;
    } else if pow == 36 {
        return 0x1000000000;
    } else if pow == 37 {
        return 0x2000000000;
    } else if pow == 38 {
        return 0x4000000000;
    } else if pow == 39 {
        return 0x8000000000;
    } else if pow == 40 {
        return 0x10000000000;
    } else if pow == 41 {
        return 0x20000000000;
    } else if pow == 42 {
        return 0x40000000000;
    } else if pow == 43 {
        return 0x80000000000;
    } else if pow == 44 {
        return 0x100000000000;
    } else if pow == 45 {
        return 0x200000000000;
    } else if pow == 46 {
        return 0x400000000000;
    } else if pow == 47 {
        return 0x800000000000;
    } else if pow == 48 {
        return 0x1000000000000;
    } else if pow == 49 {
        return 0x2000000000000;
    } else if pow == 50 {
        return 0x4000000000000;
    } else if pow == 51 {
        return 0x8000000000000;
    } else if pow == 52 {
        return 0x10000000000000;
    } else if pow == 53 {
        return 0x20000000000000;
    } else if pow == 54 {
        return 0x40000000000000;
    } else if pow == 55 {
        return 0x80000000000000;
    } else if pow == 56 {
        return 0x100000000000000;
    } else if pow == 57 {
        return 0x200000000000000;
    } else if pow == 58 {
        return 0x400000000000000;
    } else if pow == 59 {
        return 0x800000000000000;
    } else if pow == 60 {
        return 0x1000000000000000;
    } else if pow == 61 {
        return 0x2000000000000000;
    } else if pow == 62 {
        return 0x4000000000000000;
    } else if pow == 63 {
        return 0x8000000000000000;
    } else if pow == 64 {
        return 0x10000000000000000;
    } else if pow == 65 {
        return 0x20000000000000000;
    } else if pow == 66 {
        return 0x40000000000000000;
    } else if pow == 67 {
        return 0x80000000000000000;
    } else if pow == 68 {
        return 0x100000000000000000;
    } else if pow == 69 {
        return 0x200000000000000000;
    } else if pow == 70 {
        return 0x400000000000000000;
    } else if pow == 71 {
        return 0x800000000000000000;
    } else if pow == 72 {
        return 0x1000000000000000000;
    } else if pow == 73 {
        return 0x2000000000000000000;
    } else if pow == 74 {
        return 0x4000000000000000000;
    } else if pow == 75 {
        return 0x8000000000000000000;
    } else if pow == 76 {
        return 0x10000000000000000000;
    } else if pow == 77 {
        return 0x20000000000000000000;
    } else if pow == 78 {
        return 0x40000000000000000000;
    } else if pow == 79 {
        return 0x80000000000000000000;
    } else if pow == 80 {
        return 0x100000000000000000000;
    } else if pow == 81 {
        return 0x200000000000000000000;
    } else if pow == 82 {
        return 0x400000000000000000000;
    } else if pow == 83 {
        return 0x800000000000000000000;
    } else if pow == 84 {
        return 0x1000000000000000000000;
    } else if pow == 85 {
        return 0x2000000000000000000000;
    } else if pow == 86 {
        return 0x4000000000000000000000;
    } else if pow == 87 {
        return 0x8000000000000000000000;
    } else if pow == 88 {
        return 0x10000000000000000000000;
    } else if pow == 89 {
        return 0x20000000000000000000000;
    } else if pow == 90 {
        return 0x40000000000000000000000;
    } else if pow == 91 {
        return 0x80000000000000000000000;
    } else if pow == 92 {
        return 0x100000000000000000000000;
    } else if pow == 93 {
        return 0x200000000000000000000000;
    } else if pow == 94 {
        return 0x400000000000000000000000;
    } else if pow == 95 {
        return 0x800000000000000000000000;
    } else if pow == 96 {
        return 0x1000000000000000000000000;
    } else if pow == 97 {
        return 0x2000000000000000000000000;
    } else if pow == 98 {
        return 0x4000000000000000000000000;
    } else if pow == 99 {
        return 0x8000000000000000000000000;
    } else if pow == 100 {
        return 0x10000000000000000000000000;
    } else if pow == 101 {
        return 0x20000000000000000000000000;
    } else if pow == 102 {
        return 0x40000000000000000000000000;
    } else if pow == 103 {
        return 0x80000000000000000000000000;
    } else if pow == 104 {
        return 0x100000000000000000000000000;
    } else if pow == 105 {
        return 0x200000000000000000000000000;
    } else if pow == 106 {
        return 0x400000000000000000000000000;
    } else if pow == 107 {
        return 0x800000000000000000000000000;
    } else if pow == 108 {
        return 0x1000000000000000000000000000;
    } else if pow == 109 {
        return 0x2000000000000000000000000000;
    } else if pow == 110 {
        return 0x4000000000000000000000000000;
    } else if pow == 111 {
        return 0x8000000000000000000000000000;
    } else if pow == 112 {
        return 0x10000000000000000000000000000;
    } else if pow == 113 {
        return 0x20000000000000000000000000000;
    } else if pow == 114 {
        return 0x40000000000000000000000000000;
    } else if pow == 115 {
        return 0x80000000000000000000000000000;
    } else if pow == 116 {
        return 0x100000000000000000000000000000;
    } else if pow == 117 {
        return 0x200000000000000000000000000000;
    } else if pow == 118 {
        return 0x400000000000000000000000000000;
    } else if pow == 119 {
        return 0x800000000000000000000000000000;
    } else if pow == 120 {
        return 0x1000000000000000000000000000000;
    } else if pow == 121 {
        return 0x2000000000000000000000000000000;
    } else if pow == 122 {
        return 0x4000000000000000000000000000000;
    } else if pow == 123 {
        return 0x8000000000000000000000000000000;
    } else if pow == 124 {
        return 0x10000000000000000000000000000000;
    } else if pow == 125 {
        return 0x20000000000000000000000000000000;
    } else if pow == 126 {
        return 0x40000000000000000000000000000000;
    } else if pow == 127 {
        return 0x80000000000000000000000000000000;
    } else {
        return panic_with_felt252('pow2: pow >= 128');
    }
}


/// Splits a u256 into `len` bytes, big-endian, and appends the result to `dst`.
fn split_word(mut value: u256, mut len: usize, ref dst: Array<u8>) {
    let word_le = split_word_le(value, len);
    let word_be = ArrayExtTrait::reverse(word_le.span());
    ArrayExtTrait::concat(ref dst, word_be.span());
}

fn split_u128_le(ref dest: Array<u8>, mut value: u128, mut len: usize) {
    loop {
        if len == 0 {
            assert(value == 0, 'split_words:value not 0');
            break;
        }
        dest.append((value % 256).try_into().unwrap());
        value /= 256;
        len -= 1;
    }
}

/// Splits a u256 into `len` bytes, little-endian, and returns the bytes array.
fn split_word_le(mut value: u256, mut len: usize) -> Array<u8> {
    let mut dst: Array<u8> = ArrayTrait::new();
    let low_len = min(len, 16);
    split_u128_le(ref dst, value.low, low_len);
    let high_len = min(len - low_len, 16);
    split_u128_le(ref dst, value.high, high_len);
    dst
}

/// Splits a u256 into 16 bytes, big-endian, and appends the result to `dst`.
fn split_word_128(value: u256, ref dst: Array<u8>) {
    split_word(value, 16, ref dst)
}


/// Loads a sequence of bytes into a single u256 in big-endian
///
/// # Arguments
/// * `len` - The number of bytes to load
/// * `words` - The bytes to load
///
/// # Returns
/// The packed u256
fn load_word(mut len: usize, words: Span<u8>) -> u256 {
    if len == 0 {
        return 0;
    }

    let mut current: u256 = 0;
    let mut counter = 0;

    loop {
        if len == 0 {
            break;
        }
        let loaded: u8 = *words[counter];
        let tmp = current * 256;
        current = tmp + loaded.into();
        len -= 1;
        counter += 1;
    };

    current
}

/// Converts a u256 to a bytes array represented by an array of u8 values.
///
/// # Arguments
/// * `value` - The value to convert
///
/// # Returns
/// The bytes array representation of the value.
fn u256_to_bytes_array(mut value: u256) -> Array<u8> {
    let mut counter = 0;
    let mut bytes_arr: Array<u8> = ArrayTrait::new();
    // low part
    loop {
        if counter == 16 {
            break ();
        }
        bytes_arr.append((value.low & 0xFF).try_into().unwrap());
        value.low /= 256;
        counter += 1;
    };

    let mut counter = 0;
    // high part
    loop {
        if counter == 16 {
            break ();
        }
        bytes_arr.append((value.high & 0xFF).try_into().unwrap());
        value.high /= 256;
        counter += 1;
    };

    // Reverse the array as memory is arranged in big endian order.
    let mut counter = bytes_arr.len();
    let mut bytes_arr_reversed: Array<u8> = ArrayTrait::new();
    loop {
        if counter == 0 {
            break ();
        }
        bytes_arr_reversed.append(*bytes_arr[counter - 1]);
        counter -= 1;
    };
    bytes_arr_reversed
}

#[generate_trait]
impl ArrayExtension<T, +Drop<T>> of ArrayExtTrait<T> {
    // Concatenates two arrays by adding the elements of arr2 to arr1.
    fn concat<+Copy<T>>(ref self: Array<T>, mut arr2: Span<T>) {
        loop {
            match arr2.pop_front() {
                Option::Some(elem) => self.append(*elem),
                Option::None => { break; }
            };
        };
    }

    /// Reverses an array
    fn reverse<+Copy<T>>(self: Span<T>) -> Array<T> {
        let mut counter = self.len();
        let mut dst: Array<T> = ArrayTrait::new();
        loop {
            if counter == 0 {
                break ();
            }
            dst.append(*self[counter - 1]);
            counter -= 1;
        };
        dst
    }

    // Appends n time value to the Array
    fn append_n<+Copy<T>>(ref self: Array<T>, value: T, mut n: usize) {
        loop {
            if n == 0 {
                break;
            }

            self.append(value);

            n -= 1;
        };
    }

    // Appends an item only if it is not already in the array.
    fn append_unique<+Copy<T>, +PartialEq<T>>(ref self: Array<T>, value: T) {
        if self.span().contains(value) {
            return ();
        }
        self.append(value);
    }

    // Concatenates two arrays by adding the elements of arr2 to arr1.
    fn concat_unique<+Copy<T>, +PartialEq<T>>(ref self: Array<T>, mut arr2: Span<T>) {
        loop {
            match arr2.pop_front() {
                Option::Some(elem) => self.append_unique(*elem),
                Option::None => { break; }
            };
        };
    }
}

#[generate_trait]
impl SpanExtension<T, +Copy<T>, +Drop<T>> of SpanExtTrait<T> {
    // Returns true if the array contains an item.
    fn contains<+PartialEq<T>>(mut self: Span<T>, value: T) -> bool {
        loop {
            match self.pop_front() {
                Option::Some(elem) => { if *elem == value {
                    break true;
                } },
                Option::None => { break false; }
            }
        }
    }

    // Returns the index of an item in the array.
    fn index_of<+PartialEq<T>>(mut self: Span<T>, value: T) -> Option<u128> {
        let mut i = 0;
        loop {
            match self.pop_front() {
                Option::Some(elem) => { if *elem == value {
                    break Option::Some(i);
                } },
                Option::None => { break Option::None; }
            }
            i += 1;
        }
    }
}

#[generate_trait]
impl U8SpanExImpl of U8SpanExTrait {
    // keccack256 on a bytes message
    fn compute_keccak256_hash(self: Span<u8>) -> u256 {
        let (mut keccak_input, last_input_word, last_input_num_bytes) = self.to_u64_words();
        let hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes)
            .reverse_endianness();

        hash
    }
    /// Transforms a Span<u8> into an Array of u64 full words, a pending u64 word and its length in
    /// bytes
    fn to_u64_words(self: Span<u8>) -> (Array<u64>, u64, usize) {
        let (full_u64_word_count, last_input_num_bytes) = DivRem::div_rem(
            self.len(), u32_as_non_zero(8)
        );

        let mut u64_words: Array<u64> = Default::default();
        let mut byte_counter: u8 = 0;
        let mut pending_word: u64 = 0;
        let mut u64_word_counter: usize = 0;

        loop {
            if u64_word_counter == full_u64_word_count {
                break self;
            }
            if byte_counter == 8 {
                u64_words.append(pending_word);
                byte_counter = 0;
                pending_word = 0;
                u64_word_counter += 1;
            }
            pending_word += match self.get(u64_word_counter * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = (*byte.unbox()).into();
                    // Accumulate pending_word in a little endian manner
                    byte.shl(8_u64 * byte_counter.into())
                },
                Option::None => { break self; },
            };
            byte_counter += 1;
        };

        // Fill the last input word
        let mut last_input_word: u64 = 0;
        let mut byte_counter: u8 = 0;

        // We enter a second loop for clarity.
        // O(2n) should be okay
        // We might want to regroup every computation into a single loop with appropriate `if`
        // branching For optimisation
        loop {
            if byte_counter.into() == last_input_num_bytes {
                break self;
            }
            last_input_word += match self.get(full_u64_word_count * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = (*byte.unbox()).into();
                    byte.shl(8_u64 * byte_counter.into())
                },
                Option::None => { break self; },
            };
            byte_counter += 1;
        };

        (u64_words, last_input_word, last_input_num_bytes)
    }

    /// Returns right padded slice of the span, starting from index offset
    /// If offset is greater than the span length, returns an empty span
    /// # Examples
    ///
    /// ```
    ///   let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
    ///   let expected = array![0x04, 0x05, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
    ///   let result = span.slice_right_padded(4, 10);
    ///   assert_eq!(result, expected);
    /// ```
    /// # Arguments
    /// * `offset` - The offset to start the slice from
    /// * `len` - The length of the slice
    ///
    /// # Returns
    /// * A span of length `len` starting from `offset` right padded with 0s if `offset` is greater
    /// than the span length, returns an empty span of length `len` if offset is grearter than the
    /// span length
    fn slice_right_padded(self: Span<u8>, offset: usize, len: usize) -> Span<u8> {
        let mut arr = array![];

        let start = if offset <= self.len() {
            offset
        } else {
            self.len()
        };

        let end = min(start.saturating_add(len), self.len());

        let slice = self.slice(start, end - start);
        // Save appending to span for this case as it is more efficient to just return the slice
        if slice.len() == len {
            return slice;
        }

        // Copy the span
        arr.append_span(slice);

        loop {
            if arr.len() == len {
                break;
            };

            arr.append(0);
        };

        arr.span()
    }

    /// Clones and pads the given span with 0s to the given length, if data is more than the given
    /// length, it is truncated from the right side # Examples
    /// ```
    ///  let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
    ///  let expected = array![0x0, 0x0, 0x0, 0x0, 0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
    ///  let result = span.pad_left_with_zeroes(10);
    ///
    ///  assert_eq!(result, expected);
    ///
    ///  // Truncates the data if it is more than the given length
    ///  let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
    ///  let expected = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8].span();
    ///  let result = span.pad_left_with_zeroes(9);
    ///
    ///  assert_eq!(result, expected);
    /// ```
    /// # Arguments
    /// * `len` - The length of the padded span
    ///
    /// # Returns
    /// * A span of length `len` left padded with 0s if the span length is less than `len`, returns
    /// a span of length `len` if the span length is greater than `len` then the data is truncated
    /// from the right side
    fn pad_left_with_zeroes(self: Span<u8>, len: usize) -> Span<u8> {
        if self.len() >= len {
            return self.slice(0, len);
        }

        // left pad with 0
        let mut arr = array![];
        loop {
            if arr.len() == (len - self.len()) {
                break;
            };

            arr.append(0);
        };

        // append the data
        let mut i = 0;
        loop {
            if i == self.len() {
                break;
            };

            arr.append(*self[i]);
            i += 1;
        };

        arr.span()
    }
}

#[generate_trait]
impl U64Impl of U64Trait {
    /// Returns the number of trailing zeroes in the bit representation of `self`.
    /// # Arguments
    /// * `self` a `u64` value.
    /// # Returns
    /// * The number of trailing zeroes in the bit representation of `self`.
    fn count_trailing_zeroes(self: u64) -> u8 {
        let mut count = 0;

        if self == 0 {
            return 64; // If n is 0, all 64 bits are zeros
        };

        let mut mask = 1;

        loop {
            if (self & mask) != 0 {
                break;
            }

            count += 1;
            mask *= 2;
        };

        count
    }
}


#[generate_trait]
impl U128Impl of U128Trait {
    /// Returns the Least signficant 64 bits of a u128
    fn as_u64(self: u128) -> u64 {
        let (_, bottom_word) = u128_split(self);
        bottom_word
    }
}

#[generate_trait]
impl U256Impl of U256Trait {
    /// Splits an u256 into 4 little endian u64.
    /// Returns ((high_high, high_low),(low_high, low_low))
    fn split_into_u64_le(self: u256) -> ((u64, u64), (u64, u64)) {
        let low_le = integer::u128_byte_reverse(self.low);
        let high_le = integer::u128_byte_reverse(self.high);
        (u128_split(high_le), u128_split(low_le))
    }

    /// Reverse the endianness of an u256
    fn reverse_endianness(self: u256) -> u256 {
        let new_low = integer::u128_byte_reverse(self.high);
        let new_high = integer::u128_byte_reverse(self.low);
        u256 { low: new_low, high: new_high }
    }
}

trait ToBytes<T> {
    /// Unpacks a type T into a span of big endian bytes
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytes representation of the value in big endian.
    fn to_be_bytes(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of big endian bytes, padded to the byte size of T
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytesrepresentation of the value in big endian padded to the byte size of T.
    fn to_be_bytes_padded(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of little endian bytes
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytes representation of the value in little endian.
    fn to_le_bytes(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of little endian bytes, padded to the byte size of T
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytesrepresentation of the value in little endian padded to the byte size of T.
    fn to_le_bytes_padded(self: T) -> Span<u8>;
}

impl ToBytesImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +BitAnd<T>,
    +Bitshift<T>,
    +BitSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +core::ops::AddAssign<T, T>,
    +PartialEq<T>
> of ToBytes<T> {
    fn to_be_bytes(self: T) -> Span<u8> {
        let bytes_used = self.bytes_used();

        let one = One::<T>::one();
        let two = one + one;
        let eight = two * two * two;

        // 0xFF
        let mask = BoundedInt::<u8>::max().into();

        let mut bytes: Array<u8> = Default::default();
        let mut i: u8 = 0;
        loop {
            if i == bytes_used {
                break ();
            }

            let val = Bitshift::<T>::shr(self, eight * (bytes_used - i - 1).into());
            bytes.append((val & mask).try_into().unwrap());
            i += 1;
        };

        bytes.span()
    }

    fn to_be_bytes_padded(mut self: T) -> Span<u8> {
        let padding = (BitSize::<T>::bits() / 8);
        self.to_be_bytes().pad_left_with_zeroes(padding)
    }

    fn to_le_bytes(mut self: T) -> Span<u8> {
        let bytes_used = self.bytes_used();
        let one = One::<T>::one();
        let two = one + one;
        let eight = two * two * two;

        // 0xFF
        let mask = BoundedInt::<u8>::max().into();

        let mut bytes: Array<u8> = Default::default();

        let mut i: u8 = 0;
        loop {
            if i == bytes_used {
                break ();
            }
            let val = self.shr(eight * i.into());
            bytes.append((val & mask).try_into().unwrap());
            i += 1;
        };

        bytes.span()
    }

    fn to_le_bytes_padded(mut self: T) -> Span<u8> {
        let padding = (BitSize::<T>::bits() / 8);
        self.to_le_bytes().slice_right_padded(0, padding)
    }
}

trait FromBytes<T> {
    /// Parses a span of big endian bytes into a type T
    ///
    /// # Arguments
    /// * `self` a span of big endian bytes.
    ///
    /// # Returns
    /// * The Option::(value) represented by the bytes in big endian, Option::None if the span is
    /// longer than the byte size of T.
    fn from_be_bytes(self: Span<u8>) -> Option<T>;
    /// Parses a span of little endian bytes into a type T
    ///
    /// # Arguments
    /// * `self` a span of little endian bytes.
    ///
    /// # Returns
    /// * The Option::(value) represented by the bytes in little endian, Option::None if the span is
    /// longer than the byte size of T.
    fn from_le_bytes(self: Span<u8>) -> Option<T>;
}

impl FromBytesImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +BitAnd<T>,
    +Bitshift<T>,
    +ByteSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +Into<u32, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +core::ops::AddAssign<T, T>,
    +PartialEq<T>
> of FromBytes<T> {
    fn from_be_bytes(self: Span<u8>) -> Option<T> {
        let byte_size = ByteSize::<T>::byte_size();

        let len = self.len();
        if len == 0 {
            return Option::Some(Zero::zero());
        }
        if len > byte_size {
            return Option::None;
        }
        let offset: u32 = len - 1;
        let mut result: T = Zero::zero();
        let mut i: u32 = 0;
        loop {
            if i == len {
                break ();
            }
            let byte: T = (*self.at(i)).into();
            // Safe unwrap, since offset - i is inbound in case of u8 { offset - i = 0 }, and
            // TryInto<u32, u32>, TryInto<u32, u64>, TryInto<u32, u128>, TryInto<u32, 256> are safe
            result += byte.shl((8 * (offset - i)).into());

            i += 1;
        };
        Option::Some(result)
    }

    fn from_le_bytes(self: Span<u8>) -> Option<T> {
        let byte_size = ByteSize::<T>::byte_size();
        let len = self.len();

        if len == 0 {
            return Option::Some(Zero::zero());
        }
        if len > byte_size {
            return Option::None;
        }

        let mut result: T = Zero::zero();
        let mut i: u32 = 0;
        loop {
            if i == len {
                break ();
            }
            let byte: T = (*self.at(i)).into();
            // safe unwrap, as i is inbound in case of u8 { max value can be 8 * 1 = 8 }, and
            // TryInto<u32, u32>, TryInto<u32, u64>, TryInto<u32, u128>, TryInto<u32, 256> are safe
            result += byte.shl((8 * i).into());

            i += 1;
        };
        Option::Some(result)
    }
}


#[generate_trait]
impl ByteArrayExt of ByteArrayExTrait {
    fn append_span_bytes(ref self: ByteArray, mut bytes: Span<u8>) {
        loop {
            match bytes.pop_front() {
                Option::Some(val) => { self.append_byte(*val) },
                Option::None => { break; }
            }
        }
    }

    fn from_bytes(mut bytes: Span<u8>) -> ByteArray {
        let mut arr: ByteArray = Default::default();
        let (nb_full_words, pending_word_len) = DivRem::div_rem(
            bytes.len(), 31_u32.try_into().unwrap()
        );
        let mut i = 0;
        loop {
            if i == nb_full_words {
                break;
            };
            let mut word: felt252 = 0;
            let mut j = 0;
            loop {
                if j == 31 {
                    break;
                };
                word = word * POW_256_1.into() + (*bytes.pop_front().unwrap()).into();
                j += 1;
            };
            arr.data.append(word.try_into().unwrap());
            i += 1;
        };

        if pending_word_len == 0 {
            return arr;
        };

        let mut pending_word: felt252 = 0;
        let mut i = 0;

        loop {
            if i == pending_word_len {
                break;
            };
            pending_word = pending_word * POW_256_1.into() + (*bytes.pop_front().unwrap()).into();
            i += 1;
        };
        arr.pending_word_len = pending_word_len;
        arr.pending_word = pending_word;
        arr
    }

    fn is_empty(self: @ByteArray) -> bool {
        self.len() == 0
    }

    fn into_bytes(self: ByteArray) -> Span<u8> {
        let mut output: Array<u8> = Default::default();
        let len = self.len();
        let mut i = 0;
        loop {
            if i == len {
                break;
            };
            output.append(self[i]);
            i += 1;
        };
        output.span()
    }


    /// Transforms a ByteArray into an Array of u64 full words, a pending u64 word and its length in
    /// bytes
    fn to_u64_words(self: ByteArray) -> (Array<u64>, u64, usize) {
        // We pass it by value because we want to take ownership, but we snap it
        // because `at` takes a snap and if this snap is automatically done by
        // the compiler in the loop, it won't compile
        let self = @self;
        let (full_u64_word_count, last_input_num_bytes) = DivRem::div_rem(
            self.len(), u32_as_non_zero(8)
        );

        let mut u64_words: Array<u64> = Default::default();
        let mut byte_counter: u8 = 0;
        let mut pending_word: u64 = 0;
        let mut u64_word_counter: usize = 0;

        loop {
            if u64_word_counter == full_u64_word_count {
                break;
            }
            if byte_counter == 8 {
                u64_words.append(pending_word);
                byte_counter = 0;
                pending_word = 0;
                u64_word_counter += 1;
            }
            pending_word += match self.at(u64_word_counter * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = byte.into();
                    // Accumulate pending_word in a little endian manner
                    byte.shl(8_u64 * byte_counter.into())
                },
                Option::None => { break; },
            };
            byte_counter += 1;
        };

        // Fill the last input word
        let mut last_input_word: u64 = 0;
        let mut byte_counter: u8 = 0;

        // We enter a second loop for clarity.
        // O(2n) should be okay
        // We might want to regroup every computation into a single loop with appropriate `if`
        // branching For optimisation
        loop {
            if byte_counter.into() == last_input_num_bytes {
                break;
            }
            last_input_word += match self.at(full_u64_word_count * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = byte.into();
                    byte.shl(8_u64 * byte_counter.into())
                },
                Option::None => { break; },
            };
            byte_counter += 1;
        };

        (u64_words, last_input_word, last_input_num_bytes)
    }
}

#[generate_trait]
impl ResultExImpl<T, E, +Drop<T>, +Drop<E>> of ResultExTrait<T, E> {
    /// Converts a Result<T,E> to a Result<T,F>
    fn map_err<F, +Drop<F>>(self: Result<T, E>, err: F) -> Result<T, F> {
        match self {
            Result::Ok(val) => Result::Ok(val),
            Result::Err(_) => Result::Err(err)
        }
    }
}


fn compute_starknet_address(
    kakarot_address: ContractAddress, evm_address: EthAddress, class_hash: ClassHash
) -> ContractAddress {
    // Deployer is always 0
    // pedersen(a1, a2, a3) is defined as:
    // pedersen(pedersen(pedersen(a1, a2), a3), len([a1, a2, a3]))
    //
    //
    // 
    // https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/hash_state.py#L6
    // https://github.com/xJonathanLEI/starknet-rs/blob/master/starknet-core/src/crypto.rs#L49
    // Constructor Calldata For an Account, the constructor calldata is:
    // [kakarot_address, evm_address]
    let constructor_calldata_hash = PedersenTrait::new(0)
        .update_with(kakarot_address)
        .update_with(evm_address)
        .update(2)
        .finalize();

    let hash = PedersenTrait::new(0)
        .update_with(CONTRACT_ADDRESS_PREFIX)
        .update_with(0)
        .update_with(evm_address)
        .update_with(class_hash)
        .update_with(constructor_calldata_hash)
        .update(5)
        .finalize();

    let normalized_address: ContractAddress = (hash.into() & MAX_ADDRESS).try_into().unwrap();
    // We know this unwrap is safe, because of the above bitwise AND on 2 ** 251
    normalized_address
}


#[generate_trait]
impl EthAddressExImpl of EthAddressExTrait {
    fn to_bytes(self: EthAddress) -> Array<u8> {
        let bytes_used: u256 = 20;
        let value: u256 = self.into();
        let mut bytes: Array<u8> = Default::default();
        let mut i = 0;
        loop {
            if i == bytes_used {
                break ();
            }
            let val = value.wrapping_shr(8 * (bytes_used - i - 1));
            bytes.append((val & 0xFF).try_into().unwrap());
            i += 1;
        };

        bytes
    }

    /// Packs 20 bytes into a EthAddress
    /// # Arguments
    /// * `input` a Span<u8> of len == 20
    /// # Returns
    /// * Option::Some(EthAddress) if the operation succeeds
    /// * Option::None otherwise
    fn from_bytes(input: Span<u8>) -> EthAddress {
        let len = input.len();
        if len != 20 {
            panic_with_felt252('EthAddress::from_bytes != 20b')
        }
        let offset: u32 = len - 1;
        let mut result: u256 = 0;
        let mut i: u32 = 0;
        loop {
            if i == len {
                break ();
            }
            let byte: u256 = (*input.at(i)).into();
            result += byte.shl((8 * (offset - i)).into());

            i += 1;
        };
        result.try_into().unwrap()
    }
}


trait BytesUsedTrait<T> {
    /// Returns the number of bytes used to represent a `T` value.
    /// # Arguments
    /// * `self` - The value to check.
    /// # Returns
    /// The number of bytes used to represent the value.
    fn bytes_used(self: T) -> u8;
}

impl U8BytesUsedTraitImpl of BytesUsedTrait<u8> {
    fn bytes_used(self: u8) -> u8 {
        if self == 0 {
            return 0;
        }

        return 1;
    }
}

impl USizeBytesUsedTraitImpl of BytesUsedTrait<usize> {
    fn bytes_used(self: usize) -> u8 {
        if self < 0x10000 { // 256^2
            if self < 0x100 { // 256^1
                if self == 0 {
                    return 0;
                } else {
                    return 1;
                };
            }
            return 2;
        } else {
            if self < 0x1000000 { // 256^3
                return 3;
            }
            return 4;
        }
    }
}

impl U64BytesUsedTraitImpl of BytesUsedTrait<u64> {
    fn bytes_used(self: u64) -> u8 {
        if self <= BoundedInt::<u32>::max().into() { // 256^4
            return BytesUsedTrait::<u32>::bytes_used(self.try_into().unwrap());
        } else {
            if self < 0x1000000000000 { // 256^6
                if self < 0x10000000000 {
                    if self < 0x100000000 {
                        return 4;
                    }
                    return 5;
                }
                return 6;
            } else {
                if self < 0x100000000000000 { // 256^7
                    return 7;
                } else {
                    return 8;
                }
            }
        }
    }
}

impl U128BytesTraitUsedImpl of BytesUsedTrait<u128> {
    fn bytes_used(self: u128) -> u8 {
        let (u64high, u64low) = u128_split(self);
        if u64high == 0 {
            return BytesUsedTrait::<u64>::bytes_used(u64low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u64>::bytes_used(u64high.try_into().unwrap()) + 8;
        }
    }
}

impl U256BytesUsedTraitImpl of BytesUsedTrait<u256> {
    fn bytes_used(self: u256) -> u8 {
        if self.high == 0 {
            return BytesUsedTrait::<u128>::bytes_used(self.low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u128>::bytes_used(self.high.try_into().unwrap()) + 16;
        }
    }
}

trait ByteSize<T> {
    fn byte_size() -> usize;
}

impl ByteSizeImpl<T, +BitSize<T>> of ByteSize<T> {
    fn byte_size() -> usize {
        BitSize::<T>::bits() / 8
    }
}

trait BitsUsed<T> {
    /// Returns the number of bits required to represent `self`, ignoring leading zeros.
    /// # Arguments
    /// `self` - The value to check.
    /// # Returns
    /// The number of bits used to represent the value, ignoring leading zeros.
    fn bits_used(self: T) -> u32;

    /// Returns the number of leading zeroes in the bit representation of `self`.
    /// # Arguments
    /// `self` - The value to check.
    /// # Returns
    /// The number of leading zeroes in the bit representation of `self`.
    fn count_leading_zeroes(self: T) -> u32;
}

impl BitsUsedImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +Bitshift<T>,
    +BitSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +PartialEq<T>
> of BitsUsed<T> {
    fn bits_used(self: T) -> u32 {
        if self == Zero::zero() {
            return 0;
        }
        let two: T = One::one() + One::one();
        let eight: T = two * two * two;

        let bytes_used = self.bytes_used();
        let last_byte = self.shr(eight * (bytes_used.into() - One::one()));

        // safe unwrap since we know atmost 8 bits are used
        let bits_used: u8 = bits_used_internal::bits_used_in_byte(last_byte.try_into().unwrap());

        bits_used.into() + 8 * (bytes_used - 1).into()
    }

    fn count_leading_zeroes(self: T) -> u32 {
        BitSize::<T>::bits() - self.bits_used()
    }
}

mod bits_used_internal {
    /// Returns the number of bits used to represent the value in binary representation
    /// # Arguments
    /// * `self` - The value to compute the number of bits used
    /// # Returns
    /// * The number of bits used to represent the value in binary representation
    fn bits_used_in_byte(self: u8) -> u8 {
        if self < 0b100000 {
            if self < 0b1000 {
                if self < 0b100 {
                    if self < 0b10 {
                        if self == 0 {
                            return 0;
                        } else {
                            return 1;
                        };
                    }
                    return 2;
                }

                return 3;
            }

            if self < 0b10000 {
                return 4;
            }

            return 5;
        } else {
            if self < 0b10000000 {
                if self < 0b1000000 {
                    return 6;
                }
                return 7;
            }
            return 8;
        }
    }
}

#[derive(Drop, Debug, PartialEq)]
enum Felt252VecTraitErrors {
    IndexOutOfBound,
    Overflow,
    LengthIsNotSame,
    SizeLessThanCurrentLength
}

#[generate_trait]
impl Felt252VecTraitImpl<
    T,
    +Drop<T>,
    +Copy<T>,
    +Felt252DictValue<T>,
    +Zero<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Mul<T>,
    +Exponentiation<T>,
    +ToBytes<T>,
    +PartialOrd<T>,
    +Into<u8, T>,
    +PartialEq<T>,
> of Felt252VecTrait<T> {
    /// Returns Felt252Vec<T> as a Span<8>, the returned Span is in big endian format
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// # Returns
    /// * A Span<u8> representing bytes conversion of `self` in big endian format
    fn to_be_bytes(ref self: Felt252Vec<T>) -> Span<u8> {
        let mut res: Array<u8> = array![];
        self.remove_trailing_zeroes();

        let mut i = self.len();

        loop {
            if i == 0 {
                break;
            }
            i -= 1;

            res.append_span(self[i].to_be_bytes_padded());
        };

        res.span()
    }

    /// Returns Felt252Vec<T> as a Span<8>, the returned Span is in little endian format
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// # Returns
    /// * A Span<u8> representing bytes conversion of `self` in little endian format
    fn to_le_bytes(ref self: Felt252Vec<T>) -> Span<u8> {
        let mut res: Array<u8> = array![];
        let mut i = 0;

        loop {
            if i == self.len() {
                break;
            }

            if self[i] == Zero::zero() {
                res.append(Zero::zero());
            } else {
                res.append_span(self[i].to_le_bytes());
            }

            i += 1;
        };

        res.span()
    }

    /// Expands a Felt252Vec to a new length by appending zeroes
    ///
    /// This function will mutate the Felt252Vec in-place and will expand its length,
    /// since the default value for Felt252Dict item is 0, all new elements will be set to 0.
    /// If the new length is less than the current length, it will return an error.
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `new_length` the new length of the Felt252Vec
    ///
    /// # Returns
    /// * Result::<(), Felt252VecTraitErrors>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::SizeLessThanCurrentLength if the new length is less than the
    /// current length
    fn expand(ref self: Felt252Vec<T>, new_length: usize) -> Result<(), Felt252VecTraitErrors> {
        if (new_length < self.len) {
            return Result::Err(Felt252VecTraitErrors::SizeLessThanCurrentLength);
        };

        self.len = new_length;

        Result::Ok(())
    }

    /// Sets all elements of the Felt252Vec to zero, mutates the Felt252Vec in-place
    ///
    /// # Arguments
    /// self a ref Felt252Vec<T>
    fn reset(ref self: Felt252Vec<T>) {
        let mut new_vec: Felt252Vec<T> = Default::default();
        new_vec.len = self.len;
        self = new_vec;
    }

    /// Returns the leading zeroes of a Felt252Vec<T>
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    ///
    /// # Returns
    /// * The number of leading zeroes in `self`.
    fn count_leading_zeroes(ref self: Felt252Vec<T>) -> usize {
        let mut i = 0;
        loop {
            if i == self.len || self[i] != Zero::zero() {
                break;
            }

            i += 1;
        };

        i
    }

    /// Resizes the Felt252Vec<T> in-place so that len is equal to new_len.
    ///
    /// This function will mutate the Felt252Vec in-place and will resize its length to the new
    /// length.
    /// If new_len is greater than len, the Vec is extended by the difference, with each additional
    /// slot filled with 0. If new_len is less than len, the Vec is simply truncated from the right.
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `new_len` the new length of the Felt252Vec
    fn resize(ref self: Felt252Vec<T>, new_len: usize) {
        self.len = new_len;
    }


    /// Copies the elements from a Span<u8> into the Felt252Vec<T> in little endian format, in case
    /// of overflow or index being out of bounds, an error is returned
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `index` the index at `self` to start copying from
    /// * `slice` a Span<u8>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::IndexOutOfBound if the index is out of bounds
    /// * Felt252VecTraitErrors::Overflow if the Span is too big to fit in the Felt252Vec
    fn copy_from_bytes_le(
        ref self: Felt252Vec<T>, index: usize, mut slice: Span<u8>
    ) -> Result<(), Felt252VecTraitErrors> {
        if (index >= self.len) {
            return Result::Err(Felt252VecTraitErrors::IndexOutOfBound);
        }

        if ((slice.len() + index) > self.len()) {
            return Result::Err(Felt252VecTraitErrors::Overflow);
        }

        let mut i = index;
        loop {
            let val = slice.pop_front();
            if val.is_none() {
                break;
            }

            // safe unwrap, as in case of none, we will never reach this branch
            self.set(i, (*(val.unwrap())).into());
            i += 1;
        };

        Result::Ok(())
    }

    /// Copies the elements from a Felt252Vec<T> into the Felt252Vec<T> in little endian format, If
    /// length of both Felt252Vecs are not same, it will return an error
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `vec` a ref Felt252Vec<T>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::LengthIsNotSame if the length of both Felt252Vecs are not same
    fn copy_from_vec_le(
        ref self: Felt252Vec<T>, ref vec: Felt252Vec<T>
    ) -> Result<(), Felt252VecTraitErrors> {
        if (vec.len() != self.len) {
            return Result::Err(Felt252VecTraitErrors::LengthIsNotSame);
        }

        self = vec.duplicate();

        Result::Ok(())
    }

    /// Insert elements of Felt252Vec into another Felt252Vec at a given index, in case of overflow
    /// or index being out of bounds, an error is returned
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `idx` the index at `self` to start inserting from
    /// * `vec` a ref Felt252Vec<T>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::IndexOutOfBound if the index is out of bounds
    /// * Felt252VecTraitErrors::Overflow if the Felt252Vec is too big to fit in the Felt252Vec
    fn insert_vec(
        ref self: Felt252Vec<T>, idx: usize, ref vec: Felt252Vec<T>
    ) -> Result<(), Felt252VecTraitErrors> {
        if idx >= self.len() {
            return Result::Err(Felt252VecTraitErrors::IndexOutOfBound);
        }

        if (idx + vec.len > self.len) {
            return Result::Err(Felt252VecTraitErrors::Overflow);
        }

        let stop = idx + vec.len();
        let mut i = idx;
        loop {
            if i == stop {
                break;
            }

            self.set(i, vec[i - idx]);
            i += 1;
        };

        Result::Ok(())
    }


    /// Removes trailing zeroes from a Felt252Vec<T>
    ///
    /// # Arguments
    /// * `input` a ref Felt252Vec<T>
    fn remove_trailing_zeroes(ref self: Felt252Vec<T>) {
        let mut new_len = self.len;
        loop {
            if (new_len == 0) || (self[new_len - 1] != Zero::zero()) {
                break;
            }

            new_len -= 1;
        };

        self.len = new_len;
    }

    /// Pops an element out of the vector, returns Option::None if the vector is empty
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// # Returns
    ///
    /// * Option::Some(T), returns the last element or Option::None if the vector is empty
    fn pop(ref self: Felt252Vec<T>) -> Option<T> {
        if (self.len) == 0 {
            return Option::None;
        }

        let popped_ele = self[self.len() - 1];
        self.len = self.len - 1;
        Option::Some(popped_ele)
    }

    /// takes a Felt252Vec<T> and returns a new Felt252Vec<T> with the same elements
    ///
    /// Note: this is an expensive operation, as it will create a new Felt252Vec
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    ///
    /// # Returns
    /// * A new Felt252Vec<T> with the same elements
    fn duplicate(ref self: Felt252Vec<T>) -> Felt252Vec<T> {
        let mut new_vec = Default::default();

        let mut i: u32 = 0;

        loop {
            if i == self.len {
                break;
            }

            new_vec.push(self[i]);

            i += 1;
        };

        new_vec
    }

    /// Returns a new Felt252Vec<T> with elements starting from `idx` to `idx + len`
    ///
    /// This function will start cloning from `idx` and will clone `len` elements, it will firstly
    /// clone the elements and then return a new Felt252Vec<T>
    /// In case of overflow return Option::None
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `idx` the index to start cloning from
    /// * `len` the length of the clone
    ///
    /// # Returns
    /// * Felt252Vec<T>
    ///
    /// # Panics
    /// * If the index is out of bounds
    ///
    /// Note: this is an expensive operation, as it will create a new Felt252Vec
    fn clone_slice(ref self: Felt252Vec<T>, idx: usize, len: usize) -> Felt252Vec<T> {
        let mut new_vec = Default::default();

        let mut i: u32 = 0;

        loop {
            if i == len {
                break;
            }

            new_vec.push(self[idx + i]);

            i += 1;
        };

        new_vec
    }

    /// Returns whether two Felt252Vec<T> are equal after removing trailing_zeroes
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `rhs` a ref Felt252Vec<T>
    ///
    /// # Returns
    /// * bool, returns true if both Felt252Vecs are equal, false otherwise
    /// TODO: if this utils is only used for testing, then refactor as a test util
    fn equal_remove_trailing_zeroes(ref self: Felt252Vec<T>, ref rhs: Felt252Vec<T>) -> bool {
        let mut lhs = self.duplicate();
        lhs.remove_trailing_zeroes();

        let mut rhs = rhs.duplicate();
        rhs.remove_trailing_zeroes();

        if lhs.len() != rhs.len() {
            return false;
        };

        let mut i = 0;
        loop {
            if i == lhs.len() {
                break true;
            }

            if lhs[i] != rhs[i] {
                break false;
            }

            i += 1;
        }
    }

    /// Fills a Felt252Vec<T> with a given `value` starting from `start_idx` to `start_idx + len`
    /// In case of index out of bounds or overflow, error is returned
    ///
    /// # Arguments
    /// * `self` a ref Felt252Vec<T>
    /// * `start_idx` the index to start filling from
    /// * `len` the length of the fill
    /// * `value` the value to fill the Felt252Vec with
    ///
    /// # Returns
    /// * Result::<(), Felt252VecTraitErrors>
    ///
    /// # Errors
    /// * Felt252VecTraitErrors::IndexOutOfBound if the index is out of bounds
    /// * Felt252VecTraitErrors::Overflow if the Felt252Vec is too big to fit in the Felt252Vec
    fn fill(
        ref self: Felt252Vec<T>, start_idx: usize, len: usize, value: T
    ) -> Result<(), Felt252VecTraitErrors> {
        // Index out of bounds
        if (start_idx >= self.len()) {
            return Result::Err(Felt252VecTraitErrors::IndexOutOfBound);
        }

        // Overflow
        if (start_idx + len > self.len()) {
            return Result::Err(Felt252VecTraitErrors::Overflow);
        }

        let mut i = start_idx;
        loop {
            if i == start_idx + len {
                break;
            }

            self.set(i, value);

            i += 1;
        };

        Result::Ok(())
    }
}

#[cfg(test)]
mod tests {
    use utils::helpers::{BitsUsed, BytesUsedTrait, ToBytes};
    use utils::helpers;

    #[test]
    fn test_u256_to_bytes_array() {
        let value: u256 = 256;

        let bytes_array = helpers::u256_to_bytes_array(value);
        assert(1 == *bytes_array[30], 'wrong conversion');
    }

    #[test]
    fn test_load_word() {
        // No bytes to load
        let res0 = helpers::load_word(0, ArrayTrait::new().span());
        assert(0 == res0, 'res0: wrong load');

        // Single bytes value
        let mut arr1 = ArrayTrait::new();
        arr1.append(0x01);
        let res1 = helpers::load_word(1, arr1.span());
        assert(1 == res1, 'res1: wrong load');

        let mut arr2 = ArrayTrait::new();
        arr2.append(0xff);
        let res2 = helpers::load_word(1, arr2.span());
        assert(255 == res2, 'res2: wrong load');

        // Two byte values
        let mut arr3 = ArrayTrait::new();
        arr3.append(0x01);
        arr3.append(0x00);
        let res3 = helpers::load_word(2, arr3.span());
        assert(256 == res3, 'res3: wrong load');

        let mut arr4 = ArrayTrait::new();
        arr4.append(0xff);
        arr4.append(0xff);
        let res4 = helpers::load_word(2, arr4.span());
        assert(65535 == res4, 'res4: wrong load');

        // Four byte values
        let mut arr5 = ArrayTrait::new();
        arr5.append(0xff);
        arr5.append(0xff);
        arr5.append(0xff);
        arr5.append(0xff);
        let res5 = helpers::load_word(4, arr5.span());
        assert(4294967295 == res5, 'res5: wrong load');

        // 16 bytes values
        let mut arr6 = ArrayTrait::new();
        arr6.append(0xff);
        let mut counter: u128 = 0;
        loop {
            if counter >= 15 {
                break ();
            }
            arr6.append(0xff);
            counter += 1;
        };
        let res6 = helpers::load_word(16, arr6.span());
        assert(340282366920938463463374607431768211455 == res6, 'res6: wrong load');
    }


    #[test]
    fn test_split_word_le() {
        // Test with 0 value and 0 len
        let res0 = helpers::split_word_le(0, 0);
        assert(res0.len() == 0, 'res0: wrong length');

        // Test with single byte value
        let res1 = helpers::split_word_le(1, 1);
        assert(res1.len() == 1, 'res1: wrong length');
        assert(*res1[0] == 1, 'res1: wrong value');

        // Test with two byte value
        let res2 = helpers::split_word_le(257, 2); // 257 = 0x0101
        assert(res2.len() == 2, 'res2: wrong length');
        assert(*res2[0] == 1, 'res2: wrong value at index 0');
        assert(*res2[1] == 1, 'res2: wrong value at index 1');

        // Test with four byte value
        let res3 = helpers::split_word_le(67305985, 4); // 67305985 = 0x04030201
        assert(res3.len() == 4, 'res3: wrong length');
        assert(*res3[0] == 1, 'res3: wrong value at index 0');
        assert(*res3[1] == 2, 'res3: wrong value at index 1');
        assert(*res3[2] == 3, 'res3: wrong value at index 2');
        assert(*res3[3] == 4, 'res3: wrong value at index 3');

        // Test with 16 byte value (u128 max value)
        let max_u128: u256 = 340282366920938463463374607431768211454; // u128 max value - 1
        let res4 = helpers::split_word_le(max_u128, 16);
        assert(res4.len() == 16, 'res4: wrong length');
        assert(*res4[0] == 0xfe, 'res4: wrong MSB value');

        let mut counter: usize = 1;
        loop {
            if counter >= 16 {
                break ();
            }
            assert(*res4[counter] == 0xff, 'res4: wrong value at index');
            counter += 1;
        };
    }

    #[test]
    fn test_split_word() {
        // Test with 0 value and 0 len
        let mut dst0: Array<u8> = ArrayTrait::new();
        helpers::split_word(0, 0, ref dst0);
        assert(dst0.len() == 0, 'dst0: wrong length');

        // Test with single byte value
        let mut dst1: Array<u8> = ArrayTrait::new();
        helpers::split_word(1, 1, ref dst1);
        assert(dst1.len() == 1, 'dst1: wrong length');
        assert(*dst1[0] == 1, 'dst1: wrong value');

        // Test with two byte value
        let mut dst2: Array<u8> = ArrayTrait::new();
        helpers::split_word(257, 2, ref dst2); // 257 = 0x0101
        assert(dst2.len() == 2, 'dst2: wrong length');
        assert(*dst2[0] == 1, 'dst2: wrong value at index 0');
        assert(*dst2[1] == 1, 'dst2: wrong value at index 1');

        // Test with four byte value
        let mut dst3: Array<u8> = ArrayTrait::new();
        helpers::split_word(16909060, 4, ref dst3); // 16909060 = 0x01020304
        assert(dst3.len() == 4, 'dst3: wrong length');
        assert(*dst3[0] == 1, 'dst3: wrong value at index 0');
        assert(*dst3[1] == 2, 'dst3: wrong value at index 1');
        assert(*dst3[2] == 3, 'dst3: wrong value at index 2');
        assert(*dst3[3] == 4, 'dst3: wrong value at index 3');

        // Test with 16 byte value (u128 max value)
        let max_u128: u256 = 340282366920938463463374607431768211454; // u128 max value -1
        let mut dst4: Array<u8> = ArrayTrait::new();
        helpers::split_word(max_u128, 16, ref dst4);
        assert(dst4.len() == 16, 'dst4: wrong length');
        let mut counter: usize = 0;
        assert(*dst4[15] == 0xfe, 'dst4: wrong LSB value');
        loop {
            if counter >= 15 {
                break ();
            }
            assert(*dst4[counter] == 0xff, 'dst4: wrong value at index');
            counter += 1;
        };
    }

    mod test_array_ext {
        use utils::helpers::{ArrayExtTrait};
        #[test]
        fn test_append_n() {
            // Given
            let mut original: Array<u8> = array![1, 2, 3, 4];

            // When
            original.append_n(9, 3);

            // Then
            assert(original == array![1, 2, 3, 4, 9, 9, 9], 'append_n failed');
        }

        #[test]
        fn test_append_unique() {
            let mut arr = array![1, 2, 3];
            arr.append_unique(4);
            assert(arr == array![1, 2, 3, 4], 'should have appended');
            arr.append_unique(2);
            assert(arr == array![1, 2, 3, 4], 'shouldnt have appended');
        }
    }

    mod u8_test {
        use utils::helpers::BitsUsed;
        use utils::math::Bitshift;

        #[test]
        fn test_bits_used() {
            assert_eq!(0x00_u8.bits_used(), 0);
            let mut value: u8 = 0xff;
            let mut i = 8;
            loop {
                assert_eq!(value.bits_used(), i);
                if i == 0 {
                    break;
                };
                value = value.shr(1);

                i -= 1;
            };
        }
    }

    mod u32_test {
        use utils::helpers::Bitshift;
        use utils::helpers::{BitsUsed, BytesUsedTrait, ToBytes, FromBytes};

        #[test]
        fn test_u32_from_be_bytes() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62];
            let res: Option<u32> = input.span().from_be_bytes();

            assert(res.is_some(), 'should have a value');
            assert(res.unwrap() == 0xf4321562, 'wrong result value');
        }

        #[test]
        fn test_u32_from_be_bytes_too_big() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62, 0x01];
            let res: Option<u32> = input.span().from_be_bytes();

            assert(res.is_none(), 'should not have a value');
        }

        #[test]
        fn test_u32_to_bytes_full() {
            let input: u32 = 0xf4321562;
            let res: Span<u8> = input.to_be_bytes();

            assert(res.len() == 4, 'wrong result length');
            assert(*res[0] == 0xf4, 'wrong result value');
            assert(*res[1] == 0x32, 'wrong result value');
            assert(*res[2] == 0x15, 'wrong result value');
            assert(*res[3] == 0x62, 'wrong result value');
        }

        #[test]
        fn test_u32_to_bytes_partial() {
            let input: u32 = 0xf43215;
            let res: Span<u8> = input.to_be_bytes();

            assert(res.len() == 3, 'wrong result length');
            assert(*res[0] == 0xf4, 'wrong result value');
            assert(*res[1] == 0x32, 'wrong result value');
            assert(*res[2] == 0x15, 'wrong result value');
        }


        #[test]
        fn test_u32_to_bytes_leading_zeros() {
            let input: u32 = 0x00f432;
            let res: Span<u8> = input.to_be_bytes();

            assert(res.len() == 2, 'wrong result length');
            assert(*res[0] == 0xf4, 'wrong result value');
            assert(*res[1] == 0x32, 'wrong result value');
        }

        #[test]
        fn test_u32_to_be_bytes_padded() {
            let input: u32 = 7;
            let result = input.to_be_bytes_padded();
            let expected = array![0x0, 0x0, 0x0, 7].span();

            assert_eq!(result, expected);
        }


        #[test]
        fn test_u32_bytes_used() {
            assert_eq!(0x00_u32.bytes_used(), 0);
            let mut value: u32 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 4 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u32_bytes_used_leading_zeroes() {
            let len: u32 = 0x001234;
            let bytes_count = len.bytes_used();

            assert(bytes_count == 2, 'wrong bytes count');
        }
    }

    mod u64_test {
        use utils::helpers::Bitshift;
        use utils::helpers::U64Trait;
        use utils::helpers::{BitsUsed, BytesUsedTrait, ToBytes};


        #[test]
        fn test_u64_bytes_used() {
            assert_eq!(0x00_u64.bytes_used(), 0);
            let mut value: u64 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 8 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u64_to_be_bytes_padded() {
            let input: u64 = 7;
            let result = input.to_be_bytes_padded();
            let expected = array![0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 7].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u64_trailing_zeroes() {
            /// bit len is 3, and trailing zeroes are 2
            let input: u64 = 4;
            let result = input.count_trailing_zeroes();
            let expected = 2;

            assert_eq!(result, expected);
        }


        #[test]
        fn test_u64_leading_zeroes() {
            /// bit len is 3, and leading zeroes are 64 - 3 = 61
            let input: u64 = 7;
            let result = input.count_leading_zeroes();
            let expected = 61;

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u64_bits_used() {
            let input: u64 = 7;
            let result = input.bits_used();
            let expected = 3;

            assert_eq!(result, expected);
        }
    }

    mod u128_test {
        use core::integer::BoundedInt;
        use utils::helpers::Bitshift;
        use utils::helpers::U128Trait;
        use utils::helpers::{BitsUsed, BytesUsedTrait, ToBytes};

        #[test]
        fn test_u128_bytes_used() {
            assert_eq!(0x00_u128.bytes_used(), 0);
            let mut value: u128 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 16 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u128_to_bytes_full() {
            let input: u128 = BoundedInt::max();
            let result: Span<u8> = input.to_be_bytes();
            let expected = array![
                255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
            ]
                .span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u128_to_bytes_partial() {
            let input: u128 = 0xf43215;
            let result: Span<u8> = input.to_be_bytes();
            let expected = array![0xf4, 0x32, 0x15].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u128_to_bytes_padded() {
            let input: u128 = 0xf43215;
            let result: Span<u8> = input.to_be_bytes_padded();
            let expected = array![
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf4, 0x32, 0x15
            ]
                .span();

            assert_eq!(result, expected);
        }
    }

    mod u256_test {
        use utils::helpers::Bitshift;
        use utils::helpers::U256Trait;
        use utils::helpers::{BitsUsed, BytesUsedTrait};

        #[test]
        fn test_reverse_bytes_u256() {
            let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
            let res = value.reverse_endianness();
            assert(
                res == 0x0000450000DEFA0000200400000000ADDE00000077000000E5000000FFFFFFFA,
                'reverse mismatch'
            );
        }

        #[test]
        fn test_split_u256_into_u64_little() {
            let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
            let ((high_h, low_h), (high_l, low_l)) = value.split_into_u64_le();
            assert(high_h == 0xDE00000077000000, 'split mismatch');
            assert(low_h == 0xE5000000FFFFFFFA, 'split mismatch');
            assert(high_l == 0x0000450000DEFA00, 'split mismatch');
            assert(low_l == 0x00200400000000AD, 'split mismatch');
        }

        #[test]
        fn test_u256_bytes_used() {
            assert_eq!(0x00_u256.bytes_used(), 0);
            let mut value: u256 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 32 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u256_leading_zeroes() {
            /// bit len is 3, and leading zeroes are 256 - 3 = 253
            let input: u256 = 7;
            let result = input.count_leading_zeroes();
            let expected = 253;

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u64_bits_used() {
            let input: u256 = 7;
            let result = input.bits_used();
            let expected = 3;

            assert_eq!(result, expected);
        }
    }


    mod bytearray_test {
        use utils::helpers::ByteArrayExTrait;


        #[test]
        fn test_pack_bytes_ge_bytes31() {
            let mut arr = array![
                0x01,
                0x02,
                0x03,
                0x04,
                0x05,
                0x06,
                0x07,
                0x08,
                0x09,
                0x0A,
                0x0B,
                0x0C,
                0x0D,
                0x0E,
                0x0F,
                0x10,
                0x11,
                0x12,
                0x13,
                0x14,
                0x15,
                0x16,
                0x17,
                0x18,
                0x19,
                0x1A,
                0x1B,
                0x1C,
                0x1D,
                0x1E,
                0x1F,
                0x20,
                0x21 // 33 elements
            ];

            let res = ByteArrayExTrait::from_bytes(arr.span());

            // Ensure that the result is complete and keeps the same order
            let mut i = 0;
            loop {
                if i == arr.len() {
                    break;
                };
                assert(*arr[i] == res[i], 'byte mismatch');
                i += 1;
            };
        }

        #[test]
        fn test_bytearray_append_span_bytes() {
            let bytes = array![0x01, 0x02, 0x03, 0x04];
            let mut byte_arr: ByteArray = Default::default();
            byte_arr.append_byte(0xFF);
            byte_arr.append_byte(0xAA);
            byte_arr.append_span_bytes(bytes.span());
            assert(byte_arr.len() == 6, 'wrong length');
            assert(byte_arr[0] == 0xFF, 'wrong value');
            assert(byte_arr[1] == 0xAA, 'wrong value');
            assert(byte_arr[2] == 0x01, 'wrong value');
            assert(byte_arr[3] == 0x02, 'wrong value');
            assert(byte_arr[4] == 0x03, 'wrong value');
            assert(byte_arr[5] == 0x04, 'wrong value');
        }

        #[test]
        fn test_byte_array_into_bytes() {
            let input = array![
                0x01,
                0x02,
                0x03,
                0x04,
                0x05,
                0x06,
                0x07,
                0x08,
                0x09,
                0x0A,
                0x0B,
                0x0C,
                0x0D,
                0x0E,
                0x0F,
                0x10,
                0x11,
                0x12,
                0x13,
                0x14,
                0x15,
                0x16,
                0x17,
                0x18,
                0x19,
                0x1A,
                0x1B,
                0x1C,
                0x1D,
                0x1E,
                0x1F,
                0x20,
                0x21 // 33 elements
            ];
            let byte_array = ByteArrayExTrait::from_bytes(input.span());
            let res = byte_array.into_bytes();

            // Ensure that the elements are correct
            assert(res == input.span(), 'bytes mismatch');
        }

        #[test]
        fn test_pack_bytes_le_bytes31() {
            let mut arr = array![0x11, 0x22, 0x33, 0x44];
            let res = ByteArrayExTrait::from_bytes(arr.span());

            // Ensure that the result is complete and keeps the same order
            let mut i = 0;
            loop {
                if i == arr.len() {
                    break;
                };
                assert(*arr[i] == res[i], 'byte mismatch');
                i += 1;
            };
        }


        #[test]
        fn test_bytearray_to_64_words_partial() {
            let input = ByteArrayExTrait::from_bytes(
                array![0x01, 0x02, 0x03, 0x04, 0x05, 0x06].span()
            );
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();
            assert(pending_word == 6618611909121, 'wrong pending word');
            assert(pending_word_len == 6, 'wrong pending word length');
            assert(u64_words.len() == 0, 'wrong u64 words length');
        }

        #[test]
        fn test_bytearray_to_64_words_full() {
            let input = ByteArrayExTrait::from_bytes(
                array![0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08].span()
            );
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();

            assert(pending_word == 0, 'wrong pending word');
            assert(pending_word_len == 0, 'wrong pending word length');
            assert(u64_words.len() == 1, 'wrong u64 words length');
            assert(*u64_words[0] == 578437695752307201, 'wrong u64 words length');
        }
    }

    mod span_u8_test {
        use utils::helpers::{U8SpanExTrait, ToBytes};

        #[test]
        fn test_span_u8_to_64_words_partial() {
            let mut input: Span<u8> = array![0x01, 0x02, 0x03, 0x04, 0x05, 0x06].span();
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();
            assert(pending_word == 6618611909121, 'wrong pending word');
            assert(pending_word_len == 6, 'wrong pending word length');
            assert(u64_words.len() == 0, 'wrong u64 words length');
        }

        #[test]
        fn test_span_u8_to_64_words_full() {
            let mut input: Span<u8> = array![0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08].span();
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();

            assert(pending_word == 0, 'wrong pending word');
            assert(pending_word_len == 0, 'wrong pending word length');
            assert(u64_words.len() == 1, 'wrong u64 words length');
            assert(*u64_words[0] == 578437695752307201, 'wrong u64 words length');
        }


        #[test]
        fn test_compute_msg_hash() {
            let msg = 0xabcdef_u32.to_be_bytes();
            let expected_hash = 0x800d501693feda2226878e1ec7869eef8919dbc5bd10c2bcd031b94d73492860;
            let hash = msg.compute_keccak256_hash();

            assert_eq!(hash, expected_hash);
        }

        #[test]
        fn test_right_padded_span_offset_0() {
            let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.slice_right_padded(0, 10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_right_padded_span_offset_4() {
            let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = array![0x04, 0x05, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.slice_right_padded(4, 10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_right_padded_span_offset_greater_than_span_len() {
            let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = array![0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.slice_right_padded(6, 10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_left_with_zeroes_len_10() {
            let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = array![0x0, 0x0, 0x0, 0x0, 0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let result = span.pad_left_with_zeroes(10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_left_with_zeroes_len_equal_than_data_len() {
            let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
            let expected = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
            let result = span.pad_left_with_zeroes(10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_left_with_zeroes_len_equal_than_smaller_len() {
            let span = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
            let expected = array![0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8].span();
            let result = span.pad_left_with_zeroes(9);

            assert_eq!(result, expected);
        }
    }


    mod felt252_vec_u8_test {
        use alexandria_data_structures::vec::{VecTrait, Felt252Vec, Felt252VecImpl};
        use utils::helpers::{Felt252VecTrait};

        #[test]
        fn test_felt252_vec_u8_to_bytes() {
            let mut vec: Felt252Vec<u8> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(2);
            vec.push(3);

            let result = vec.to_le_bytes();
            let expected = array![0, 1, 2, 3].span();

            assert_eq!(result, expected);
        }
    }

    mod felt252_vec_u64_test {
        use alexandria_data_structures::vec::{VecTrait, Felt252Vec, Felt252VecImpl};
        use utils::helpers::{Felt252VecTrait};

        #[test]
        fn test_felt252_vec_u64_words64_to_le_bytes() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(2);
            vec.push(3);

            let result = vec.to_le_bytes();
            let expected = array![0, 1, 2, 3].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_felt252_vec_u64_words64_to_be_bytes() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(2);
            vec.push(3);

            let result = vec.to_be_bytes();
            let expected = array![
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                3,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                2,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0
            ]
                .span();

            assert_eq!(result, expected);
        }
    }

    mod felt252_vec_test {
        use alexandria_data_structures::vec::{VecTrait, Felt252Vec, Felt252VecImpl};
        use utils::helpers::{Felt252VecTrait, Felt252VecTraitErrors};

        #[test]
        fn test_felt252_vec_expand() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.expand(4).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_expand_fail() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            let result = vec.expand(1);
            assert_eq!(result, Result::Err(Felt252VecTraitErrors::SizeLessThanCurrentLength));
        }

        #[test]
        fn test_felt252_vec_reset() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.reset();

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_count_leading_zeroes() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(0);
            vec.push(0);
            vec.push(1);

            let result = vec.count_leading_zeroes();

            assert_eq!(result, 3);
        }


        #[test]
        fn test_felt252_vec_resize_len_greater_than_current_len() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.expand(4).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_resize_len_less_than_current_len() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);
            vec.push(0);
            vec.push(0);

            vec.resize(2);

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_felt252_vec_len_0() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(0);
            vec.push(1);

            vec.resize(0);

            assert_eq!(vec.len(), 0);
        }

        #[test]
        fn test_copy_from_bytes_le_size_equal_to_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = array![1, 2, 3, 4].span();
            vec.copy_from_bytes_le(0, bytes).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 4);
            assert_eq!(vec.pop().unwrap(), 3);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_copy_from_bytes_le_size_less_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = array![1, 2].span();
            vec.copy_from_bytes_le(2, bytes).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_copy_from_bytes_le_size_greater_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = array![1, 2, 3, 4].span();
            let result = vec.copy_from_bytes_le(2, bytes);

            assert_eq!(result, Result::Err(Felt252VecTraitErrors::Overflow));
        }

        #[test]
        fn test_copy_from_bytes_index_out_of_bound() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let bytes = array![1, 2].span();
            let result = vec.copy_from_bytes_le(4, bytes);

            assert_eq!(result, Result::Err(Felt252VecTraitErrors::IndexOutOfBound));
        }

        #[test]
        fn test_copy_from_vec_le() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            vec.copy_from_vec_le(ref vec2).unwrap();

            assert_eq!(vec.len, 2);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_copy_from_vec_le_not_equal_lengths() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);

            let result = vec.copy_from_vec_le(ref vec2);

            assert_eq!(result, Result::Err(Felt252VecTraitErrors::LengthIsNotSame));
        }


        #[test]
        fn test_insert_vec_size_equal_to_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            vec.insert_vec(0, ref vec2).unwrap();

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_insert_vec_size_less_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            vec.insert_vec(2, ref vec2).unwrap();

            assert_eq!(vec.len(), 4);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_insert_vec_size_greater_than_vec_size() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(2).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);
            vec2.push(3);
            vec2.push(4);

            let result = vec.insert_vec(1, ref vec2);
            assert_eq!(result, Result::Err(Felt252VecTraitErrors::Overflow));
        }

        #[test]
        fn test_insert_vec_index_out_of_bound() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            let result = vec.insert_vec(4, ref vec2);
            assert_eq!(result, Result::Err(Felt252VecTraitErrors::IndexOutOfBound));
        }

        #[test]
        fn test_remove_trailing_zeroes_le() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);
            vec.push(0);
            vec.push(0);

            vec.remove_trailing_zeroes();

            assert_eq!(vec.len(), 2);
            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
        }

        #[test]
        fn test_pop() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            assert_eq!(vec.pop().unwrap(), 2);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop(), Option::<u64>::None);
        }

        #[test]
        fn test_duplicate() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            let mut vec2 = vec.duplicate();

            assert_eq!(vec.len(), vec2.len());
            assert_eq!(vec.pop(), vec2.pop());
            assert_eq!(vec.pop(), vec2.pop());
            assert_eq!(vec.pop().is_none(), true);
            assert_eq!(vec2.pop().is_none(), true);
        }

        #[test]
        fn test_clone_slice() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            let mut vec2 = vec.clone_slice(1, 1);

            assert_eq!(vec2.len(), 1);
            assert_eq!(vec2.pop().unwrap(), 2);
        }

        #[test]
        fn test_equal() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.push(1);
            vec.push(2);

            let mut vec2: Felt252Vec<u64> = Default::default();
            vec2.push(1);
            vec2.push(2);

            assert!(vec.equal_remove_trailing_zeroes(ref vec2));
            vec2.pop().unwrap();
            assert!(!vec.equal_remove_trailing_zeroes(ref vec2));
        }

        #[test]
        fn test_fill() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            vec.fill(1, 3, 1).unwrap();

            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 1);
            assert_eq!(vec.pop().unwrap(), 0);
        }

        #[test]
        fn test_fill_overflow() {
            let mut vec: Felt252Vec<u64> = Default::default();
            vec.expand(4).unwrap();

            assert_eq!(vec.fill(4, 0, 1), Result::Err(Felt252VecTraitErrors::IndexOutOfBound));
            assert_eq!(vec.fill(2, 4, 1), Result::Err(Felt252VecTraitErrors::Overflow));
        }
    }
}
