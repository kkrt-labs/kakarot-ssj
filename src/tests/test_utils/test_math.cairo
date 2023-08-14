use kakarot::utils::math::{Exponentiation, ExponentiationModulo};

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
