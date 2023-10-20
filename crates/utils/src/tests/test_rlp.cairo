use utils::rlp::{RLPType, RLPTrait, RLPItem};
use array::{ArrayTrait, SpanTrait};
use result::ResultTrait;
use utils::errors::{RLPError, RLP_EMPTY_INPUT, RLP_INPUT_TOO_SHORT};
use utils::helpers::U32Trait;

// Tests source : https://github.com/HerodotusDev/cairo-lib/blob/main/src/encoding/tests/test_rlp.cairo
#[test]
#[available_gas(9999999)]
fn test_rlp_types() {
    let mut i = 0;
    loop {
        if i <= 0x7f {
            assert(RLPTrait::decode_type(i) == RLPType::String, 'Parse type String');
        } else if i <= 0xb7 {
            assert(RLPTrait::decode_type(i) == RLPType::StringShort, 'Parse type StringShort');
        } else if i <= 0xbf {
            assert(RLPTrait::decode_type(i) == RLPType::StringLong, 'Parse type StringLong');
        } else if i <= 0xf7 {
            assert(RLPTrait::decode_type(i) == RLPType::ListShort, 'Parse type ListShort');
        } else if i <= 0xff {
            assert(RLPTrait::decode_type(i) == RLPType::ListLong, 'Parse type ListLong');
        }

        if i == 0xff {
            break ();
        }
        i += 1;
    };
}

#[test]
#[available_gas(9999999)]
fn test_rlp_empty() {
    let res = RLPTrait::decode(ArrayTrait::new().span());

    assert(res.is_err(), 'should return an error');
    assert(res.unwrap_err() == RLPError::RlpEmptyInput(RLP_EMPTY_INPUT), 'err != RlpInvalidLength');
}

#[test]
#[available_gas(20000000)]
fn test_rlp_encode_string_empty_input() {
    let mut input: ByteArray = Default::default();

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 1, 'wrong len');
    assert(res[0] == 0x80, 'wrong encoded value');
}

#[test]
#[available_gas(20000000)]
fn test_rlp_encode_single_byte_lt_0x80() {
    let mut input: ByteArray = Default::default();
    input.append_byte(0x40);

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 1, 'wrong len');
    assert(res[0] == 0x40, 'wrong encoded value');
}

#[test]
#[available_gas(20000000)]
fn test_rlp_encode_single_byte_ge_0x80() {
    let mut input: ByteArray = Default::default();
    input.append_byte(0x80);

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 2, 'wrong len');
    assert(res[0] == 0x81, 'wrong prefix');
    assert(res[1] == 0x80, 'wrong encoded value');
}

#[test]
#[available_gas(20000000)]
fn test_rlp_encode_length_between_2_and_55() {
    let mut input: ByteArray = Default::default();
    input.append_byte(0x40);
    input.append_byte(0x50);

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 3, 'wrong len');
    assert(res[0] == 0x82, 'wrong prefix');
    assert(res[1] == 0x40, 'wrong first value');
    assert(res[2] == 0x50, 'wrong second value');
}

#[test]
#[available_gas(20000000)]
fn test_rlp_encode_length_exactly_56() {
    let mut input: ByteArray = Default::default();
    let mut i = 0;
    loop {
        if i == 56 {
            break;
        }
        input.append_byte(0x60);
        i += 1;
    };

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 58, 'wrong len');
    assert(res[0] == 0xb8, 'wrong prefix');
    assert(res[1] == 56, 'wrong string length');
    let mut i = 2;
    loop {
        if i == 58 {
            break;
        }
        assert(res[i] == 0x60, 'wrong value in sequence');
        i += 1;
    };
}

#[test]
#[available_gas(20000000)]
fn test_rlp_encode_length_greater_than_56() {
    let mut input: ByteArray = Default::default();
    let mut i = 0;
    loop {
        if i == 60 {
            break;
        }
        input.append_byte(0x70);
        i += 1;
    };

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 62, 'wrong len');
    assert(res[0] == 0xb8, 'wrong prefix');
    assert(res[1] == 60, 'wrong length byte');
    let mut i = 2;
    loop {
        if i == 62 {
            break;
        }
        assert(res[i] == 0x70, 'wrong value in sequence');
        i += 1;
    }
}

