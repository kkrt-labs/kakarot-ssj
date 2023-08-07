use array::ArrayTrait;
use array::SpanTrait;
use traits::{Into, TryInto};
use kakarot::utils::constants;
use option::OptionTrait;
use debug::PrintTrait;

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
        return 340282366920938463463374607431768211456;
    } else if i == 1 {
        return 1329227995784915872903807060280344576;
    } else if i == 2 {
        return 5192296858534827628530496329220096;
    } else if i == 3 {
        return 20282409603651670423947251286016;
    } else if i == 4 {
        return 79228162514264337593543950336;
    } else if i == 5 {
        return 309485009821345068724781056;
    } else if i == 6 {
        return 1208925819614629174706176;
    } else if i == 7 {
        return 4722366482869645213696;
    } else if i == 8 {
        return 18446744073709551616;
    } else if i == 9 {
        return 72057594037927936;
    } else if i == 10 {
        return 281474976710656;
    } else if i == 11 {
        return 1099511627776;
    } else if i == 12 {
        return 4294967296;
    } else if i == 13 {
        return 16777216;
    } else if i == 14 {
        return 65536;
    } else if i == 15 {
        return 256;
    } else {
        return 1;
    }
}


/// Splits a u256 into `len` bytes, big-endian, and appends the result to `dst`.
fn split_word(mut value: u256, mut len: usize, ref dst: Array<u8>) {
    let little_endian = split_word_little(value, len);
    let big_endian = reverse_array(little_endian.span());
    concat_array(ref dst, big_endian.span());
}

/// Splits a u256 into `len` bytes, little-endian, and returns the bytes array.
fn split_word_little(mut value: u256, mut len: usize) -> Array<u8> {
    let mut dst: Array<u8> = ArrayTrait::new();
    let base = 256;
    let bound = 256;
    loop {
        if len == 0 {
            assert(value == 0, 'split_words:value not 0');
            break ();
        }

        let low_part = (value % constants::FELT252_PRIME) % base;
        dst.append(low_part.try_into().unwrap());

        value = (value - low_part) / 256;
        len -= 1;
    };
    dst
}

/// Splits a u256 into 16 bytes, big-endien, and appends the result to `dst`.
fn split_word_128(value: u256, ref dst: Array<u8>) {
    split_word(value, 16, ref dst)
}


/// Loads a sequence of bytes into a single u128 in big-endian
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

/// Converts a u256 to a bytes array represented by an array of felts (1 felt represents 1 byte).
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
        bytes_arr.append((value.low % 256).try_into().unwrap());
        value.low /= 256;
        counter += 1;
    };

    let mut counter = 0;
    // high part
    loop {
        if counter == 16 {
            break ();
        }
        bytes_arr.append((value.high % 256).try_into().unwrap());
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


// Concatenates two arrays by adding the elements of arr2 to arr1.
fn concat_array<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
    ref arr1: Array<T>, mut arr2: Span<T>
) {
    loop {
        if arr2.len() == 0 {
            break ();
        }
        let elem = *arr2.pop_front().unwrap();
        arr1.append(elem);
    }
}

/// Reverses an array
fn reverse_array<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(src: Span<T>) -> Array<T> {
    let mut counter = src.len();
    let mut dst: Array<T> = ArrayTrait::new();
    loop {
        if counter == 0 {
            break ();
        }
        dst.append(*src[counter - 1]);
        counter -= 1;
    };
    dst
}
