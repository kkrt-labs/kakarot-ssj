use alexandria_data_structures::vec::VecTrait;
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::result::ResultTrait;
use core::traits::Into;

use utils::crypto::modexp::arith::{
    mod_inv, monsq, monpro, compute_r_mod_n, in_place_shl, in_place_shr, big_wrapping_pow,
    big_wrapping_mul, big_sq, borrowing_sub, shifted_carrying_mul
};
use utils::crypto::modexp::mpnat::{
    MPNat, MPNatTrait, WORD_MAX, DOUBLE_WORD_MAX, Word, DoubleWord, WORD_BYTES
};
use utils::helpers::{Felt252VecTrait, Felt252VecU64Trait};
use utils::helpers::{U128Trait, U32Trait};
use utils::math::{u64_wrapping_mul};

// the tests are taken from [aurora-engine](https://github.com/aurora-is-near/aurora-engine/blob/1213f2c7c035aa523601fced8f75bef61b4728ab/engine-modexp/src/arith.rs#L401)

fn check_monsq(x: u128, n: u128) {
    let mut a = MPNatTrait::from_big_endian(x.to_be_bytes_padded().span());
    let mut m = MPNatTrait::from_big_endian(n.to_be_bytes_padded().span());
    let n_prime = WORD_MAX - mod_inv(m.digits[0]) + 1;

    let mut output = Felt252VecImpl::new();
    output.resize(2 * m.digits.len() + 1, 0);

    monsq(ref a, ref m, n_prime, ref output);
    let mut result = MPNat { digits: output };

    let mut output = Felt252VecImpl::new();
    output.resize(m.digits.len() + 2, 0);
    let mut tmp = MPNat { digits: a.digits.duplicate() };
    monpro(ref a, ref tmp, ref m, n_prime, ref output);

    let mut expected = MPNat { digits: output };

    assert!(result.digits.equal(ref expected.digits));
}

fn check_monpro(x: u128, y: u128, n: u128, ref expected: MPNat) {
    let mut a = MPNatTrait::from_big_endian(x.to_be_bytes_padded().span());
    let mut b = MPNatTrait::from_big_endian(y.to_be_bytes_padded().span());
    let mut m = MPNatTrait::from_big_endian(n.to_be_bytes().span());
    let n_prime = WORD_MAX - mod_inv(m.digits[0]) + 1;

    let mut output = Felt252VecImpl::new();
    output.resize(m.digits.len() + 2, 0);
    monpro(ref a, ref b, ref m, n_prime, ref output);
    let mut result = MPNat { digits: output };

    assert!(result.digits.equal(ref expected.digits));
}


fn check_r_mod_n(n: u128, ref expected: MPNat) {
    let mut x = MPNatTrait::from_big_endian(n.to_be_bytes_padded().span());
    let mut out: Felt252Vec<Word> = Felt252VecImpl::new();
    out.expand(x.digits.len()).unwrap();
    compute_r_mod_n(ref x, ref out);
    let mut result = MPNat { digits: out };
    assert!(result.digits.equal(ref expected.digits));
}

fn check_in_place_shl(n: u128, shift: u32, ref expected: MPNat) {
    let mut x = MPNatTrait::from_big_endian(n.to_be_bytes_padded().span());
    in_place_shl(ref x.digits, shift);
    let mut result = x;

    assert!(result.digits.equal(ref expected.digits));
}

fn check_in_place_shr(n: u128, shift: u32, ref expected: MPNat) {
    let mut x = MPNatTrait::from_big_endian(n.to_be_bytes_padded().span());
    in_place_shr(ref x.digits, shift);
    let mut result = x;

    assert!(result.digits.equal(ref expected.digits));
}

fn check_mod_inv(n: Word) {
    let n_inv = mod_inv(n);
    assert_eq!(u64_wrapping_mul(n, n_inv), 1);
}

fn check_big_wrapping_pow(a: u128, b: u32, expected_bytes: Span<u8>) {
    let mut x = MPNatTrait::from_big_endian(a.to_be_bytes_padded().span());
    let mut y = b.to_be_bytes_padded().span();

    let mut scratch = Felt252VecImpl::new();
    scratch.expand(1 + (expected_bytes.len() / WORD_BYTES)).unwrap();

    let mut result = big_wrapping_pow(ref x, y, ref scratch);

    let mut expected = MPNatTrait::from_big_endian(expected_bytes);
    assert!(result.digits.equal(ref expected.digits));
}

