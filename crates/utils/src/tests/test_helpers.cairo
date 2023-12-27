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

mod u32_test {
    use utils::helpers::Bitshift;
    use utils::helpers::U32Trait;

    #[test]
    fn test_u32_from_bytes() {
        let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62];
        let res: Option<u32> = U32Trait::from_bytes(input.span());

        assert(res.is_some(), 'should have a value');
        assert(res.unwrap() == 0xf4321562, 'wrong result value');
    }

    #[test]
    fn test_u32_from_bytes_too_big() {
        let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62, 0x01];
        let res: Option<u32> = U32Trait::from_bytes(input.span());

        assert(res.is_none(), 'should not have a value');
    }

    #[test]
    fn test_u32_to_bytes_full() {
        let input: u32 = 0xf4321562;
        let res: Span<u8> = input.to_bytes();

        assert(res.len() == 4, 'wrong result length');
        assert(*res[0] == 0xf4, 'wrong result value');
        assert(*res[1] == 0x32, 'wrong result value');
        assert(*res[2] == 0x15, 'wrong result value');
        assert(*res[3] == 0x62, 'wrong result value');
    }

    #[test]
    fn test_u32_to_bytes_partial() {
        let input: u32 = 0xf43215;
        let res: Span<u8> = input.to_bytes();

        assert(res.len() == 3, 'wrong result length');
        assert(*res[0] == 0xf4, 'wrong result value');
        assert(*res[1] == 0x32, 'wrong result value');
        assert(*res[2] == 0x15, 'wrong result value');
    }


    #[test]
    fn test_u32_to_bytes_leading_zeros() {
        let input: u32 = 0x00f432;
        let res: Span<u8> = input.to_bytes();

        assert(res.len() == 2, 'wrong result length');
        assert(*res[0] == 0xf4, 'wrong result value');
        assert(*res[1] == 0x32, 'wrong result value');
    }


    #[test]
    fn test_u32_bytes_used() {
        assert_eq!(0x00_u32.bytes_used(), 0);
        let mut value = 0xff;
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
        let len = 0x001234;
        let bytes_count = len.bytes_used();

        assert(bytes_count == 2, 'wrong bytes count');
    }
}

mod u64_test {
    use utils::helpers::Bitshift;
    use utils::helpers::U64Trait;

    #[test]
    fn test_u64_bytes_used() {
        assert_eq!(0x00_u64.bytes_used(), 0);
        let mut value = 0xff;
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
}

mod u128_test {
    use utils::helpers::Bitshift;
    use utils::helpers::U128Trait;

    #[test]
    fn test_u128_bytes_used() {
        assert_eq!(0x00_u128.bytes_used(), 0);
        let mut value = 0xff;
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
}

mod u256_test {
    use utils::helpers::Bitshift;
    use utils::helpers::U256Trait;
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
        let mut value = 0xff;
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
        let input = ByteArrayExTrait::from_bytes(array![0x01, 0x02, 0x03, 0x04, 0x05, 0x06].span());
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
    use utils::helpers::{U32Trait, U8SpanExTrait};

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
        let msg = 0xabcdef_u32.to_bytes();
        let expected_hash = 0x800d501693feda2226878e1ec7869eef8919dbc5bd10c2bcd031b94d73492860;
        let hash = msg.compute_keccak256_hash();

        assert_eq!(hash, expected_hash);
    }
}

mod eth_signature_test {
    use starknet::eth_signature::Signature;
    use utils::constants::CHAIN_ID;
    use utils::eth_transaction::TransactionType;
    use utils::helpers::{EthAddressSignatureTrait, TryIntoEthSignatureTrait};