#[test]
#[available_gas(200000000)]
fn test_rlp_encode_large_bytearray_inputs() {
    let mut input: ByteArray = Default::default();
    let mut i = 0;
    loop {
        if i == 500 {
            break;
        }
        input.append_byte(0x70);
        i += 1;
    };

    let res = RLPTrait::encode_string(input).unwrap();

    assert(res.len() == 503, 'wrong len');
    assert(res[0] == 0xb9, 'wrong prefix');
    assert(res[1] == 0x01, 'wrong first length byte');
    assert(res[2] == 0xF4, 'wrong second length byte');
    let mut i = 3;
    loop {
        if i == 503 {
            break;
        }
        assert(res[i] == 0x70, 'wrong value in sequence');
        i += 1;
    }
}

#[test]
#[available_gas(99999999)]
fn test_rlp_decode_string() {
    let mut i = 0;
    loop {
        if i == 0x80 {
            break ();
        }
        let mut arr = ArrayTrait::new();
        arr.append(i);

        let (res, len) = RLPTrait::decode(arr.span()).unwrap();
        assert(len == 1, 'Wrong len');
        assert(res == RLPItem::Bytes(arr.span()), 'Wrong value');

        i += 1;
    };
}

#[test]
#[available_gas(99999999)]
fn test_rlp_decode_short_string() {
    let mut arr = array![
        0x9b,
        0x5a,
        0x80,
        0x6c,
        0xf6,
        0x34,
        0xc0,
        0x39,
        0x8d,
        0x8f,
        0x2d,
        0x89,
        0xfd,
        0x49,
        0xa9,
        0x1e,
        0xf3,
        0x3d,
        0xa4,
        0x74,
        0xcd,
        0x84,
        0x94,
        0xbb,
        0xa8,
        0xda,
        0x3b,
        0xf7
    ];

    let (res, len) = RLPTrait::decode(arr.span()).unwrap();
    assert(len == 1 + (0x9b - 0x80), 'Wrong len');

    // Remove the byte representing the data type
    arr.pop_front();
    let expected_item = RLPItem::Bytes(arr.span());

    assert(res == expected_item, 'Wrong value');
}

#[test]
#[available_gas(99999999)]
fn test_rlp_decode_short_string_input_too_short() {
    let mut arr = array![
        0x9b,
        0x5a,
        0x80,
        0x6c,
        0xf6,
        0x34,
        0xc0,
        0x39,
        0x8d,
        0x8f,
        0x2d,
        0x89,
        0xfd,
        0x49,
        0xa9,
        0x1e,
        0xf3,
        0x3d,
        0xa4,
        0x74,
        0xcd,
        0x84,
        0x94,
        0xbb,
        0xa8,
        0xda,
        0x3b
    ];

    let res = RLPTrait::decode(arr.span());
    assert(res.is_err(), 'should return an RLPError');
    assert(
        res.unwrap_err() == RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT),
        'err != RlpInputTooShort'
    );
}

#[test]
#[available_gas(99999999)]
fn test_rlp_decode_long_string_with_payload_len_on_1_byte() {
    let mut arr = array![
        0xb8,
        0x3c,
        0xf7,
        0xa1,
        0x7e,
        0xf9,
        0x59,
        0xd4,
        0x88,
        0x38,
        0x8d,
        0xdc,
        0x34,
        0x7b,
        0x3a,
        0x10,
        0xdd,
        0x85,
        0x43,
        0x1d,
        0x0c,
        0x37,
        0x98,
        0x6a,
        0x63,
        0xbd,
        0x18,
        0xba,
        0xa3,
        0x8d,
        0xb1,
        0xa4,
        0x81,
        0x6f,
        0x24,
        0xde,
        0xc3,
        0xec,
        0x16,
        0x6e,
        0xb3,
        0xb2,
        0xac,
        0xc4,
        0xc4,
        0xf7,
        0x79,
        0x04,
        0xba,
        0x76,
        0x3c,
        0x67,
        0xc6,
        0xd0,
        0x53,
        0xda,
        0xea,
        0x10,
        0x86,
        0x19,
        0x7d,
        0xd9
    ];

    let (res, len) = RLPTrait::decode(arr.span()).unwrap();
    assert(len == 1 + (0xb8 - 0xb7) + 0x3c, 'Wrong len');

    // Remove the bytes representing the data type and their length
    arr.pop_front();
    arr.pop_front();
    let expected_item = RLPItem::Bytes(arr.span());

    assert(res == expected_item, 'Wrong value');
}