fn check_big_wrapping_mul(a: u128, b: u128, output_digits: usize, ref expected: MPNat) {
    let mut x = MPNatTrait::from_big_endian(a.to_be_bytes_padded().span());
    let mut y = MPNatTrait::from_big_endian(b.to_be_bytes_padded().span());

    let mut out = Felt252VecImpl::new();
    out.expand(output_digits).unwrap();

    big_wrapping_mul(ref x, ref y, ref out);
    let mut result = MPNat { digits: out };

    assert!(result.digits.equal(ref expected.digits));
}

fn check_big_sq(a: u128, ref expected: MPNat) {
    let mut x = MPNatTrait::from_big_endian(a.to_be_bytes_padded().span());
    let mut out = Felt252VecImpl::new();
    out.expand(2 * x.digits.len() + 1).unwrap();

    big_sq(ref x, ref out);

    let mut result = MPNat { digits: out };
    assert!(result.digits.equal(ref expected.digits));
}

#[test]
fn test_monsq_alpha() {
    let mut x = Felt252VecImpl::new();
    x.push(0xf72fc634c83435bc);
    x.push(0xa6b0ce70ac511873);
    let mut x = MPNat { digits: x };

    let mut y = Felt252VecImpl::new();
    y.push(0xf3e77eceb2ecfce5);
    y.push(0xc4550871a1cfc67a);
    let mut y = MPNat { digits: y };

    let n_prime = 0xa51080a4eb8b9f13;
    let mut scratch = Felt252VecImpl::new();
    scratch.expand(5).unwrap();

    monsq(ref x, ref y, n_prime, ref scratch);
}


#[test]
fn test_monsq_0() {
    check_monsq(1, 31);
}

#[test]
fn test_monsq_1() {
    check_monsq(6, 31);
}

#[test]
fn test_monsq_2() {
    // This example is intentionally chosen because 5 * 5 = 25 = 0 mod 25,
    // therefore it requires the final subtraction step in the algorithm.
    check_monsq(5, 25);
}

#[test]
fn test_monsq_3() {
    check_monsq(0x1FFF_FFFF_FFFF_FFF0, 0x1FFF_FFFF_FFFF_FFF1);
}

#[test]
fn test_monsq_4() {
    check_monsq(0x16FF_221F_CB7D, 0x011E_842B_6BAA_5017_EBF2_8293);
}

#[test]
fn test_monsq_5() {
    check_monsq(0x0A2D_63F5_CFF9, 0x1F3B_3BD9_43EF);
}

#[test]
fn test_monsq_6() {
    check_monsq(0xa6b0ce71a380dea7c83435bc, 0xc4550871a1cfc67af3e77eceb2ecfce5,);
}

#[test]
fn test_monpro_0() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(2);
    let mut expected = MPNat { digits: expected_digits };

    check_monpro(1, 1, 31, ref expected);
}

#[test]
fn test_monpro_1() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(22);
    let mut expected = MPNat { digits: expected_digits };

    check_monpro(6, 7, 31, ref expected);
}

#[test]
fn test_monpro_2() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);
    let mut expected = MPNat { digits: expected_digits };

    // This example is intentionally chosen because 5 * 7 = 35 = 0 mod 35,
    // therefore it requires the final subtraction step in the algorithm.
    check_monpro(5, 7, 35, ref expected);
}

#[test]
fn test_monpro_3() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(384307168202282284);

    let mut expected = MPNat { digits: expected_digits };

    // This example is intentionally chosen because 5 * 7 = 35 = 0 mod 35,
    // therefore it requires the final subtraction step in the algorithm.
    check_monpro(0x1FFF_FFFF_FFFF_FFF0, 0x1234, 0x1FFF_FFFF_FFFF_FFF1, ref expected);
}

#[test]
fn test_monpro_4() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);
    let mut expected = MPNat { digits: expected_digits };

    // This example is intentionally chosen because 5 * 7 = 35 = 0 mod 35,
    // therefore it requires the final subtraction step in the algorithm.
    check_monpro(0x16FF_221F_CB7D, 0x0C75_8535_434F, 0x011E_842B_6BAA_5017_EBF2_8293, ref expected);
}