    #[test]
    fn test_eth_signature_to_felt252_array() {
        // generated via ./scripts/compute_rlp_encoding.ts
        // inputs:
        //          to: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
        //          value: 1
        //          gasLimit: 1
        //          gasPrice: 1
        //          nonce: 1
        //          chainId: 1263227476
        //          data: 0xabcdef
        //          tx_type: 0 for signature_0, 1 for signature_1, 2 for signature_2

        // tx_type = 0, v: 0x9696a4cb
        let signature_0 = Signature {
            r: 0x306c3f638450a95f1f669481bf8ede9b056ef8d94259a3104f3a28673e02823d,
            s: 0x41ea07e6d3d02773e380e752e5b3f9d28aca3882ee165e56b402cca0189967c9,
            y_parity: false
        };

        // tx_type = 1
        let signature_1 = Signature {
            r: 0x615c33039b7b09e3d5aa3cf1851c35abe7032f92111cc95ef45f83d032ccff5d,
            s: 0x30b5f1a58abce1c7d45309b7a3b0befeddd1aee203021172779dd693a1e59505,
            y_parity: false
        };

        // tx_type = 2
        let signature_2 = Signature {
            r: 0xbc485ed0b43483ebe5fbff90962791c015755cc03060a33360b1b3e823bb71a4,
            s: 0x4c47017509e1609db6c2e8e2b02327caeb709c986d8b63099695105432afa533,
            y_parity: false
        };

        let expected_signature_0: Span<felt252> = array![
            signature_0.r.low.into(),
            signature_0.r.high.into(),
            signature_0.s.low.into(),
            signature_0.s.high.into(),
            0x9696a4cb
        ]
            .span();

        let expected_signature_1: Span<felt252> = array![
            signature_1.r.low.into(),
            signature_1.r.high.into(),
            signature_1.s.low.into(),
            signature_1.s.high.into(),
            0x0_felt252,
        ]
            .span();

        let expected_signature_2: Span<felt252> = array![
            signature_2.r.low.into(),
            signature_2.r.high.into(),
            signature_2.s.low.into(),
            signature_2.s.high.into(),
            0x0_felt252,
        ]
            .span();

        let result = signature_0
            .try_into_felt252_array(TransactionType::Legacy, CHAIN_ID)
            .unwrap()
            .span();
        assert_eq!(result, expected_signature_0);

        let result = signature_1
            .try_into_felt252_array(TransactionType::EIP2930, CHAIN_ID)
            .unwrap()
            .span();
        assert_eq!(result, expected_signature_1);

        let result = signature_2
            .try_into_felt252_array(TransactionType::EIP1559, CHAIN_ID)
            .unwrap()
            .span();
        assert_eq!(result, expected_signature_2);
    }

    #[test]
    fn test_felt252_array_to_eth_signature() {
        // generated via ./scripts/compute_rlp_encoding.ts
        // inputs:
        //          to: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
        //          value: 1
        //          gasLimit: 1
        //          gasPrice: 1
        //          nonce: 1
        //          chainId: 1263227476
        //          data: 0xabcdef
        //          tx_type: 0 for signature_0, 1 for signature_1, 2 for signature_2

        // tx_type = 0, v: 0x9696a4cb
        let signature_0 = Signature {
            r: 0x306c3f638450a95f1f669481bf8ede9b056ef8d94259a3104f3a28673e02823d,
            s: 0x41ea07e6d3d02773e380e752e5b3f9d28aca3882ee165e56b402cca0189967c9,
            y_parity: false
        };

        // tx_type = 1
        let signature_1 = Signature {
            r: 0x615c33039b7b09e3d5aa3cf1851c35abe7032f92111cc95ef45f83d032ccff5d,
            s: 0x30b5f1a58abce1c7d45309b7a3b0befeddd1aee203021172779dd693a1e59505,
            y_parity: false
        };

        // tx_type = 2
        let signature_2 = Signature {
            r: 0xbc485ed0b43483ebe5fbff90962791c015755cc03060a33360b1b3e823bb71a4,
            s: 0x4c47017509e1609db6c2e8e2b02327caeb709c986d8b63099695105432afa533,
            y_parity: false
        };

        let signature_0_felt252_arr: Array<felt252> = array![
            signature_0.r.low.into(),
            signature_0.r.high.into(),
            signature_0.s.low.into(),
            signature_0.s.high.into(),
            0x9696a4cb
        ];

        let signature_1_felt252_arr: Array<felt252> = array![
            signature_1.r.low.into(),
            signature_1.r.high.into(),
            signature_1.s.low.into(),
            signature_1.s.high.into(),
            0x0
        ];

        let signature_2_felt252_arr: Array<felt252> = array![
            signature_2.r.low.into(),
            signature_2.r.high.into(),
            signature_2.s.low.into(),
            signature_2.s.high.into(),
            0x0
        ];

        let result: Signature = signature_0_felt252_arr
            .span()
            .try_into_eth_signature(CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_0);

        let result: Signature = signature_1_felt252_arr
            .span()
            .try_into_eth_signature(CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_1);

        let result: Signature = signature_2_felt252_arr
            .span()
            .try_into_eth_signature(CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_2);
    }
}
