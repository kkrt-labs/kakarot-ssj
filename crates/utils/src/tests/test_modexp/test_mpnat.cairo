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
use utils::math::{Bitshift, WrappingBitshift};

// the tests are taken from [aurora-engine](https://github.com/aurora-is-near/aurora-engine/blob/1213f2c7c035aa523601fced8f75bef61b4728ab/engine-modexp/src/mpnat.rs#L825)

#[cfg(test)]
pub fn mp_nat_to_u128(ref x: MPNat) -> u128 {
    let result = x.digits.from_le_to_le_bytes();
    let mut i: usize = 0;
    loop {
        if i == result.len() {
            break;
        };

        i += 1;
    };
    U128Trait::from_le_bytes(result).unwrap()
}

fn check_modpow_even(base: u128, exp: u128, modulus: u128, expected: u128) {
    let mut x = MPNatTrait::from_big_endian(base.to_be_bytes());
    let mut m = MPNatTrait::from_big_endian(modulus.to_be_bytes());
    let mut result = x.modpow(exp.to_be_bytes_padded(), ref m);
    let result = mp_nat_to_u128(ref result);
    assert_eq!(result, expected);
}

fn check_modpow_with_power_of_two(base: u128, exp: u128, modulus: u128, expected: u128) {
    let mut x = MPNatTrait::from_big_endian(base.to_be_bytes());
    let mut m = MPNatTrait::from_big_endian(modulus.to_be_bytes());
    let mut result = x.modpow_with_power_of_two(exp.to_be_bytes(), ref m);
    let result = mp_nat_to_u128(ref result);
    assert_eq!(result, expected);
}

fn check_modpow_montgomery(base: u128, exp: u128, modulus: u128, expected: u128) {
    let mut x = MPNatTrait::from_big_endian(base.to_be_bytes());
    let mut m = MPNatTrait::from_big_endian(modulus.to_be_bytes());
    let mut result = x.modpow_montgomery(exp.to_be_bytes(), ref m);
    let result = mp_nat_to_u128(ref result);
    assert_eq!(result, expected, "({base} ^ {exp}) % {modulus} failed check_modpow_montgomery");
}

fn check_sub_to_same_size(a: u128, n: u128) {
    let mut x = MPNatTrait::from_big_endian(a.to_be_bytes());
    let mut y = MPNatTrait::from_big_endian(n.to_be_bytes());
    x.sub_to_same_size(ref y);

    assert!(x.digits.len() <= y.digits.len());
    let result = mp_nat_to_u128(ref x);
    assert_eq!(result % n, a % n, "{a} % {n} failed sub_to_same_size check");
}


fn check_is_odd(n: u128) {
    let mut mp = MPNatTrait::from_big_endian(n.to_be_bytes());
    assert_eq!(mp.is_odd(), n % 2 == 1, "{n} failed is_odd test");
}

fn check_is_p2(n: u128, expected_result: bool) {
    let mut mp = MPNatTrait::from_big_endian(n.to_be_bytes());
    assert_eq!(mp.is_power_of_two(), expected_result, "{n} failed is_power_of_two test");
}

#[test]
#[available_gas(100000000000000)]
fn test_modpow_even() {
    check_modpow_even(3, 5, 500, 243);
    check_modpow_even(3, 5, 20, 3);
    check_modpow_even(
        0x2ff4f4df4c518867207c84b57a77aa50,
        0xca83c2925d17c577c9a03598b6f360,
        0xf863d4f17a5405d84814f54c92f803c8,
        0x8d216c9a1fb275ed18eb340ed43cacc0,
    );
    check_modpow_even(
        0x13881e1614244c56d15ac01096b070e7,
        0x336df5b4567cbe4c093271dc151e6c72,
        0x7540f399a0b6c220f1fc60d2451a1ff0,
        0x1251d64c552e8f831f5b841d2811f9c1,
    );
    check_modpow_even(
        0x774d5b2494a449d8f22b22ea542d4ddf,
        0xd2f602e1688f271853e7794503c2837e,
        0xa80d20ebf75f92192159197b60f36e8e,
        0x3fbbba42489b27fc271fb39f54aae2e1,
    );
    check_modpow_even(
        0x756e409cc3583a6b68ae27ccd9eb3d50,
        0x16dafb38a334288954d038bedbddc970,
        0x1f9b2237f09413d1fc44edf9bd02b8bc,
        0x9347445ac61536a402723cd07a3f5a4,
    );
    check_modpow_even(
        0x6dcb8405e2cc4dcebee3e2b14861b47d,
        0xe6c1e5251d6d5deb8dddd0198481d671,
        0xe34a31d814536e8b9ff6cc5300000000,
        0xaa86af638386880334694967564d0c3d,
    );
    check_modpow_even(
        0x9c12fe4a1a97d17c1e4573247a43b0e5,
        0x466f3e0a2e8846b8c48ecbf612b96412,
        0x710d7b9d5718acff0000000000000000,
        0x569bf65929e71cd10a553a8623bdfc99,
    );
    check_modpow_even(
        0x6d018fdeaa408222cb10ff2c36124dcf,
        0x8e35fc05d490bb138f73c2bc284a67a7,
        0x6c237160750d78400000000000000000,
        0x3fe14e11392c6c6be8efe956c965d5af,
    );
}