#[test]
fn test_monpro_5() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(4425093052866);
    let mut expected = MPNat { digits: expected_digits };

    // This example is intentionally chosen because 5 * 7 = 35 = 0 mod 35,
    // therefore it requires the final subtraction step in the algorithm.
    check_monpro(0x0A2D_63F5_CFF9, 0x1B21_FF3C_FA8E, 0x1F3B_3BD9_43EF, ref expected);
}

#[test]
fn test_r_mod_n_0() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);
    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0x01_00_00_00_01, ref expected);
}

#[test]
fn test_r_mod_n_1() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(549722259457);
    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0x80_00_00_00_01, ref expected);
}

#[test]
fn test_r_mod_n_2() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);
    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0xFFFF_FFFF_FFFF_FFFF, ref expected);
}

#[test]
fn test_r_mod_n_3() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);
    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0x0001_0000_0000_0000_0001, ref expected);
}

#[test]
fn test_r_mod_n_4() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(18446181123756130305);
    expected_digits.push(32767);

    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0x8000_0000_0000_0000_0001, ref expected);
}

#[test]
fn test_r_mod_n_5() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(3491005389787767287);
    expected_digits.push(2668502225);

    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0xbf2d_c9a3_82c5_6e85_b033_7651, ref expected);
}

#[test]
fn test_r_mod_n_6() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(4294967296);

    let mut expected = MPNat { digits: expected_digits };

    check_r_mod_n(0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF, ref expected);
}

#[test]
fn test_in_place_shl_0() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shl(0, 0, ref expected);
}

#[test]
fn test_in_place_shl_1() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1024);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shl(1, 10, ref expected);
}

#[test]
fn test_in_place_shl_2() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(18446744073709551584);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shl(WORD_MAX.into(), 5, ref expected);
}


#[test]
fn test_in_place_shl_3() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(18446744073709486080);
    expected_digits.push(18446744073709551615);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shl(DOUBLE_WORD_MAX, 16, ref expected);
}

#[test]
fn test_in_place_shr_0() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shr(0, 0, ref expected);
}

#[test]
fn test_in_place_shr_1() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shr(1, 10, ref expected);
}

#[test]
fn test_in_place_shr_2() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(298261);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shr(0x1234_5678, 10, ref expected);
}

#[test]
fn test_in_place_shr_3() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(576460752303423487);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shr(WORD_MAX.into(), 5, ref expected);
}

#[test]
fn test_in_place_shr_4() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(18446744073709551615);
    expected_digits.push(281474976710655);

    let mut expected = MPNat { digits: expected_digits };

    check_in_place_shr(DOUBLE_WORD_MAX.into(), 16, ref expected);
}

#[test]
#[available_gas(10000000000000)]
fn test_mod_inv_0() {
    let mut i = 1;
    loop {
        if i == 1025 {
            break;
        };

        check_mod_inv(2 * i - 1);
        i += 1;
    }
}

#[test]
#[available_gas(10000000000000)]
fn test_mod_inv_1() {
    let mut i = 0;
    loop {
        if i == 1025 {
            break;
        };

        check_mod_inv(0xFF_FF_FF_FF - 2 * i);
        i += 1;
    }
}

#[test]
fn test_big_wrapping_pow_0() {
    let expected_bytes: Span<u8> = array![1].span();
    check_big_wrapping_pow(1, 1, expected_bytes);
}

#[test]
fn test_big_wrapping_pow_1() {
    let expected_bytes: Span<u8> = array![100].span();

    check_big_wrapping_pow(10, 2, expected_bytes);
}

#[test]
fn test_big_wrapping_pow_2() {
    let expected_bytes: Span<u8> = array![1, 0, 0, 0, 0].span();

    check_big_wrapping_pow(2, 32, expected_bytes);
}

#[test]
fn test_big_wrapping_pow_3() {
    let expected_bytes: Span<u8> = array![1, 0, 0, 0, 0, 0, 0, 0, 0].span();
    check_big_wrapping_pow(2, 64, expected_bytes);
}

