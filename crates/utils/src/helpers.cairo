use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::cmp::min;
use core::hash::{HashStateExTrait, HashStateTrait};

use core::panic_with_felt252;
use core::pedersen::PedersenTrait;
use core::starknet::{EthAddress, ContractAddress, ClassHash};
use core::traits::TryInto;
use core::traits::{DivRem};
use crate::constants::{CONTRACT_ADDRESS_PREFIX, MAX_ADDRESS};
use crate::constants::{POW_2, POW_256_1, POW_256_REV};
use crate::math::{Bitshift, WrappingBitshift};

use crate::traits::array::{ArrayExtTrait};
use crate::traits::{U256TryIntoContractAddress, EthAddressIntoU256, BoolIntoNumeric};

/// Splits a u128 into two u64 parts, representing the high and low parts of the input.
///
/// # Arguments
/// * `input` - The u128 value to be split.
///
/// # Returns
/// A tuple containing two u64 values, where the first element is the high part of the input
/// and the second element is the low part of the input.
pub fn u128_split(input: u128) -> (u64, u64) {
    let (high, low) = core::integer::u128_safe_divmod(
        input, 0x10000000000000000_u128.try_into().unwrap()
    );

    (high.try_into().unwrap(), low.try_into().unwrap())
}


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
pub fn ceil32(value: usize) -> usize {
    let ceiling = 32_u32;
    let (_q, r) = DivRem::div_rem(value, ceiling.try_into().unwrap());
    if r == 0_u8.into() {
        return value;
    } else {
        return (value + ceiling - r).into();
    }
}

/// Computes the number of 32-byte words required to represent `size` bytes
///
/// # Arguments
/// * `size` - The size in bytes
///
/// # Returns
/// The number of 32-byte words required to represent `size` bytes
///
/// # Examples
/// bytes_32_words_size(2) = 1
/// bytes_32_words_size(34) = 2
#[inline(always)]
pub fn bytes_32_words_size(size: usize) -> usize {
    (size + 31) / 32
}

/// Computes 256 ** (16 - i) for 0 <= i <= 16.
pub fn pow256_rev(i: usize) -> u256 {
    if (i > 16) {
        panic_with_felt252('pow256_rev: i > 16');
    }
    let v = POW_256_REV.span().at(i);
    *v
}

/// Computes 2**pow for 0 <= pow < 128.
pub fn pow2(pow: usize) -> u128 {
    if (pow > 127) {
        return panic_with_felt252('pow2: pow >= 128');
    }
    let v = POW_2.span().at(pow);
    *v
}

/// Splits a u256 into `len` bytes, big-endian, and appends the result to `dst`.
pub fn split_word(mut value: u256, mut len: usize, ref dst: Array<u8>) {
    let word_le = split_word_le(value, len);
    let word_be = ArrayExtTrait::reverse(word_le.span());
    ArrayExtTrait::concat(ref dst, word_be.span());
}

/// Splits a u128 into `len` bytes in little-endian order and appends them to the destination array.
///
/// # Arguments
/// * `dest` - The destination array to append the bytes to
/// * `value` - The u128 value to split into bytes
/// * `len` - The number of bytes to split the value into
pub fn split_u128_le(ref dest: Array<u8>, mut value: u128, mut len: usize) {
    while len != 0 {
        dest.append((value % 256).try_into().unwrap());
        value /= 256;
        len -= 1;
    };
}

/// Splits a u256 into `len` bytes, little-endian, and returns the bytes array.
///
/// # Arguments
/// * `value` - The u256 value to be split.
/// * `len` - The number of bytes to split the value into.
///
/// # Returns
/// An `Array<u8>` containing the little-endian byte representation of the input value.
pub fn split_word_le(mut value: u256, mut len: usize) -> Array<u8> {
    let mut dst: Array<u8> = ArrayTrait::new();
    let low_len = min(len, 16);
    split_u128_le(ref dst, value.low, low_len);
    let high_len = min(len - low_len, 16);
    split_u128_le(ref dst, value.high, high_len);
    dst
}