#[test]
fn test_modpow_with_power_of_two() {
    check_modpow_with_power_of_two(3, 2, 1.wrapping_shl(30), 9);
    check_modpow_with_power_of_two(3, 5, 1.wrapping_shl(30), 243);
    check_modpow_with_power_of_two(3, 1_000_000, 1.wrapping_shl(30), 641836289);
    check_modpow_with_power_of_two(3, 1_000_000, 1.wrapping_shl(31), 1715578113);
    check_modpow_with_power_of_two(3, 1_000_000, 1.wrapping_shl(32), 3863061761);
    check_modpow_with_power_of_two(
        0xabcd_ef01_2345_6789_1111, 0x1234_5678_90ab_cdef, 1.wrapping_shl(5), 17,
    );
    check_modpow_with_power_of_two(
        0x3f47_9dc0_d5b9_6003,
        0xa180_e045_e314_8581,
        1.wrapping_shl(118),
        0x0028_3d19_e6cc_b8a0_e050_6abb_b9b1_1a03,
    );
}

#[test]
#[available_gas(100000000000000)]
fn test_modpow_montgomery() {
    check_modpow_montgomery(3, 5, 0x9346_9d50_1f74_d1c1, 243);
    check_modpow_montgomery(3, 5, 19, 15);
    check_modpow_montgomery(
        0x5c4b74ec760dfb021499f5c5e3c69222,
        0x62b2a34b21cf4cc036e880b3fb59fe09,
        0x7b799c4502cd69bde8bb12601ce3ff15,
        0x10c9d9071d0b86d6a59264d2f461200,
    );
    check_modpow_montgomery(
        0xadb5ce8589030e3a9112123f4558f69c,
        0xb002827068f05b84a87431a70fb763ab,
        0xc4550871a1cfc67af3e77eceb2ecfce5,
        0x7cb78c0e1c1b43f6412e9d1155ea96d2,
    );
    check_modpow_montgomery(
        0x26eb51a5d9bf15a536b6e3c67867b492,
        0xddf007944a79bf55806003220a58cc6,
        0xc96275a80c694a62330872b2690f8773,
        0x23b75090ead913def3a1e0bde863eda7,
    );
    check_modpow_montgomery(
        0xb93fa81979e597f548c78f2ecb6800f3,
        0x5fad650044963a271898d644984cb9f0,
        0xbeb60d6bd0439ea39d447214a4f8d3ab,
        0x354e63e6a5e007014acd3e5ea88dc3ad,
    );
    check_modpow_montgomery(
        0x1993163e4f578869d04949bc005c878f,
        0x8cb960f846475690259514af46868cf5,
        0x52e104dc72423b534d8e49d878f29e3b,
        0x2aa756846258d5cfa6a3f8b9b181a11c,
    );
}

#[test]
fn test_sub_to_same_size() {
    check_sub_to_same_size(0x10_00_00_00_00, 0xFF_00_00_00);
    check_sub_to_same_size(0x10_00_00_00_00, 0x01_00_00_00);
    check_sub_to_same_size(0x35_00_00_00_00, 0x01_00_00_00);
    check_sub_to_same_size(0xEF_00_00_00_00_00_00, 0x02_FF_FF_FF);

    let n = 10;
    let a = 57 + 2 * n + 0x1234_0000_0000 * n + 0x000b_0000_0000_0000_0000 * n;
    check_sub_to_same_size(a, n);

    // Test that borrow equals self_most_sig at end of sub_to_same_size */
    {
        let mut x = MPNatTrait::from_big_endian(
            array![
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0xae,
                0x5f,
                0xf0,
                0x8b,
                0xfc,
                0x02,
                0x71,
                0xa4,
                0xfe,
                0xe0,
                0x49,
                0x02,
                0xc9,
                0xd9,
                0x12,
                0x61,
                0x8e,
                0xf5,
                0x02,
                0x2c,
                0xa0,
                0x00,
                0x00,
                0x00,
            ]
                .span()
        );
        let mut y = MPNatTrait::from_big_endian(
            array![
                0xae,
                0x5f,
                0xf0,
                0x8b,
                0xfc,
                0x02,
                0x71,
                0xa4,
                0xfe,
                0xe0,
                0x49,
                0x0f,
                0x70,
                0x00,
                0x00,
                0x00,
            ]
                .span()
        );
        x.sub_to_same_size(ref y);
    }

    // Additional test for sub_to_same_size q_hat/r_hat adjustment logic */
    {
        let mut x = MPNatTrait::from_big_endian(
            array![
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0xff,
                0xff,
                0xff,
                0xff,
                0x00,
                0x00,
                0x00,
                0x00,
                0x01,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
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
        let mut y = MPNatTrait::from_big_endian(
            array![
                0xff,
                0xff,
                0xff,
                0xff,
                0x00,
                0x00,
                0x00,
                0x00,
                0xff,
                0xff,
                0xff,
                0xff,
                0xff,
                0x00,
                0x00,
                0x00,
            ]
                .span()
        );
        x.sub_to_same_size(ref y);
    }
}

#[test]
#[available_gas(100000000000000)]
fn test_mp_nat_is_odd() {
    let mut n = 0;
    loop {
        if n == 1025 {
            break;
        };
        check_is_odd(n);

        n += 1;
    };

    let mut n = 0xFF_FF_FF_FF_00_00_00_00;

    loop {
        if n == 0xFF_FF_FF_FF_00_00_04_01 {
            break;
        }

        check_is_odd(n);
        n += 1;
    };
}

#[test]
fn test_mp_nat_is_power_of_two() {
    check_is_p2(0, false);
    check_is_p2(1, true);
    check_is_p2(1327, false);
    check_is_p2((1.shl(1)) + (1.shl(35)), false);
    check_is_p2(1.shl(1), true);
    check_is_p2(1.shl(2), true);
    check_is_p2(1.shl(3), true);
    check_is_p2(1.shl(4), true);
    check_is_p2(1.shl(5), true);
    check_is_p2(1.shl(31), true);
    check_is_p2(1.shl(32), true);
    check_is_p2(1.shl(64), true);
    check_is_p2(1.shl(65), true);
    check_is_p2(1.shl(127), true);
}