#[test]
#[available_gas(10000000000000)]
fn test_big_wrapping_pow_4() {
    let expected_bytes: Span<u8> = array![
        3,
        218,
        116,
        252,
        230,
        21,
        167,
        46,
        59,
        185,
        199,
        194,
        149,
        140,
        133,
        157,
        60,
        102,
        160,
        27,
        104,
        79,
        16,
        104,
        20,
        104,
        116,
        207,
        214,
        100,
        237,
        159,
        0,
        245,
        249,
        156,
        52,
        33,
        217,
        113,
        130,
        6,
        65,
        78,
        49,
        141,
        141,
        160,
        29,
        125,
        168,
        236,
        88,
        174,
        146,
        81,
        137,
        165,
        242,
        90,
        251,
        115,
        144,
        169,
        141,
        66,
        207,
        230,
        56,
        199,
        140,
        109,
        7,
        99,
        35,
        155,
        88,
        29,
        90,
        192,
        55,
        127,
        112,
        26,
        176,
        181,
        13,
        72,
        107,
        209,
        1,
        210,
        88,
        233,
        185,
        87,
        108,
        122,
        168,
        137,
        255,
        36,
        201,
        185,
        31,
        36,
        51,
        208,
        64,
        154,
        113,
        233,
        71,
        95,
        35,
        253,
        0,
        3,
        159,
        183,
        10,
        83,
        233,
        88,
        96,
        19,
        104,
        229,
        132,
        73,
        219,
        152,
        126,
        215,
        249,
        46,
        110,
        157,
        234,
        2,
        100,
        178,
        150,
        110,
        217,
        246,
        128,
        219,
        121,
        21,
        234,
        55,
        101,
        81,
        207,
        191,
        200,
        201,
        2,
        40,
        13,
        80,
        107,
        226,
        143,
        164,
        254,
        91,
        54,
        46,
        254,
        7,
        14,
        136,
        149,
        194,
        6,
        191,
        14,
        49,
        140,
        193,
        40,
        1,
        138,
        165,
        82,
        34,
        33,
        169,
        41,
        136,
        130,
        47,
        84,
        173,
        58,
        121,
        192,
        247,
        98,
        237,
        165,
        215,
        161,
        198,
        87,
        228,
        76,
        160,
        66,
        78,
        169,
        139,
        234,
        169,
        83,
        15,
        16,
        192,
        170,
        71,
        227,
        232,
        116,
        189,
        81,
        64,
        104,
        182,
        129,
        203,
        191,
        210,
        151,
        132,
        254,
        239,
        19,
        138,
        49,
        113,
        140,
        77,
        38,
        49,
        117,
        127,
        203,
        123,
        127,
        49,
        32,
        61,
        108,
        120,
        133,
        119,
        8,
        232,
        84,
        57,
        103,
        197,
        160,
        65,
        191,
        82,
        253,
        60,
        191,
        209,
        63,
        176,
        43,
        33,
        54,
        75,
        17,
        73,
        222,
        198,
        80,
        5,
        14,
        50,
        117,
        156,
        77,
        147,
        190,
        230,
        143,
        47,
        149,
        180,
        203,
        144,
        202,
        102,
        231,
        2,
        91,
        22,
        101,
        178,
        211,
        233,
        109,
        156,
        72,
        151,
        199,
        189,
        90,
        76,
        21,
        112,
        21,
        2,
        44,
        96,
        42,
        141,
        217,
        142,
        23,
        75,
        248,
        209,
        26,
        3,
        198,
        103,
        227,
        103,
        140,
        99,
        75,
        211,
        152,
        109,
        19,
        72,
        6,
        116,
        67,
        70,
        32,
        45,
        5,
        113,
        179,
        252,
        2,
        202,
        115,
        244,
        68,
        128,
        156,
        233,
        227,
        211,
        5,
        146,
        147,
        186,
        34,
        3,
        105,
        147,
        64,
        79,
        172,
        141,
        14,
        60,
        69,
        249,
        169,
        76,
        252,
        84,
        151,
        49,
        81,
        246,
        185,
        181,
        181,
        226,
        28,
        152,
        30,
        47,
        248,
        103,
        21,
        184,
        140,
        193,
        112,
        139,
        250,
        206,
        35,
        180,
        122,
        32,
        151,
        105,
        30,
        193,
        68,
        232,
        170,
        174,
        254,
        143,
        29,
        165,
        194,
        14,
        164,
        35,
        25,
        250,
        86,
        76,
        213,
        159,
        21,
        0,
        212,
        146,
        21,
        8,
        180,
        73,
        250,
        116,
        137,
        221,
        20,
        22,
        146,
        169,
        120,
        166,
        229,
        226,
        136,
        201,
        177,
        49,
        21,
        228,
        191,
        246,
        26,
        36,
        183,
        175,
        137,
        71,
        4,
        46,
        235,
        197,
        99,
        0,
        142,
        97,
        184,
        34,
        84,
        254,
        41,
        95,
        198,
        178,
        48,
        105,
        215,
        72,
        155,
        238,
        51,
        164,
        52,
        179,
        126,
        254,
        100,
        35,
        236,
        63,
        215,
        238,
        217,
        239,
        229,
        160,
        192,
        33,
        82,
        165,
        81,
        149,
        186,
        53,
        109,
        184,
        187,
        186,
        8,
        43,
        249,
        20,
        37,
        255,
        241,
        18,
        61,
        97,
        229,
        29,
        201,
        144,
        92,
        202,
        215,
        161,
        165,
        133,
        89,
        180,
        246,
        37,
        16,
        133,
        226,
        209,
        23,
        61,
        241,
        25,
        9,
        150,
        154,
        150,
        133,
        210,
        62,
        115,
        34,
        201,
        187,
        217,
        3,
        82,
        102,
        174,
        233,
        33,
        31,
        7,
        4,
        88,
        70,
        173,
        157,
        111,
        96,
        102,
        223,
        157,
        224,
        158,
        235,
        191,
        55,
        219,
        218,
        146,
        233,
        242,
        250,
        170,
        100,
        68,
        37,
        56,
        251,
        109,
        112,
        217,
        209,
        46,
        229,
        198,
        198,
        156,
        198,
        70,
        76,
        131,
        79,
        40,
        25,
        176,
        21,
        43,
        31,
        121,
        204,
        225,
        128,
        182,
        191,
        148,
        72,
        22,
        112,
        63,
        223,
        182,
        155,
        177,
        183,
        72,
        111,
        6,
        196,
        250,
        189,
        45,
        97,
        182,
        14,
        219,
        189,
        50,
        226,
        91,
        1,
        86,
        95,
        131,
        120,
        224,
        0,
        71,
        28,
        151,
        69,
        24,
        93,
        82,
        237,
        136,
        103,
        90,
        247,
        173,
        204,
        121,
        199,
        17,
        164,
        80,
        49,
        183,
        10,
        200,
        235,
        56,
        72,
        72,
        147,
        150,
        223,
        110,
        165,
        60,
        13,
        251,
        42,
        193,
        78,
        212,
        166,
        178,
        103,
        19,
        35,
        69,
        10,
        137,
        62,
        13,
        90,
        203,
        126,
        203,
        207,
        190,
        184,
        89,
        118,
        186,
        203,
        6,
        115,
        158,
        168,
        35,
        206,
        227,
        48,
        221,
        252,
        190,
        166,
        249,
        96,
        92,
        244,
        77,
        213,
        119,
        44,
        207,
        17,
        16,
        118,
        104,
        106,
        188,
        205,
        5,
        240,
        14,
        181,
        227,
        4,
        11,
        32,
        91,
        224,
        78,
        175,
        49,
        19,
        12,
        233,
        131,
        141,
        47,
        32,
        14,
        195,
        214,
        77,
        158,
        39,
        114,
        167,
        37,
        16,
        249,
        73,
        167,
        230,
        165,
        19,
        4,
        199,
        227,
        251,
        184,
        131,
        137,
        74,
        176,
        116,
        35,
        182,
        121,
        62,
        114,
        64,
        163,
        84,
        208,
        111,
        56,
        191,
        88,
        130,
        64,
        64,
        181,
        162,
        53,
        34,
        16,
        179,
        155,
        137,
        138,
        101,
        121,
        73,
        234,
        189,
        100,
        141,
        122,
        123,
        79,
        200,
        90,
        208,
        83,
        253,
        124,
        125,
        116,
        72,
        138,
        63,
        42,
        144,
        200,
        73,
        233,
        113,
        143,
        85,
        140,
        16,
        240,
        230,
        42,
        114,
        137,
        193,
        10,
        129,
        124,
        193,
        104,
        177,
        55,
        156,
        173,
        135,
        168,
        217,
        1,
        46,
        41,
        132,
        17,
        222,
        178,
        226,
        24,
        108,
        117,
        199,
        171,
        232,
        129,
        82,
        225,
        214,
        105,
        94,
        188,
        72,
        62,
        91,
        193,
        188,
        18,
        33,
        131,
        18,
        194,
        70,
        151,
        187,
        42,
        5,
        62,
        85,
        38,
        134,
        252,
        183,
        227,
        120,
        19,
        152,
        243,
        235,
        114,
        208,
        78,
        57,
        113,
        217,
        182,
        125,
        195,
        64,
        229,
        232,
        54,
        118,
        11,
        119,
        163,
        235,
        12,
        67,
        90,
        246,
        76,
        219,
        200,
        124,
        234,
        41,
        172,
        31,
        167,
        213,
        127,
        100,
        163,
        72,
        44,
        107,
        171,
        229,
        189,
        68,
        201,
        244,
        154,
        27,
        172,
        228,
        234,
        192,
        156,
        127,
        170,
        9,
        78,
        166,
        249,
        154,
        178,
        179,
        172,
        220,
        205,
        220,
        60,
        86,
        98,
        134,
        60,
        134,
        89,
        244,
        187,
        231,
        128,
        6,
        109,
        152,
        251,
        44,
        208,
        238,
        169,
        71,
        51,
        192,
        242,
        57,
        8,
        62,
        206,
        94,
        94,
        25,
        220,
        160,
        175,
        35,
        113,
        66,
        42,
        134,
        241,
        57,
        253,
        44,
        244,
        163,
        158,
        152,
        147,
        79,
        142,
        190,
        139,
        222,
        202,
        216,
        220,
        47,
        179,
        207,
        199,
        104,
        1,
        21,
        106,
        142,
        188,
        105,
        247,
        111,
        202,
        78,
        145,
        66,
        216,
        222,
        96,
        138,
        133,
        28,
        235,
        204,
        100,
        183,
        232,
        65,
        138,
        196,
        133,
        23,
        154,
        0,
        187,
        252,
        32,
        106,
        76,
        94,
        129,
        173,
        13,
        79,
        167,
        103,
        54,
        51,
        102,
        224,
        231,
        159,
        127,
        54,
        131,
        122,
        65,
        83,
        195,
        9,
        175,
        45,
        179,
        32,
        118,
        230,
        101,
        85,
        13,
        85,
        234,
        26,
        16,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
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
    check_big_wrapping_pow(2766, 844, expected_bytes);
}

#[test]
fn test_big_wrapping_mul_0() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(0, 0, 1, ref expected);
}