#[test]
#[available_gas(99999999)]
fn test_rlp_decode_long_string_with_input_too_short() {
    let mut arr = array![
        0xb8,
        0x3c,
        0xf7,
        0xa1,
        0x7e,
        0xf9,
        0x59,
        0xd4,
        0x88,
        0x38,
        0x8d,
        0xdc,
        0x34,
        0x7b,
        0x3a,
        0x10,
        0xdd,
        0x85,
        0x43,
        0x1d,
        0x0c,
        0x37,
        0x98,
        0x6a,
        0x63,
        0xbd,
        0x18,
        0xba,
        0xa3,
        0x8d,
        0xb1,
        0xa4,
        0x81,
        0x6f,
        0x24,
        0xde,
        0xc3,
        0xec,
        0x16,
        0x6e,
        0xb3,
        0xb2,
        0xac,
        0xc4,
        0xc4,
        0xf7,
        0x79,
        0x04,
        0xba,
        0x76,
        0x3c,
        0x67,
        0xc6,
        0xd0,
        0x53,
        0xda,
        0xea,
        0x10,
        0x86,
        0x19,
    ];

    let res = RLPTrait::decode(arr.span());
    assert(res.is_err(), 'should return an RLPError');
    assert(
        res.unwrap_err() == RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT),
        'err != RlpInputTooShort'
    );
}

#[test]
#[available_gas(99999999)]
fn test_rlp_decode_long_string_with_payload_len_on_2_bytes() {
    let mut arr = array![
        0xb9,
        0x01,
        0x02,
        0xf7,
        0xa1,
        0x7e,
        0xf9,
        0x59,
        0xd4,
        0x88,
        0x38,
        0x8d,
        0xdc,
        0x34,
        0x7b,
        0x3a,
        0x10,
        0xdd,
        0x85,
        0x43,
        0x1d,
        0x0c,
        0x37,
        0x98,
        0x6a,
        0x63,
        0xbd,
        0x18,
        0xba,
        0xa3,
        0x8d,
        0xb1,
        0xa4,
        0x81,
        0x6f,
        0x24,
        0xde,
        0xc3,
        0xec,
        0x16,
        0x6e,
        0xb3,
        0xb2,
        0xac,
        0xc4,
        0xc4,
        0xf7,
        0x79,
        0x04,
        0xba,
        0x76,
        0x3c,
        0x67,
        0xc6,
        0xd0,
        0x53,
        0xda,
        0xea,
        0x10,
        0x86,
        0x19,
        0x7d,
        0xd9,
        0x33,
        0x58,
        0x47,
        0x69,
        0x34,
        0x76,
        0x89,
        0x43,
        0x67,
        0x93,
        0x45,
        0x76,
        0x87,
        0x34,
        0x95,
        0x67,
        0x89,
        0x34,
        0x36,
        0x43,
        0x86,
        0x79,
        0x43,
        0x63,
        0x34,
        0x78,
        0x63,
        0x49,
        0x58,
        0x67,
        0x83,
        0x59,
        0x64,
        0x56,
        0x37,
        0x93,
        0x74,
        0x58,
        0x69,
        0x69,
        0x43,
        0x67,
        0x39,
        0x48,
        0x67,
        0x98,
        0x45,
        0x63,
        0x89,
        0x45,
        0x67,
        0x94,
        0x37,
        0x63,
        0x04,
        0x56,
        0x40,
        0x39,
        0x68,
        0x43,
        0x08,
        0x68,
        0x40,
        0x65,
        0x03,
        0x46,
        0x80,
        0x93,
        0x48,
        0x64,
        0x95,
        0x36,
        0x87,
        0x39,
        0x84,
        0x56,
        0x73,
        0x76,
        0x89,
        0x34,
        0x95,
        0x86,
        0x73,
        0x65,
        0x40,
        0x93,
        0x60,
        0x98,
        0x34,
        0x56,
        0x83,
        0x04,
        0x56,
        0x80,
        0x36,
        0x08,
        0x59,
        0x68,
        0x45,
        0x06,
        0x83,
        0x06,
        0x68,
        0x40,
        0x59,
        0x68,
        0x40,
        0x65,
        0x84,
        0x03,
        0x68,
        0x30,
        0x48,
        0x65,
        0x03,
        0x46,
        0x83,
        0x49,
        0x57,
        0x68,
        0x95,
        0x79,
        0x68,
        0x34,
        0x76,
        0x83,
        0x74,
        0x69,
        0x87,
        0x43,
        0x59,
        0x63,
        0x84,
        0x75,
        0x63,
        0x98,
        0x47,
        0x56,
        0x34,
        0x86,
        0x73,
        0x94,
        0x87,
        0x65,
        0x43,
        0x98,
        0x67,
        0x34,
        0x96,
        0x79,
        0x34,
        0x86,
        0x57,
        0x93,
        0x48,
        0x57,
        0x69,
        0x34,
        0x87,
        0x56,
        0x89,
        0x34,
        0x57,
        0x68,
        0x73,
        0x49,
        0x56,
        0x53,
        0x79,
        0x43,
        0x95,
        0x67,
        0x34,
        0x96,
        0x79,
        0x38,
        0x47,
        0x63,
        0x94,
        0x65,
        0x37,
        0x89,
        0x63,
        0x53,
        0x45,
        0x68,
        0x79,
        0x88,
        0x97,
        0x68,
        0x87,
        0x68,
        0x68,
        0x68,
        0x76,
        0x99,
        0x87,
        0x60
    ];

    let (res, len) = RLPTrait::decode(arr.span()).unwrap();
    assert(len == 1 + (0xb9 - 0xb7) + 0x0102, 'Wrong len');

    // Remove the bytes representing the data type and their length
    arr.pop_front();
    arr.pop_front();
    arr.pop_front();
    let expected_item = RLPItem::Bytes(arr.span());

    assert(res == expected_item, 'Wrong value');
}


