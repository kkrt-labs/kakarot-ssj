use integer::{u256_overflowing_add, BoundedInt, u512, u256_overflow_mul};
use utils::math::{
    Exponentiation, WrappingExponentiation, u256_wide_add, Bitshift, WrappingBitshift,
    OverflowingMul, WrappingMul, SaturatingAdd
};

#[test]
fn test_wrapping_pow() {
    assert(5_u256.wrapping_pow(10) == 9765625, '5^10 should be 9765625');
    assert(
        5_u256.wrapping_pow(90) == 807793566946316088741610050849573099185363389551639556884765625,
        '5^90 failed'
    );
    assert(2_u256.wrapping_pow(256) == 0, 'should wrap to 0');
    assert(123456_u256.wrapping_pow(0) == 1, 'n^0 should be 1');
    assert(0_u256.wrapping_pow(123456) == 0, '0^n should be 0');
}

#[test]
fn test_pow() {
    assert(5_u256.pow(10) == 9765625, '5^10 should be 9765625');
    assert(5_u256.pow(45) == 28421709430404007434844970703125, '5^45 failed');
    assert(123456_u256.pow(0) == 1, 'n^0 should be 1');
    assert(0_u256.pow(123456) == 0, '0^n should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Out of gas',))]
fn test_wrapping_slow_pow_runs_out_of_gas() {
    let exp = 3_u256.wrapping_fpow(10);
    3_u256.wrapping_spow(exp);
}

#[test]
fn test_wrapping_fast_pow() {
    let exp = 3_u256.wrapping_fpow(10);
    assert(
        3_u256
            .wrapping_fpow(
                exp
            ) == 6701808933569337837891967767170127839253608180143676463326689955522159283811,
        '3^(3^10) failed'
    );
}

#[test]
fn test_wrapping_fast_pow_0() {
    assert(3_u256.wrapping_fpow(0) == 1, '3^(0) should be 1');
}

#[test]
fn test_wrapping_fast_base_0() {
    assert(0_u256.wrapping_fpow(42) == 0, '0^(42) should be 0');
}

#[test]
fn test_wrapping_fast_base_0_pow_0() {
    assert(0_u256.wrapping_fpow(0) == 1, '0^(0) should be 1');
}

#[test]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_pow_should_overflow() {
    2_u256.pow(256);
}


#[test]
fn test_wide_add_basic() {
    let a = 1000;
    let b = 500;

    let (_, overflow) = u256_overflowing_add(a, b);

    let expected = u512 { limb0: 1500, limb1: 0, limb2: 0, limb3: 0, };

    let result = u256_wide_add(a, b);

    assert(!overflow, 'shouldnt overflow');
    assert(result == expected, 'wrong result');
}

#[test]
fn test_wide_add_overflow() {
    let a = BoundedInt::<u256>::max();
    let b = 1;

    let (_, overflow) = u256_overflowing_add(a, b);

    let expected = u512 { limb0: 0, limb1: 0, limb2: 1, limb3: 0, };

    let result = u256_wide_add(a, b);

    assert(overflow, 'should overflow');
    assert(result == expected, 'wrong result');
}

#[test]
fn test_wide_add_max_values() {
    let a = BoundedInt::<u256>::max();
    let b = BoundedInt::<u256>::max();

    let expected = u512 {
        limb0: 0xfffffffffffffffffffffffffffffffe,
        limb1: 0xffffffffffffffffffffffffffffffff,
        limb2: 1,
        limb3: 0,
    };

    let result = u256_wide_add(a, b);

    assert(result == expected, 'wrong result');
}

#[test]
fn test_shl() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 3 * 8;

    // When
    let result = a.shl(shift);

    // Then
    let expected = 0x91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f000000_u256;
    assert(result == expected, 'wrong result');
}


#[test]
#[should_panic(expected: ('mul Overflow',))]
fn test_shl_256_bits_overflow() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 32 * 8;

    // When & Then 2.pow(256) overflows u256
    a.shl(shift);
}

#[test]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_shl_overflow() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 4 * 8;

    // When & Then a << 32 overflows u256
    a.shl(shift);
}

#[test]
fn test_wrapping_shl_overflow() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 12 * 8;

    // When
    let result = a.wrapping_shl(shift);

    // Then
    // The bits moved after the 256th one are discarded, the new bits are set to 0.
    let expected = 0xf24201bac4e64f70ca2b9d9491e82a498faab3fe000000000000000000000000_u256;
    assert(result == expected, 'wrong result');
}


#[test]
fn test_wrapping_shl() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 3 * 8;

    // When
    let result = a.wrapping_shl(shift);

    // Then
    let expected = 0x91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f000000_u256;
    assert(result == expected, 'wrong result');
}

#[test]
fn test_shr() {
    // Given
    let a = 0x0091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 1 * 8;

    // When
    let result = a.shr(shift);

    // Then
    let expected = 0x000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade626_u256;
    assert(result == expected, 'wrong result');
}