#[test]
fn test_big_wrapping_mul_1() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(1, 1, 1, ref expected);
}

#[test]
fn test_big_wrapping_mul_2() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(42);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(7, 6, 1, ref expected);
}

#[test]
fn test_big_wrapping_mul_3() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);
    expected_digits.push(18446744073709551614);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(WORD_MAX.into(), WORD_MAX.into(), 2, ref expected);
}

#[test]
fn test_big_wrapping_mul_4() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(WORD_MAX.into(), WORD_MAX.into(), 1, ref expected);
}

#[test]
fn test_big_wrapping_mul_5() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(42);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(DOUBLE_WORD_MAX - 5, DOUBLE_WORD_MAX - 6, 2, ref expected);
}

#[test]
fn test_big_wrapping_mul_6() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(6727192404480162174);
    expected_digits.push(3070707315540124665);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(0xa945_aa5e_429a_6d1a, 0x4072_d45d_3355_237b, 3, ref expected);
}

#[test]
fn test_big_wrapping_mul_7() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(2063196614268007784);
    expected_digits.push(7048986299143829482);
    expected_digits.push(14065833420641261004);

    let mut expected = MPNat { digits: expected_digits };

    check_big_wrapping_mul(
        0x8ae1_5515_fc92_b1c0_b473_8ce8_6bbf_7218,
        0x43e9_8b77_1f7c_aa93_6c4c_85e9_7fd0_504f,
        3,
        ref expected
    );
}

