use integer::{
    u256, u256_overflow_mul, u256_overflowing_add, u512, BoundedInt, u128_overflowing_mul
};
use utils::num::{Zero, One, SizeOf};


// === Exponentiation ===

trait Exponentiation<T> {
    /// Raise a number to a power.
    /// # Panics
    /// Panics if the result overflows the type T.
    fn pow(self: T, exponent: T) -> T;
}

impl ExponentiationImpl<
    T, +Zero<T>, +One<T>, +Add<T>, +Sub<T>, +Mul<T>, +Copy<T>, +Drop<T>
> of Exponentiation<T> {
    fn pow(self: T, mut exponent: T) -> T {
        if self.is_zero() {
            return Zero::zero();
        }
        if exponent.is_zero() {
            return One::one();
        }
        self * self.pow(exponent - One::one())
    }
}

trait WrappingExponentiation<T> {
    /// Raise a number to a power modulo MAX<T> (max value of type T).
    /// Instead of explicitly providing a modulo, we use overflowing functions
    /// from the core library, which wrap around when overflowing.
    /// * `T` - The result of base raised to the power of exp modulo MAX<T>.
    fn wrapping_pow(self: T, exponent: T) -> T;
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

impl U128WrappingExponentiationImpl of WrappingExponentiation<u128> {
    fn wrapping_pow(self: u128, mut exponent: u128) -> u128 {
        if self == 0 {
            return 0;
        }
        let mut result = 1;
        loop {
            if exponent == 0 {
                break;
            }
            let (new_result, _) = u128_overflowing_mul(result, self);
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


// === BitShift ===

trait Bitshift<T> {
    // Shift a number left by a given number of bits.
    // # Panics
    // Panics if the shift is greater than 255.
    // Panics if the result overflows the type T.
    fn shl(self: T, shift: T) -> T;

    // Shift a number right by a given number of bits.
    // # Panics
    // Panics if the shift is greater than 255.
    fn shr(self: T, shift: T) -> T;
}

impl BitshiftImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Mul<T>,
    +Copy<T>,
    +Drop<T>,
    +PartialOrd<T>,
    +SizeOf<T>
> of Bitshift<T> {
    fn shl(self: T, shift: T) -> T {
        // if we shift by more than nb_bits of T, the result is 0
        // we early return to save gas and prevent unexpected behavior
        if shift > shift.size_of() - One::one() {
            panic_with_felt252('mul Overflow');
        }
        let two = One::one() + One::one();
        self * two.pow(shift)
    }

    fn shr(self: T, shift: T) -> T {
        // early return to save gas if shift > nb_bits of T
        if shift > shift.size_of() - One::one() {
            panic_with_felt252('mul Overflow');
        }
        let two = One::one() + One::one();
        self / two.pow(shift)
    }
}

trait WrappingBitshift<T> {
    // Shift a number left by a given number of bits.
    // If the shift is greater than 255, the result is 0.
    // The bits moved after the 256th one are discarded, the new bits are set to 0.
    fn wrapping_shl(self: T, shift: T) -> T;

    // Shift a number right by a given number of bits.
    // If the shift is greater than 255, the result is 0.
    fn wrapping_shr(self: T, shift: T) -> T;
}

impl Felt252WrappingBitshiftImpl of WrappingBitshift<felt252> {
    fn wrapping_shl(self: felt252, shift: felt252) -> felt252 {
        self * 2.wrapping_pow(shift)
    }

    fn wrapping_shr(self: felt252, shift: felt252) -> felt252 {
        // converting to u256
        let val: u256 = self.into();
        let shift: u256 = shift.into();

        // early return to save gas if shift > 255
        if shift > 255 {
            return 0;
        }

        let shifted_u256 = val / 2_u256.wrapping_pow(shift);

        // convert back to felt252
        shifted_u256.try_into().unwrap()
    }
}

impl U256WrappingBitshiftImpl of WrappingBitshift<u256> {
    fn wrapping_shl(self: u256, shift: u256) -> u256 {
        let (result, _) = u256_overflow_mul(self, 2.wrapping_pow(shift));
        result
    }

    fn wrapping_shr(self: u256, shift: u256) -> u256 {
        // if we shift by more than 255 bits, the result is 0 (the type is 256 bits wide)
        // we early return to save gas
        // and prevent unexpected behavior, e.g. 2.pow(256) == 0 mod 2^256, given we can't divide by zero
        if shift > 255 {
            return 0;
        }
        self / 2.pow(shift)
    }
}

impl U128WrappingBitshiftImpl of WrappingBitshift<u128> {
    fn wrapping_shl(self: u128, shift: u128) -> u128 {
        let (result, _) = u128_overflowing_mul(self, 2.wrapping_pow(shift));
        result
    }

    fn wrapping_shr(self: u128, shift: u128) -> u128 {
        // if we shift by more than 255 bits, the result is 0 (the type is 128 bits wide)
        // we early return to save gas
        // and prevent unexpected behavior, e.g. 2.pow(128) == 0 mod 2^128, given we can't divide by zero
        if shift > 127 {
            return 0;
        }
        self / 2.pow(shift)
    }
}

// === Standalone functions ===

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
