use integer::{u256_overflowing_add, BoundedInt, u512};
use utils::math::{Exponentiation, ExponentiationModulo, u256_wide_add};

#[test]
#[available_gas(20000000)]
fn test_pow_mod() {
    assert(5_u256.pow_mod(10) == 9765625, '5^10 should be 9765625');
    assert(2_u256.pow_mod(256) == 0, 'should wrap to 0');
    assert(123456_u256.pow_mod(0) == 1, 'n^0 should be 1');
    assert(0_u256.pow_mod(123456) == 0, '0^n should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_pow() {
    assert(5_u256.pow(10) == 9765625, '5^10 should be 9765625');
    assert(123456_u256.pow(0) == 1, 'n^0 should be 1');
    assert(0_u256.pow(123456) == 0, '0^n should be 0');
}

#[test]
#[should_panic]
#[available_gas(2000000)]
fn test_pow_should_overflow() {
    assert(2_u256.pow(256) == 0, 'should overflow');
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
