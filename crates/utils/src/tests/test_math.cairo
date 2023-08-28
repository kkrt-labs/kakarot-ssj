use integer::{u256_overflowing_add, BoundedInt, u512};
use utils::math::{Exponentiation, WrappingExponentiation, u256_wide_add, Bitwise};

#[test]
#[available_gas(20000000)]
fn test_wrapping_pow() {
    assert(5_u256.wrapping_pow(10) == 9765625, '5^10 should be 9765625');
    assert(2_u256.wrapping_pow(256) == 0, 'should wrap to 0');
    assert(123456_u256.wrapping_pow(0) == 1, 'n^0 should be 1');
    assert(0_u256.wrapping_pow(123456) == 0, '0^n should be 0');
    assert(
        2_felt252
            .wrapping_pow(252) == 0x7ffffffffffffeeffffffffffffffffffffffffffffffffffffffffffffffff,
        '2^252 should wrap around'
    );
}

#[test]
#[available_gas(20000000)]
fn test_pow() {
    assert(5_u256.pow(10) == 9765625, '5^10 should be 9765625');
    assert(123456_u256.pow(0) == 1, 'n^0 should be 1');
    assert(0_u256.pow(123456) == 0, '0^n should be 0');
}

#[test]
#[should_panic(expected: ('u256_mul Overflow',))]
#[available_gas(20000000)]
fn test_pow_should_overflow() {
    2_u256.pow(256);
}


#[test]
#[available_gas(2000000)]
fn test_wide_add_basic() {
    let a = 1000;
    let b = 500;

    let (sum, overflow) = u256_overflowing_add(a, b);

    let expected = u512 { limb0: 1500, limb1: 0, limb2: 0, limb3: 0, };

    let result = u256_wide_add(a, b);

    assert(!overflow, 'shouldnt overflow');
    assert(result == expected, 'wrong result');
}

#[test]
#[available_gas(2000000)]
fn test_wide_add_overflow() {
    let a = BoundedInt::<u256>::max();
    let b = 1;

    let (sum, overflow) = u256_overflowing_add(a, b);

    let expected = u512 { limb0: 0, limb1: 0, limb2: 1, limb3: 0, };

    let result = u256_wide_add(a, b);

    assert(overflow, 'should overflow');
    assert(result == expected, 'wrong result');
}

#[test]
#[available_gas(2000000)]
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
#[available_gas(2000000)]
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
#[available_gas(2000000000000)]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_shl_256_bits_overflow() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 32 * 8;

    // When & Then 2.pow(256) overflows u256
    let result = a.shl(shift);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_shl_overflow() {
    // Given
    let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
    // 1-byte shift is an 8-bit shift
    let shift = 4 * 8;

    // When & Then a << 32 overflows u256 
    let result = a.shl(shift);
}

#[test]
#[available_gas(2000000000000)]
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
#[available_gas(2000000)]
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
#[available_gas(20000000)]
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
#[available_gas(20000000000)]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_shr_256_bits_overflow() {
    let a = 0xab91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
    let shift = 32 * 8;

    // When & Then 2.pow(256) overflows u256
    let result = a.shr(shift);
}


#[test]
#[available_gas(20000000)]
fn test_bitshift_right_wide() {
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
#[available_gas(20000000000)]
fn test_bitshift_right_wide_to_zero() {
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