#[test]
fn test_big_sq_0() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(0, ref expected);
}

#[test]
fn test_big_sq_1() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(1, ref expected);
}

#[test]
fn test_big_sq_2() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);
    expected_digits.push(18446744073709551614);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(WORD_MAX.into(), ref expected);
}

#[test]
fn test_big_sq_3() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(4);
    expected_digits.push(18446744073709551608);
    expected_digits.push(3);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(2 * WORD_MAX.into(), ref expected);
}

#[test]
fn test_big_sq_4() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(0);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(0, ref expected);
}

#[test]
fn test_big_sq_5() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(2532367871917050473);
    expected_digits.push(16327525306720758713);
    expected_digits.push(15087745550001425684);
    expected_digits.push(5708046406239628566);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(0x8e67904953db9a2bf6da64bf8bda866d, ref expected);
}


#[test]
fn test_big_sq_6() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(15092604974397072849);
    expected_digits.push(3791921091882282235);
    expected_digits.push(12594445234582458012);
    expected_digits.push(7165619740963215273);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(0x9f8dc1c3fc0bf50fe75ac3bbc03124c9, ref expected);
}

#[test]
fn test_big_sq_7() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(5163998055150312593);
    expected_digits.push(8460506958278925118);
    expected_digits.push(17089393176389340230);
    expected_digits.push(6902937458884066534);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(0x9c9a17378f3d064e5eaa80eeb3850cd7, ref expected);
}


