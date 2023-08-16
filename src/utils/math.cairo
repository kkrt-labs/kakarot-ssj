use integer::{u256_overflow_mul};

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