#[test]
#[available_gas(99999999)]
fn test_rlp_decode_long_string_with_payload_len_too_short() {
    let mut arr = array![0xb9, 0x01,];

    let res = RLPTrait::decode(arr.span());
    assert(res.is_err(), 'should return an RLPError');
    assert(
        res.unwrap_err() == RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT),
        'err != RlpInputTooShort'
    );
}

#[test]
#[available_gas(99999999999)]
fn test_rlp_decode_short_list() {
    let mut arr = array![0xc9, 0x83, 0x35, 0x35, 0x89, 0x42, 0x83, 0x45, 0x38, 0x92];
    let (res, len) = RLPTrait::decode(arr.span()).unwrap();
    assert(len == 1 + (0xc9 - 0xc0), 'Wrong len');

    let mut expected_0 = array![0x35, 0x35, 0x89];
    let mut expected_1 = array![0x42];
    let mut expected_2 = array![0x45, 0x38, 0x92];

    let expected = array![expected_0.span(), expected_1.span(), expected_2.span()];
    let expected_item = RLPItem::List(expected.span());

    assert(res == expected_item, 'Wrong value');
}

#[test]
#[available_gas(99999999999)]
fn test_rlp_decode_short_list_with_input_too_short() {
    let mut arr = array![0xc9, 0x83, 0x35, 0x35, 0x89, 0x42, 0x83, 0x45, 0x38];

    let res = RLPTrait::decode(arr.span());
    assert(res.is_err(), 'should return an RLPError');
    assert(
        res.unwrap_err() == RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT),
        'err != RlpInputTooShort'
    );
}