#[test]
fn test_big_sq_8() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(2009857620356723108);
    expected_digits.push(5657228334642978155);
    expected_digits.push(88889113116670247);
    expected_digits.push(12075559273075793199);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(0xcf2025cee03025d247ad190e9366d926, ref expected);
}

#[test]
fn test_big_sq_9() {
    let mut expected_digits: Felt252Vec<u64> = Felt252VecImpl::new();
    expected_digits.push(1);
    expected_digits.push(0);
    expected_digits.push(18446744073709551614);
    expected_digits.push(18446744073709551615);

    let mut expected = MPNat { digits: expected_digits };

    check_big_sq(DOUBLE_WORD_MAX, ref expected);
}

// Test for addition overflows in the big_sq inner loop */
#[test]
fn test_big_sq_10() {
    let mut x = MPNatTrait::from_big_endian(
        array![
            0xff,
            0xff,
            0xff,
            0xff,
            0x80,
            0x00,
            0x00,
            0x00,
            0x80,
            0x00,
            0x00,
            0x00,
            0x40,
            0x00,
            0x00,
            0x00,
            0xff,
            0xff,
            0xff,
            0xff,
            0x80,
            0x00,
            0x00,
            0x00,
        ]
            .span()
    );

    let mut out = Felt252VecImpl::new();
    out.expand(2 * x.digits.len() + 1).unwrap();

    big_sq(ref x, ref out);
    let mut result = MPNat { digits: out };

    let mut expected = MPNatTrait::from_big_endian(
        array![
            0xff,
            0xff,
            0xff,
            0xff,
            0x00,
            0x00,
            0x00,
            0x01,
            0x40,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x01,
            0xff,
            0xff,
            0xff,
            0xfe,
            0x40,
            0x00,
            0x00,
            0x01,
            0x90,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0xbf,
            0xff,
            0xff,
            0xff,
            0x00,
            0x00,
            0x00,
            0x00,
            0x40,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
        ]
            .span()
    );

    assert!(result.digits.equal(ref expected.digits));
}

#[test]
fn test_borrowing_sub() {
    assert_eq!(borrowing_sub(0, 0, false), (0, false));
    assert_eq!(borrowing_sub(1, 0, false), (1, false));
    assert_eq!(borrowing_sub(47, 5, false), (42, false));
    assert_eq!(borrowing_sub(101, 7, true), (93, false));
    assert_eq!(borrowing_sub(0x00_00_01_00, 0x00_00_02_00, false), (WORD_MAX - 0xFF, true));
    assert_eq!(borrowing_sub(0x00_00_01_00, 0x00_00_10_00, true), (WORD_MAX - 0x0F_00, true));
}


#[test]
fn test_shifted_carrying_mul() {
    assert_eq!(shifted_carrying_mul(0, 0, 0, 0), (0, 0));
    assert_eq!(shifted_carrying_mul(0, 6, 7, 0), (42, 0));
    assert_eq!(shifted_carrying_mul(0, 6, 7, 8), (50, 0));
    assert_eq!(shifted_carrying_mul(5, 6, 7, 8), (55, 0));
    assert_eq!(
        shifted_carrying_mul(
            WORD_MAX - 0x11, WORD_MAX - 0x1234, WORD_MAX - 0xABCD, WORD_MAX - 0xFF
        ),
        (0x0C_38_0C_94, WORD_MAX - 0xBE00)
    );
    assert_eq!(shifted_carrying_mul(WORD_MAX, WORD_MAX, WORD_MAX, WORD_MAX), (WORD_MAX, WORD_MAX));
}