#[test]
#[should_panic(expected: ('mul Overflow',))]
fn test_shr_256_bits_overflow() {
    let a = 0xab91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
    let shift = 32 * 8;

    // When & Then 2.pow(256) overflows u256
    a.shr(shift);
}


#[test]
fn test_wrapping_shr() {
    // Given
    let a = 0x0091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 2 * 8;

    // When
    let result = a.wrapping_shr(shift);

    // Then
    let expected = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6_u256;
    assert(result == expected, 'wrong result');
}


#[test]
fn test_wrapping_shr_to_zero() {
    // Given
    let a = 0xab91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 32 * 8;

    // When
    let result = a.wrapping_shr(shift);

    // Then
    let expected = 0_u256;
    assert(result == expected, 'wrong result');
}

#[test]
fn test_u8_overflowing_mul_not_overflow_case() {
    let result = 5_u8.overflowing_mul(10);
    assert_eq!(result, (50, false));
}

#[test]
fn test_u8_overflowing_mul_overflow_case() {
    let result = BoundedInt::<u8>::max().overflowing_mul(BoundedInt::max());
    assert_eq!(result, (1, true));
}

#[test]
fn test_u8_wrapping_mul_not_overflow_case() {
    let result = 5_u8.wrapping_mul(10);
    assert_eq!(result, 50);
}

#[test]
fn test_u8_wrapping_mul_overflow_case() {
    let result = BoundedInt::<u8>::max().wrapping_mul(BoundedInt::max());
    assert_eq!(result, 1);
}

#[test]
fn test_u32_overflowing_mul_not_overflow_case() {
    let result = 5_u32.overflowing_mul(10);
    assert_eq!(result, (50, false));
}

#[test]
fn test_u32_overflowing_mul_overflow_case() {
    let result = BoundedInt::<u32>::max().overflowing_mul(BoundedInt::max());
    assert_eq!(result, (1, true));
}

#[test]
fn test_u32_wrapping_mul_not_overflow_case() {
    let result = 5_u32.wrapping_mul(10);
    assert_eq!(result, 50);
}

#[test]
fn test_u32_wrapping_mul_overflow_case() {
    let result = BoundedInt::<u32>::max().wrapping_mul(BoundedInt::max());
    assert_eq!(result, 1);
}


#[test]
fn test_u64_overflowing_mul_not_overflow_case() {
    let result = 5_u64.overflowing_mul(10);
    assert_eq!(result, (50, false));
}

#[test]
fn test_u64_overflowing_mul_overflow_case() {
    let result = BoundedInt::<u64>::max().overflowing_mul(BoundedInt::max());
    assert_eq!(result, (1, true));
}

#[test]
fn test_u64_wrapping_mul_not_overflow_case() {
    let result = 5_u64.wrapping_mul(10);
    assert_eq!(result, 50);
}

#[test]
fn test_u64_wrapping_mul_overflow_case() {
    let result = BoundedInt::<u64>::max().wrapping_mul(BoundedInt::max());
    assert_eq!(result, 1);
}


#[test]
fn test_u128_overflowing_mul_not_overflow_case() {
    let result = 5_u128.overflowing_mul(10);
    assert_eq!(result, (50, false));
}

#[test]
fn test_u128_overflowing_mul_overflow_case() {
    let result = BoundedInt::<u128>::max().overflowing_mul(BoundedInt::max());
    assert_eq!(result, (1, true));
}

#[test]
fn test_u128_wrapping_mul_not_overflow_case() {
    let result = 5_u128.wrapping_mul(10);
    assert_eq!(result, 50);
}

#[test]
fn test_u128_wrapping_mul_overflow_case() {
    let result = BoundedInt::<u128>::max().wrapping_mul(BoundedInt::max());
    assert_eq!(result, 1);
}

#[test]
fn test_u256_overflowing_mul_not_overflow_case() {
    let result = 5_u256.overflowing_mul(10);
    assert_eq!(result, (50, false));
}

#[test]
fn test_u256_overflowing_mul_overflow_case() {
    let result = BoundedInt::<u256>::max().overflowing_mul(BoundedInt::max());
    assert_eq!(result, (1, true));
}

#[test]
fn test_u256_wrapping_mul_not_overflow_case() {
    let result = 5_u256.wrapping_mul(10);
    assert_eq!(result, 50);
}

#[test]
fn test_u256_wrapping_mul_overflow_case() {
    let result = BoundedInt::<u256>::max().wrapping_mul(BoundedInt::max());
    assert_eq!(result, 1);
}

#[test]
fn test_saturating_add() {
    let max = BoundedInt::<u8>::max();

    assert_eq!(max.saturating_add(1), BoundedInt::<u8>::max());
    assert_eq!((max - 2).saturating_add(1), max - 1);
}
