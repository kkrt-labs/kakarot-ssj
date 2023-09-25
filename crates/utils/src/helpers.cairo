use debug::PrintTrait;
use starknet::{EthAddress, EthAddressIntoFelt252};
use cmp::min;
use utils::constants::{
    POW_256_0_U256, POW_256_1_U256, POW_256_2_U256, POW_256_3_U256, POW_256_4_U256, POW_256_5_U256,
    POW_256_6_U256, POW_256_7_U256, POW_256_8_U256, POW_256_9_U256, POW_256_10_U256,
    POW_256_11_U256, POW_256_12_U256, POW_256_13_U256, POW_256_14_U256, POW_256_15_U256,
    POW_256_16_U256,
};
use keccak::u128_split;


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
        return POW_256_16_U256;
    } else if i == 1 {
        return POW_256_15_U256;
    } else if i == 2 {
        return POW_256_14_U256;
    } else if i == 3 {
        return POW_256_13_U256;
    } else if i == 4 {
        return POW_256_12_U256;
    } else if i == 5 {
        return POW_256_11_U256;
    } else if i == 6 {
        return POW_256_10_U256;
    } else if i == 7 {
        return POW_256_9_U256;
    } else if i == 8 {
        return POW_256_8_U256;
    } else if i == 9 {
        return POW_256_7_U256;
    } else if i == 10 {
        return POW_256_6_U256;
    } else if i == 11 {
        return POW_256_5_U256;
    } else if i == 12 {
        return POW_256_4_U256;
    } else if i == 13 {
        return POW_256_3_U256;
    } else if i == 14 {
        return POW_256_2_U256;
    } else if i == 15 {
        return POW_256_1_U256;
    } else {
        return POW_256_0_U256;
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
    let word_be = ArrayExtensionTrait::reverse(word_le.span());
    ArrayExtensionTrait::concat(ref dst, word_be.span());
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
            break ();
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
impl ArrayExtension<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>> of ArrayExtensionTrait<T> {
    // Concatenates two arrays by adding the elements of arr2 to arr1.
    fn concat(ref self: Array<T>, mut arr2: Span<T>) {
        loop {
            match arr2.pop_front() {
                Option::Some(elem) => self.append(*elem),
                Option::None => {
                    break;
                }
            };
        }
    }

    /// Reverses an array
    fn reverse(self: Span<T>) -> Array<T> {
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
    fn append_n(ref self: Array<T>, value: T, mut n: usize) {
        loop {
            if n == 0 {
                break;
            }

            self.append(value);

            n -= 1;
        };
    }
}

#[generate_trait]
impl SpanExtension of SpanExtensionTrait {
    /// Pads a span of bytes with zeroes on the right.
    ///
    /// It creates a new `Array<u8>` instance and clones each element of the input span to it,
    /// and then adds the required amount of zeroes.
    ///
    /// # Arguments
    ///
    /// * `self` - The `Span<u8>` instance to pad with zeroes.
    /// * `n_zeroes` - The number of zeroes to add to the right of the span.
    ///
    /// # Returns
    ///
    /// A new `Span<u8>` instance which has a length equal to the length of the input
    /// span plus the number of zeroes specified.
    fn clone_pad_right(self: Span<u8>, n_zeroes: usize) -> Span<u8> {
        let mut res: Array<u8> = array![];
        let mut i = 0;
        loop {
            if i == self.len() {
                break;
            }
            res.append(*self[i]);
            i += 1;
        };
        let mut i = 0;
        loop {
            if i == n_zeroes {
                break ();
            }
            res.append(0);
            i += 1;
        };
        res.span()
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
