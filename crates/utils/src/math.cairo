use integer::{u256_overflow_mul, u256_overflowing_add, u512, BoundedInt};

trait Exponentiation<T> {
    /// Raise a number to a power modulo MAX<T> (max value of type T).
    /// # Panics
    /// Panics if the result overflows the type T.
    fn pow(self: T, exponent: T) -> T;
}

trait WrappingExponentiation<T> {
    /// Raise a number to a power modulo MAX<T> (max value of type T).
    /// Instead of explicitly providing a modulo, we use overflowing functions
    /// from the core library, which wrap around when overflowing.
    /// * `T` - The result of base raised to the power of exp modulo MAX<T>.
    fn wrapping_pow(self: T, exponent: T) -> T;
}

impl U256ExpImpl of Exponentiation<u256> {
    fn pow(self: u256, mut exponent: u256) -> u256 {
        if self == 0 {
            return 0;
        }
        if exponent == 0 {
            return 1;
        } else {
            return self * Exponentiation::pow(self, exponent - 1);
        }
    }
}

impl U256WrappingExponentiationImpl of WrappingExponentiation<u256> {
    fn wrapping_pow(self: u256, mut exponent: u256) -> u256 {
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


impl Felt252WrappingExpImpl of WrappingExponentiation<felt252> {
    fn wrapping_pow(self: felt252, mut exponent: felt252) -> felt252 {
        if self == 0 {
            return 0;
        }
        if exponent == 0 {
            return 1;
        } else {
            // Mul<felt252> wraps around, so we don't need to worry about overflows.
            return self * WrappingExponentiation::wrapping_pow(self, exponent - 1);
        }
    }
}


/// Adds two 256-bit unsigned integers, returning a 512-bit unsigned integer result.
///
/// limb3 will always be 0, because the maximum sum of two 256-bit numbers is at most
/// 2**257 - 2 which fits in 257 bits.
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

trait Bitwise<T> {
    // Shift a number left by a given number of bits.
    // # Panics
    // Panics if the shift is greater than 255.
    // Panics if the result overflows the type T.
    fn left_shift(self: T, shift: T) -> T;

    // Shift a number right by a given number of bits.
    // # Panics
    // Panics if the shift is greater than 255.
    fn right_shift(self: T, shift: T) -> T;

    // Shift a number left by a given number of bits.
    // If the shift is greater than 255, the result is 0.
    // The bits moved after the 256th one are discarded, the new bits are set to 0.
    fn left_shift_wide(self: T, shift: T) -> T;

    // Shift a number right by a given number of bits.
    // If the shift is greater than 255, the result is 0.
    fn right_shift_wide(self: T, shift: T) -> T;
}

impl U256BitwiseImpl of Bitwise<u256> {
    fn left_shift(self: u256, shift: u256) -> u256 {
        self * 2.pow(shift)
    }

    fn right_shift(self: u256, shift: u256) -> u256 {
        self / 2.pow(shift)
    }

    fn left_shift_wide(self: u256, shift: u256) -> u256 {
        let (result, _) = u256_overflow_mul(self, 2.wrapping_pow(shift));
        result
    }

    fn right_shift_wide(self: u256, shift: u256) -> u256 {
        // if we shift by more than 255 bits, the result is 0 (the type is 256 bits wide)
        // we early return to save gas
        // and prevent unexpected behavior, e.g. 2.pow(256) == 0 mod 2^256, given we can't divide by zero
        if shift > 255 {
            return 0;
        }
        self / 2.wrapping_pow(shift)
    }
}
