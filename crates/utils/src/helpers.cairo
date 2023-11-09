use cmp::min;
use core::hash::{HashStateExTrait, HashStateTrait};
use core::pedersen::{HashState, PedersenTrait};

use integer::U32TryIntoNonZero;
use integer::u32_as_non_zero;
use keccak::{cairo_keccak, u128_split};
use starknet::{EthAddress, EthAddressIntoFelt252, ContractAddress, ClassHash};
use traits::DivRem;
use utils::constants::{
    POW_256_0, POW_256_1, POW_256_2, POW_256_3, POW_256_4, POW_256_5, POW_256_6, POW_256_7,
    POW_256_8, POW_256_9, POW_256_10, POW_256_11, POW_256_12, POW_256_13, POW_256_14, POW_256_15,
    POW_256_16,
};
use utils::constants::{CONTRACT_ADDRESS_PREFIX, MAX_ADDRESS};
use utils::math::{Bitshift, WrappingBitshift};
use utils::num::{Zero, One, SizeOf};
use utils::traits::{U256TryIntoContractAddress, EthAddressIntoU256};
/// Ceils a number of bits to the next word (32 bytes)
///
/// # Arguments
/// * `bytes_len` - The number of bits to ceil
///
/// # Returns
/// The number of bytes that are needed to store `bytes_len` bits in 32-bytes words.
///
/// # Examples
/// ceil_bytes_len_to_next_32_bytes_word(2) = 32
/// ceil_bytes_len_to_next_32_bytes_word(34) = 64
fn ceil_bytes_len_to_next_32_bytes_word(bytes_len: usize) -> usize {
    let q = (bytes_len + 31) / 32;
    return q * 32;
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

/// Splits a u256 into 16 bytes, big-endien, and appends the result to `dst`.
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
        }
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

    fn append_span<+Clone<T>>(ref self: Array<T>, mut span: Span<T>) {
        loop {
            match span.pop_front() {
                Option::Some(current) => { self.append(current.clone()); },
                Option::None => { break; }
            };
        }
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
}

#[generate_trait]
impl U8SpanExImpl of U8SpanExTrait {
    /// Transforms a Span<u8> into an Array of u64 full words, a pending u64 word and its length in bytes
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
        // We might want to regroup every computation into a single loop with appropriate `if` branching
        // For optimisation
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
}


#[generate_trait]
impl BytesImpl of BytesTrait {
    // keccack256 on a bytes message
    fn compute_keccak256_hash(self: Span<u8>) -> u256 {
        let (mut keccak_input, last_input_word, last_input_num_bytes) = self.to_u64_words();
        let msg_hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes)
            .reverse_endianness();

        msg_hash
    }
}

#[generate_trait]
impl U32Impl of U32Trait {
    /// Packs 4 bytes into a u32
    /// # Arguments
    /// * `input` a Span<u8> of len <=4
    /// # Returns
    /// * Option::Some(u32) if the operation succeeds
    /// * Option::None otherwise
    fn from_bytes(input: Span<u8>) -> Option<u32> {
        let len = input.len();
        if len == 0 {
            return Option::None;
        }
        if len > 4 {
            return Option::None;
        }
        let offset: u32 = len - 1;
        let mut result: u32 = 0;
        let mut i: u32 = 0;
        loop {
            if i == len {
                break ();
            }
            let byte: u32 = (*input.at(i)).into();
            result += byte.shl(8 * (offset - i));

            i += 1;
        };
        Option::Some(result)
    }

    /// Unpacks a u32 into an array of bytes
    /// # Arguments
    /// * `self` a `u32` value.
    /// # Returns
    /// * The bytes array representation of the value.
    fn to_bytes(mut self: u32) -> Span<u8> {
        let bytes_used: u32 = self.bytes_used().into();
        let mut bytes: Array<u8> = Default::default();
        let mut i = 0;
        loop {
            if i == bytes_used {
                break ();
            }
            let val = self.shr(8 * (bytes_used.try_into().unwrap() - i - 1));
            bytes.append((val & 0xFF).try_into().unwrap());
            i += 1;
        };

        bytes.span()
    }

    /// Returns the number of bytes used to represent a `u32` value.
    /// # Arguments
    /// * `self` - The value to check.
    /// # Returns
    /// The number of bytes used to represent the value.
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
            if self < 0x1000000 { // 256^6
                return 3;
            }
            return 4;
        }
    }
}

#[generate_trait]
impl U128Impl of U128Trait {
    /// Packs 16 bytes into a u128
    /// # Arguments
    /// * `input` a Span<u8> of len <=16
    /// # Returns
    /// * Option::Some(u128) if the operation succeeds
    /// * Option::None otherwise
    fn from_bytes(input: Span<u8>) -> Option<u128> {
        let len = input.len();
        if len == 0 {
            return Option::None;
        }
        if len > 16 {
            return Option::None;
        }
        let offset: u32 = len - 1;
        let mut result: u128 = 0;
        let mut i: u32 = 0;
        loop {
            if i == len {
                break ();
            }
            let byte: u128 = (*input.at(i)).into();
            result += byte.shl((8 * (offset - i)).into());

            i += 1;
        };
        Option::Some(result)
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

    // Returns a u256 representation as bytes: `Span<u8>`
    // This slice is padded of zeros if the u256 representation does not take up to 32 bytes
    fn to_bytes(self: u256) -> Span<u8> {
        let bytes_used: u256 = 32;
        let mut bytes: Array<u8> = Default::default();
        let mut i = 0;
        loop {
            if i == bytes_used {
                break ();
            }
            let val = self.shr(8 * (bytes_used - i - 1));
            bytes.append((val & 0xFF).try_into().unwrap());
            i += 1;
        };

        bytes.span()
    }

    /// Packs 32 bytes into a u128
    /// # Arguments
    /// * `input` a Span<u8> of len <=32
    /// # Returns
    /// * Option::Some(u128) if the operation succeeds
    /// * Option::None otherwise
    fn from_bytes(input: Span<u8>) -> Option<u256> {
        let len = input.len();
        if len == 0 {
            return Option::None;
        }
        if len > 32 {
            return Option::None;
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


    /// Transforms a ByteArray into an Array of u64 full words, a pending u64 word and its length in bytes
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
        // We might want to regroup every computation into a single loop with appropriate `if` branching
        // For optimisation
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
    deployer: ContractAddress, evm_address: EthAddress, class_hash: ClassHash
) -> ContractAddress {
    // Deployer is always Kakarot Core
    // pedersen(a1, a2, a3) is defined as:
    // pedersen(pedersen(pedersen(a1, a2), a3), len([a1, a2, a3]))
    // https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/hash_state.py#L6
    // https://github.com/xJonathanLEI/starknet-rs/blob/master/starknet-core/src/crypto.rs#L49
    // Constructor Calldata
    // For an Account, the constructor calldata is:
    // [kakarot_address, evm_address]
    let constructor_calldata_hash = PedersenTrait::new(0)
        .update_with(deployer)
        .update_with(evm_address)
        .update(2)
        .finalize();

    let hash = PedersenTrait::new(0)
        .update_with(CONTRACT_ADDRESS_PREFIX)
        .update_with(deployer)
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
impl EthAddressExtTrait of EthAddressExt {
    fn to_bytes(self: EthAddress) -> Span<u8> {
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

        bytes.span()
    }
}