#[test]
#[available_gas(99999999999)]
fn test_rlp_decode_long_list() {
    let mut arr = array![
        0xf9,
        0x02,
        0x11,
        0xa0,
        0x77,
        0x70,
        0xcf,
        0x09,
        0xb5,
        0x06,
        0x7a,
        0x1b,
        0x35,
        0xdf,
        0x62,
        0xa9,
        0x24,
        0x89,
        0x81,
        0x75,
        0xce,
        0xae,
        0xec,
        0xad,
        0x1f,
        0x68,
        0xcd,
        0xb4,
        0xa8,
        0x44,
        0x40,
        0x0c,
        0x73,
        0xc1,
        0x4a,
        0xf4,
        0xa0,
        0x1e,
        0xa3,
        0x85,
        0xd0,
        0x5a,
        0xb2,
        0x61,
        0x46,
        0x6d,
        0x5c,
        0x04,
        0x87,
        0xfe,
        0x68,
        0x45,
        0x34,
        0xc1,
        0x9f,
        0x1a,
        0x4b,
        0x5c,
        0x4b,
        0x18,
        0xdc,
        0x1a,
        0x36,
        0x35,
        0x60,
        0x02,
        0x50,
        0x71,
        0xb4,
        0xa0,
        0x2c,
        0x4c,
        0x04,
        0xce,
        0x35,
        0x40,
        0xd3,
        0xd1,
        0x46,
        0x18,
        0x72,
        0x30,
        0x3c,
        0x53,
        0xa5,
        0xe5,
        0x66,
        0x83,
        0xc1,
        0x30,
        0x4f,
        0x8d,
        0x36,
        0xa8,
        0x80,
        0x0c,
        0x6a,
        0xf5,
        0xfa,
        0x3f,
        0xcd,
        0xee,
        0xa0,
        0xa9,
        0xdc,
        0x77,
        0x8d,
        0xc5,
        0x4b,
        0x7d,
        0xd3,
        0xc4,
        0x82,
        0x22,
        0xe7,
        0x39,
        0xd1,
        0x61,
        0xfe,
        0xb0,
        0xc0,
        0xee,
        0xce,
        0xb2,
        0xdc,
        0xd5,
        0x17,
        0x37,
        0xf0,
        0x5b,
        0x8e,
        0x37,
        0xa6,
        0x38,
        0x51,
        0xa0,
        0xa9,
        0x5f,
        0x4d,
        0x55,
        0x56,
        0xdf,
        0x62,
        0xdd,
        0xc2,
        0x62,
        0x99,
        0x04,
        0x97,
        0xae,
        0x56,
        0x9b,
        0xcd,
        0x8e,
        0xfd,
        0xda,
        0x7b,
        0x20,
        0x07,
        0x93,
        0xf8,
        0xd3,
        0xde,
        0x4c,
        0xdb,
        0x97,
        0x18,
        0xd7,
        0xa0,
        0x39,
        0xd4,
        0x06,
        0x6d,
        0x14,
        0x38,
        0x22,
        0x6e,
        0xaf,
        0x4a,
        0xc9,
        0xe9,
        0x43,
        0xa8,
        0x74,
        0xa9,
        0xa9,
        0xc2,
        0x5f,
        0xb0,
        0xd8,
        0x1d,
        0xb9,
        0x86,
        0x1d,
        0x8c,
        0x13,
        0x36,
        0xb3,
        0xe2,
        0x03,
        0x4c,
        0xa0,
        0x7a,
        0xcc,
        0x7c,
        0x63,
        0xb4,
        0x6a,
        0xa4,
        0x18,
        0xb3,
        0xc9,
        0xa0,
        0x41,
        0xa1,
        0x25,
        0x6b,
        0xcb,
        0x73,
        0x61,
        0x31,
        0x6b,
        0x39,
        0x7a,
        0xda,
        0x5a,
        0x88,
        0x67,
        0x49,
        0x1b,
        0xbb,
        0x13,
        0x01,
        0x30,
        0xa0,
        0x15,
        0x35,
        0x8a,
        0x81,
        0x25,
        0x2e,
        0xc4,
        0x93,
        0x71,
        0x13,
        0xfe,
        0x36,
        0xc7,
        0x80,
        0x46,
        0xb7,
        0x11,
        0xfb,
        0xa1,
        0x97,
        0x34,
        0x91,
        0xbb,
        0x29,
        0x18,
        0x7a,
        0x00,
        0x78,
        0x5f,
        0xf8,
        0x52,
        0xae,
        0xa0,
        0x68,
        0x91,
        0x42,
        0xd3,
        0x16,
        0xab,
        0xfa,
        0xa7,
        0x1c,
        0x8b,
        0xce,
        0xdf,
        0x49,
        0x20,
        0x1d,
        0xdb,
        0xb2,
        0x10,
        0x4e,
        0x25,
        0x0a,
        0xdc,
        0x90,
        0xc4,
        0xe8,
        0x56,
        0x22,
        0x1f,
        0x53,
        0x4a,
        0x96,
        0x58,
        0xa0,
        0xdc,
        0x36,
        0x50,
        0x99,
        0x25,
        0x34,
        0xfd,
        0xa8,
        0xa3,
        0x14,
        0xa7,
        0xdb,
        0xb0,
        0xae,
        0x3b,
        0xa8,
        0xc7,
        0x9d,
        0xb5,
        0x55,
        0x0c,
        0x69,
        0xce,
        0x2a,
        0x24,
        0x60,
        0xc0,
        0x07,
        0xad,
        0xc4,
        0xc1,
        0xa3,
        0xa0,
        0x20,
        0xb0,
        0x68,
        0x3b,
        0x66,
        0x55,
        0xb0,
        0x05,
        0x9e,
        0xe1,
        0x03,
        0xd0,
        0x4e,
        0x4b,
        0x50,
        0x6b,
        0xcb,
        0xc1,
        0x39,
        0x00,
        0x63,
        0x92,
        0xb7,
        0xda,
        0xb1,
        0x11,
        0x78,
        0xc2,
        0x66,
        0x03,
        0x42,
        0xe7,
        0xa0,
        0x8e,
        0xed,
        0xeb,
        0x45,
        0xfb,
        0x63,
        0x0f,
        0x1c,
        0xd9,
        0x97,
        0x36,
        0xeb,
        0x18,
        0x57,
        0x22,
        0x17,
        0xcb,
        0xc6,
        0xd5,
        0xf3,
        0x15,
        0xb7,
        0x1b,
        0xe2,
        0x03,
        0xb0,
        0x3c,
        0xe8,
        0xd9,
        0x9b,
        0x26,
        0x14,
        0xa0,
        0x79,
        0x23,
        0xa3,
        0x3d,
        0xf6,
        0x5a,
        0x98,
        0x6f,
        0xd5,
        0xe7,
        0xf9,
        0xe6,
        0xe4,
        0xc2,
        0xb9,
        0x69,
        0x73,
        0x6b,
        0x08,
        0x94,
        0x4e,
        0xbe,
        0x99,
        0x39,
        0x4a,
        0x86,
        0x14,
        0x61,
        0x2f,
        0xe6,
        0x09,
        0xf3,
        0xa0,
        0x65,
        0x34,
        0xd7,
        0xd0,
        0x1a,
        0x20,
        0x71,
        0x4a,
        0xa4,
        0xfb,
        0x2a,
        0x55,
        0xb9,
        0x46,
        0xce,
        0x64,
        0xc3,
        0x22,
        0x2d,
        0xff,
        0xad,
        0x2a,
        0xa2,
        0xd1,
        0x8a,
        0x92,
        0x34,
        0x73,
        0xc9,
        0x2a,
        0xb1,
        0xfd,
        0xa0,
        0xbf,
        0xf9,
        0xc2,
        0x8b,
        0xfe,
        0xb8,
        0xbf,
        0x2d,
        0xa9,
        0xb6,
        0x18,
        0xc8,
        0xc3,
        0xb0,
        0x6f,
        0xe8,
        0x0c,
        0xb1,
        0xc0,
        0xbd,
        0x14,
        0x47,
        0x38,
        0xf7,
        0xc4,
        0x21,
        0x61,
        0xff,
        0x29,
        0xe2,
        0x50,
        0x2f,
        0xa0,
        0x7f,
        0x14,
        0x61,
        0x69,
        0x3c,
        0x70,
        0x4e,
        0xa5,
        0x02,
        0x1b,
        0xbb,
        0xa3,
        0x5e,
        0x72,
        0xc5,
        0x02,
        0xf6,
        0x43,
        0x9e,
        0x45,
        0x8f,
        0x98,
        0x24,
        0x2e,
        0xd0,
        0x37,
        0x48,
        0xea,
        0x8f,
        0xe2,
        0xb3,
        0x5f,
        0x80
    ];
    let (res, len) = RLPTrait::decode(arr.span()).unwrap();
    assert(len == 1 + (0xf9 - 0xf7) + 0x0211, 'Wrong len');

    let mut expected_0 = array![
        0x77,
        0x70,
        0xcf,
        0x09,
        0xb5,
        0x06,
        0x7a,
        0x1b,
        0x35,
        0xdf,
        0x62,
        0xa9,
        0x24,
        0x89,
        0x81,
        0x75,
        0xce,
        0xae,
        0xec,
        0xad,
        0x1f,
        0x68,
        0xcd,
        0xb4,
        0xa8,
        0x44,
        0x40,
        0x0c,
        0x73,
        0xc1,
        0x4a,
        0xf4
    ];
    let mut expected_1 = array![
        0x1e,
        0xa3,
        0x85,
        0xd0,
        0x5a,
        0xb2,
        0x61,
        0x46,
        0x6d,
        0x5c,
        0x04,
        0x87,
        0xfe,
        0x68,
        0x45,
        0x34,
        0xc1,
        0x9f,
        0x1a,
        0x4b,
        0x5c,
        0x4b,
        0x18,
        0xdc,
        0x1a,
        0x36,
        0x35,
        0x60,
        0x02,
        0x50,
        0x71,
        0xb4
    ];
    let mut expected_2 = array![
        0x2c,
        0x4c,
        0x04,
        0xce,
        0x35,
        0x40,
        0xd3,
        0xd1,
        0x46,
        0x18,
        0x72,
        0x30,
        0x3c,
        0x53,
        0xa5,
        0xe5,
        0x66,
        0x83,
        0xc1,
        0x30,
        0x4f,
        0x8d,
        0x36,
        0xa8,
        0x80,
        0x0c,
        0x6a,
        0xf5,
        0xfa,
        0x3f,
        0xcd,
        0xee
    ];
    let mut expected_3 = array![
        0xa9,
        0xdc,
        0x77,
        0x8d,
        0xc5,
        0x4b,
        0x7d,
        0xd3,
        0xc4,
        0x82,
        0x22,
        0xe7,
        0x39,
        0xd1,
        0x61,
        0xfe,
        0xb0,
        0xc0,
        0xee,
        0xce,
        0xb2,
        0xdc,
        0xd5,
        0x17,
        0x37,
        0xf0,
        0x5b,
        0x8e,
        0x37,
        0xa6,
        0x38,
        0x51
    ];
    let mut expected_4 = array![
        0xa9,
        0x5f,
        0x4d,
        0x55,
        0x56,
        0xdf,
        0x62,
        0xdd,
        0xc2,
        0x62,
        0x99,
        0x04,
        0x97,
        0xae,
        0x56,
        0x9b,
        0xcd,
        0x8e,
        0xfd,
        0xda,
        0x7b,
        0x20,
        0x07,
        0x93,
        0xf8,
        0xd3,
        0xde,
        0x4c,
        0xdb,
        0x97,
        0x18,
        0xd7
    ];
    let mut expected_5 = array![
        0x39,
        0xd4,
        0x06,
        0x6d,
        0x14,
        0x38,
        0x22,
        0x6e,
        0xaf,
        0x4a,
        0xc9,
        0xe9,
        0x43,
        0xa8,
        0x74,
        0xa9,
        0xa9,
        0xc2,
        0x5f,
        0xb0,
        0xd8,
        0x1d,
        0xb9,
        0x86,
        0x1d,
        0x8c,
        0x13,
        0x36,
        0xb3,
        0xe2,
        0x03,
        0x4c
    ];
    let mut expected_6 = array![
        0x7a,
        0xcc,
        0x7c,
        0x63,
        0xb4,
        0x6a,
        0xa4,
        0x18,
        0xb3,
        0xc9,
        0xa0,
        0x41,
        0xa1,
        0x25,
        0x6b,
        0xcb,
        0x73,
        0x61,
        0x31,
        0x6b,
        0x39,
        0x7a,
        0xda,
        0x5a,
        0x88,
        0x67,
        0x49,
        0x1b,
        0xbb,
        0x13,
        0x01,
        0x30
    ];
    let mut expected_7 = array![
        0x15,
        0x35,
        0x8a,
        0x81,
        0x25,
        0x2e,
        0xc4,
        0x93,
        0x71,
        0x13,
        0xfe,
        0x36,
        0xc7,
        0x80,
        0x46,
        0xb7,
        0x11,
        0xfb,
        0xa1,
        0x97,
        0x34,
        0x91,
        0xbb,
        0x29,
        0x18,
        0x7a,
        0x00,
        0x78,
        0x5f,
        0xf8,
        0x52,
        0xae
    ];
    let mut expected_8 = array![
        0x68,
        0x91,
        0x42,
        0xd3,
        0x16,
        0xab,
        0xfa,
        0xa7,
        0x1c,
        0x8b,
        0xce,
        0xdf,
        0x49,
        0x20,
        0x1d,
        0xdb,
        0xb2,
        0x10,
        0x4e,
        0x25,
        0x0a,
        0xdc,
        0x90,
        0xc4,
        0xe8,
        0x56,
        0x22,
        0x1f,
        0x53,
        0x4a,
        0x96,
        0x58
    ];
    let mut expected_9 = array![
        0xdc,
        0x36,
        0x50,
        0x99,
        0x25,
        0x34,
        0xfd,
        0xa8,
        0xa3,
        0x14,
        0xa7,
        0xdb,
        0xb0,
        0xae,
        0x3b,
        0xa8,
        0xc7,
        0x9d,
        0xb5,
        0x55,
        0x0c,
        0x69,
        0xce,
        0x2a,
        0x24,
        0x60,
        0xc0,
        0x07,
        0xad,
        0xc4,
        0xc1,
        0xa3
    ];
    let mut expected_10 = array![
        0x20,
        0xb0,
        0x68,
        0x3b,
        0x66,
        0x55,
        0xb0,
        0x05,
        0x9e,
        0xe1,
        0x03,
        0xd0,
        0x4e,
        0x4b,
        0x50,
        0x6b,
        0xcb,
        0xc1,
        0x39,
        0x00,
        0x63,
        0x92,
        0xb7,
        0xda,
        0xb1,
        0x11,
        0x78,
        0xc2,
        0x66,
        0x03,
        0x42,
        0xe7
    ];
    let mut expected_11 = array![
        0x8e,
        0xed,
        0xeb,
        0x45,
        0xfb,
        0x63,
        0x0f,
        0x1c,
        0xd9,
        0x97,
        0x36,
        0xeb,
        0x18,
        0x57,
        0x22,
        0x17,
        0xcb,
        0xc6,
        0xd5,
        0xf3,
        0x15,
        0xb7,
        0x1b,
        0xe2,
        0x03,
        0xb0,
        0x3c,
        0xe8,
        0xd9,
        0x9b,
        0x26,
        0x14
    ];
    let mut expected_12 = array![
        0x79,
        0x23,
        0xa3,
        0x3d,
        0xf6,
        0x5a,
        0x98,
        0x6f,
        0xd5,
        0xe7,
        0xf9,
        0xe6,
        0xe4,
        0xc2,
        0xb9,
        0x69,
        0x73,
        0x6b,
        0x08,
        0x94,
        0x4e,
        0xbe,
        0x99,
        0x39,
        0x4a,
        0x86,
        0x14,
        0x61,
        0x2f,
        0xe6,
        0x09,
        0xf3
    ];
    let mut expected_13 = array![
        0x65,
        0x34,
        0xd7,
        0xd0,
        0x1a,
        0x20,
        0x71,
        0x4a,
        0xa4,
        0xfb,
        0x2a,
        0x55,
        0xb9,
        0x46,
        0xce,
        0x64,
        0xc3,
        0x22,
        0x2d,
        0xff,
        0xad,
        0x2a,
        0xa2,
        0xd1,
        0x8a,
        0x92,
        0x34,
        0x73,
        0xc9,
        0x2a,
        0xb1,
        0xfd
    ];
    let mut expected_14 = array![
        0xbf,
        0xf9,
        0xc2,
        0x8b,
        0xfe,
        0xb8,
        0xbf,
        0x2d,
        0xa9,
        0xb6,
        0x18,
        0xc8,
        0xc3,
        0xb0,
        0x6f,
        0xe8,
        0x0c,
        0xb1,
        0xc0,
        0xbd,
        0x14,
        0x47,
        0x38,
        0xf7,
        0xc4,
        0x21,
        0x61,
        0xff,
        0x29,
        0xe2,
        0x50,
        0x2f
    ];
    let mut expected_15 = array![
        0x7f,
        0x14,
        0x61,
        0x69,
        0x3c,
        0x70,
        0x4e,
        0xa5,
        0x02,
        0x1b,
        0xbb,
        0xa3,
        0x5e,
        0x72,
        0xc5,
        0x02,
        0xf6,
        0x43,
        0x9e,
        0x45,
        0x8f,
        0x98,
        0x24,
        0x2e,
        0xd0,
        0x37,
        0x48,
        0xea,
        0x8f,
        0xe2,
        0xb3,
        0x5f
    ];
    let mut expected_16 = ArrayTrait::new();

    let mut expected = array![
        expected_0.span(),
        expected_1.span(),
        expected_2.span(),
        expected_3.span(),
        expected_4.span(),
        expected_5.span(),
        expected_6.span(),
        expected_7.span(),
        expected_8.span(),
        expected_9.span(),
        expected_10.span(),
        expected_11.span(),
        expected_12.span(),
        expected_13.span(),
        expected_14.span(),
        expected_15.span(),
        expected_16.span()
    ];
    let expected_item = RLPItem::List(expected.span());

    assert(res == expected_item, 'Wrong value');
}

#[test]
#[available_gas(99999999999)]
fn test_rlp_decode_long_list_with_input_too_short() {
    let mut arr = array![
        0xf9,
        0x02,
        0x11,
        0xa0,
        0x77,
        0x70,
        0xcf,
        0x09,
        0xb5,
        0x06,
        0x7a,
        0x1b,
        0x35,
        0xdf,
        0x62,
        0xa9,
        0x24,
        0x89,
        0x81,
        0x75,
        0xce,
        0xae,
        0xec,
        0xad,
        0x1f,
        0x68,
        0xcd,
        0xb4
    ];

    let res = RLPTrait::decode(arr.span());
    assert(res.is_err(), 'should return an RLPError');
    assert(
        res.unwrap_err() == RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT),
        'err != RlpInputTooShort'
    );
}

#[test]
#[available_gas(99999999999)]
fn test_rlp_decode_long_list_with_len_too_short() {
    let mut arr = array![0xf9, 0x02,];

    let res = RLPTrait::decode(arr.span());
    assert(res.is_err(), 'should return an RLPError');
    assert(
        res.unwrap_err() == RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT),
        'err != RlpInputTooShort'
    );
}