/// Splits a u256 into 16 bytes, big-endian, and appends the result to `dst`.
///
/// # Arguments
/// * `value` - The u256 value to be split.
/// * `dst` - The destination array to append the bytes to.
pub fn split_word_128(value: u256, ref dst: Array<u8>) {
    split_word(value, 16, ref dst)
}


/// Loads a sequence of bytes into a single u256 in big-endian order.
///
/// # Arguments
/// * `len` - The number of bytes to load.
/// * `words` - The span of bytes to load.
///
/// # Returns
/// A `u256` value representing the loaded bytes in big-endian order.
pub fn load_word(mut len: usize, words: Span<u8>) -> u256 {
    if len == 0 {
        return 0;
    }

    let mut current: u256 = 0;
    let mut counter = 0;

    while len != 0 {
        let loaded: u8 = *words[counter];
        let tmp = current * 256;
        current = tmp + loaded.into();
        len -= 1;
        counter += 1;
    };

    current
}

/// Converts a u256 to a bytes array represented by an array of u8 values in big-endian order.
///
/// # Arguments
/// * `value` - The u256 value to convert.
///
/// # Returns
/// An `Array<u8>` representing the big-endian byte representation of the input value.
pub fn u256_to_bytes_array(mut value: u256) -> Array<u8> {
    let mut counter = 0;
    let mut bytes_arr: Array<u8> = ArrayTrait::new();
    // low part
    while counter != 16 {
        bytes_arr.append((value.low & 0xFF).try_into().unwrap());
        value.low /= 256;
        counter += 1;
    };

    let mut counter = 0;
    // high part
    while counter != 16 {
        bytes_arr.append((value.high & 0xFF).try_into().unwrap());
        value.high /= 256;
        counter += 1;
    };

    // Reverse the array as memory is arranged in big endian order.
    let mut counter = bytes_arr.len();
    let mut bytes_arr_reversed: Array<u8> = ArrayTrait::new();
    while counter != 0 {
        bytes_arr_reversed.append(*bytes_arr[counter - 1]);
        counter -= 1;
    };
    bytes_arr_reversed
}


/// Computes the Starknet address for a given Kakarot address, EVM address, and class hash.
///
/// # Arguments
/// * `kakarot_address` - The Kakarot contract address.
/// * `evm_address` - The Ethereum address.
/// * `class_hash` - The class hash.
///
/// # Returns
/// A `ContractAddress` representing the computed Starknet address.
pub fn compute_starknet_address(
    kakarot_address: ContractAddress, evm_address: EthAddress, class_hash: ClassHash
) -> ContractAddress {
    // Deployer is always Kakarot (current contract)
    // pedersen(a1, a2, a3) is defined as:
    // pedersen(pedersen(pedersen(a1, a2), a3), len([a1, a2, a3]))
    // https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/hash_state.py#L6
    // https://github.com/xJonathanLEI/starknet-rs/blob/master/starknet-core/src/crypto.rs#L49
    // Constructor Calldata For an Account, the constructor calldata is:
    // [1, evm_address]
    let constructor_calldata_hash = PedersenTrait::new(0)
        .update_with(1)
        .update_with(evm_address)
        .update(2)
        .finalize();

    let hash = PedersenTrait::new(0)
        .update_with(CONTRACT_ADDRESS_PREFIX)
        .update_with(kakarot_address)
        .update_with(evm_address)
        .update_with(class_hash)
        .update_with(constructor_calldata_hash)
        .update(5)
        .finalize();

    let normalized_address: ContractAddress = (hash.into() & MAX_ADDRESS).try_into().unwrap();
    // We know this unwrap is safe, because of the above bitwise AND on 2 ** 251
    normalized_address
}


#[cfg(test)]
mod tests {
    use crate::helpers;

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
        while counter < 15 {
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
        while counter < 16 {
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
        while counter < 15 {
            assert_eq!(*dst4[counter], 0xff);
            counter += 1;
        };
    }
}
