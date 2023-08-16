use integer::{u256_overflow_mul, u256_overflowing_add, u512, BoundedInt};

trait Exponentiation<T> {
    // Raise a number to a power.
    /// * `base` - The number to raise.
    /// * `exp` - The exponent.
    /// # Returns
    /// * `T` - The result of base raised to the power of exp.
    fn pow(self: T, exp: T) -> T;
}

impl U256ExpImpl of Exponentiation<u256> {
    fn pow(self: u256, exp: u256) -> u256 {
        if self == 0 {
            return 0;
        }
        if exp == 0 {
            return 1;
        } else {
            return self * Exponentiation::pow(self, exp - 1);
        }
    }
}

impl Felt252ExpImpl of Exponentiation<felt252> {
    fn pow(self: felt252, exp: felt252) -> felt252 {
        if self == 0 {
            return 0;
        }
        if exp == 0 {
            return 1;
        } else {
            return self * Exponentiation::pow(self, exp - 1);
        }
    }
}


trait ExponentiationModulo<T> {
    // Raise a number to a power modulo MAX<T> (max value of type T).
    // Instead of explicitly providing a modulo, we use overflowing functions
    // from the core library, which wrap around when overflowing.
    /// * `base` - The number to raise.
    /// * `exp` - The exponent.
    /// # Returns
    /// * `T` - The result of base raised to the power of exp modulo MAX<T>.
    fn pow_mod(self: T, exponent: T) -> T;
}

impl U256ExpModImpl of ExponentiationModulo<u256> {
    fn pow_mod(self: u256, mut exponent: u256) -> u256 {
        if self == 0 {
            return 0;
        }
        let mut result = 1;
        loop {
            if exponent == 0 {
                break;
            }
            let (new_result, _) = u256_overflow_mul(result, self);
            result = new_result;
            exponent -= 1;
        };
        result
    }
}

fn u256_wide_add(a: u256, b: u256) -> u512 {
    let (sum, overflow) = u256_overflowing_add(a, b);

    let limb0 = sum.low;
    let limb1 = sum.high;

    let limb2 = if overflow {
        1
    } else {
        0
    };

    let limb3 = 0;

    u512 { limb0, limb1, limb2, limb3 }
}

#[test]
fn test_abc_basic() {
    let a = 1000;
    let b = 500;

    let (sum, overflow) = u256_overflowing_add(a, b);

    let expected = u512 { limb0: 1500, limb1: 0, limb2: 0, limb3: 0,  };

    let result = u256_wide_add(a, b);

    assert(!overflow, 'shouldnt overflow');
    assert(result == expected, 'wrong result');
}

#[test]
fn test_abc_overflow() {
    let a = BoundedInt::<u256>::max();
    let b = 1;

    let (sum, overflow) = u256_overflowing_add(a, b);

    let expected = u512 { limb0: 0, limb1: 0, limb2: 1, limb3: 0,  };

    let result = u256_wide_add(a, b);

    assert(overflow, 'should overflow');
    assert(result == expected, 'wrong result');
}
#[test]
fn test_abc_max_values() {
    let a = BoundedInt::<u256>::max();
    let b = BoundedInt::<u256>::max();

    let (sum, overflow) = u256_overflowing_add(a, b);

    let expected = u512 {
        limb0: 0xfffffffffffffffffffffffffffffffe,
        limb1: 0xffffffffffffffffffffffffffffffff,
        limb2: 1,
        limb3: 0,
    };

    let result = u256_wide_add(a, b);

    assert(overflow, 'should overflow');
    assert(result == expected, 'wrong result');
}

use debug::PrintTrait;

