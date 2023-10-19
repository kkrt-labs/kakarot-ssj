use utils::helpers;
use utils::helpers::{
    SpanExtension, SpanExtTrait, ArrayExtension, ArrayExtTrait, U256Trait, U32Trait
};
use utils::helpers::{ByteArrayExTrait};
use utils::traits::{ByteArraySerde};

#[test]
#[available_gas(2000000000)]
fn test_u256_to_bytes_array() {
    let value: u256 = 256;

    let bytes_array = helpers::u256_to_bytes_array(value);
    assert(1 == *bytes_array[30], 'wrong conversion');
}

#[test]
#[available_gas(2000000000)]
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
#[available_gas(2000000000)]
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
#[available_gas(2000000000)]
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

#[test]
#[available_gas(2000000000)]
fn test_append_n() {
    // Given
    let mut original: Array<u8> = array![1, 2, 3, 4];

    // When
    original.append_n(9, 3);

    // Then
    assert(original == array![1, 2, 3, 4, 9, 9, 9], 'append_n failed');
}

#[test]
#[available_gas(2000000000)]
fn test_append_unique() {
    let mut arr = array![1, 2, 3];
    arr.append_unique(4);
    assert(arr == array![1, 2, 3, 4], 'should have appended');
    arr.append_unique(2);
    assert(arr == array![1, 2, 3, 4], 'shouldnt have appended');
}

#[test]
#[available_gas(2000000000)]
fn test_reverse_bytes_u256() {
    let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
    let res = value.reverse_endianness();
    assert(
        res == 0x0000450000DEFA0000200400000000ADDE00000077000000E5000000FFFFFFFA,
        'reverse mismatch'
    );
}

#[test]
#[available_gas(2000000000)]
fn test_split_u256_into_u64_little() {
    let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
    let ((high_h, low_h), (high_l, low_l)) = value.split_into_u64_le();
    assert(high_h == 0xDE00000077000000, 'split mismatch');
    assert(low_h == 0xE5000000FFFFFFFA, 'split mismatch');
    assert(high_l == 0x0000450000DEFA00, 'split mismatch');
    assert(low_l == 0x00200400000000AD, 'split mismatch');
}

#[test]
#[available_gas(20000000)]
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
#[available_gas(20000000)]
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
#[available_gas(2000000000)]
fn test_bytes_serde_u32_deserialize() {
    let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62];
    let res: Option<u32> = U32Trait::from_bytes(input.span());

    assert(res != Option::None, 'should have a value');
    let res = res.unwrap();
    assert(res == 0xf4321562, 'wrong result value');
}

#[test]
#[available_gas(2000000000)]
fn test_bytearray_deserialize() {
    let mut serialized: Span<felt252> = array![
        0x03, 0xabcdef, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
    ]
        .span();

    let deserialized: ByteArray = Serde::<ByteArray>::deserialize(ref serialized).unwrap();

    let expected = ByteArray {
        data: array![
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff.try_into().unwrap()
        ],
        pending_word_len: 3,
        pending_word: 0xabcdef
    };
    assert(expected.len() == deserialized.len(), 'len mismatch');
    let mut i = 0;
    loop {
        if i == deserialized.len() {
            break;
        }

        assert(expected[i] == deserialized[i], 'item mismatch');
        i += 1;
    };
}

#[test]
#[available_gas(20000000)]
fn test_bytearray_serialize() {
    let byte_arr = ByteArray {
        data: array![
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff.try_into().unwrap()
        ],
        pending_word_len: 3,
        pending_word: 0xabcdef
    };
    let mut serialized: Array<felt252> = Default::default();
    byte_arr.serialize(ref serialized);

    // One extra element encodes the length of the pending word
    assert(serialized.len() == 3, 'len mismatch');
    assert(*serialized[0] == 3, 'pending_word_len mismatch');
    assert(*serialized[1] == 0xabcdef, 'pending_word mismatch');
    assert(
        *serialized[2] == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        'full_word mismatch'
    );
}
