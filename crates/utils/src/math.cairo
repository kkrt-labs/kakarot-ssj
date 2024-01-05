use core::num::traits::{Zero, One};
use integer::{
    u256, u256_overflow_mul, u256_overflowing_add, u512, BoundedInt, u128_overflowing_mul,
    u64_wide_mul, u64_to_felt252
};
use utils::num::{SizeOf};


// === Exponentiation ===

trait Exponentiation<T> {
    /// Raise a number to a power.
    /// # Panics
    /// Panics if the result overflows the type T.
    fn pow(self: T, exponent: T) -> T;
}

impl ExponentiationImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +Div<T>,
    +BitAnd<T>,
    +PartialEq<T>,
    +Copy<T>,
    +Drop<T>
> of Exponentiation<T> {
    fn pow(self: T, mut exponent: T) -> T {
        let zero = Zero::zero();
        if self.is_zero() {
            return zero;
        }
        let one = One::one();
        let mut result = one;
        let mut base = self;
        let two = one + one;

        loop {
            if exponent & one == one {
                result = result * base;
            }

            exponent = exponent / two;
            if exponent == zero {
                break result;
            }

            base = base * base;
        }
    }
}

trait WrappingExponentiation<T> {
    /// Raise a number to a power modulo MAX<T> (max value of type T).
    /// Instead of explicitly providing a modulo, we use overflowing functions
    /// from the core library, which wrap around when overflowing.
    /// * `T` - The result of base raised to the power of exp modulo MAX<T>.
    fn wrapping_pow(self: T, exponent: T) -> T;
}

mod internal_wrapping_pow_u64 {
    use super::u64_overflow_mul;

    fn wrapping_spow(base: u64, exponent: u64) -> u64 {
        let mut exponent = exponent;
        let mut base = base;
        let mut result = 1;

        loop {
            if exponent == 0 {
                break result;
            }
            let (new_result, _) = u64_overflow_mul(result, base);
            result = new_result;
            exponent -= 1;
        }
    }
    fn wrapping_fpow(base: u64, exponent: u64) -> u64 {
        let mut result = 1;
        let mut base = base;
        let mut exponent = exponent;

        loop {
            if exponent % 2 != 0 {
                let (new_result, _) = u64_overflow_mul(result, base);
                result = new_result;
            }

            exponent = exponent / 2;
            if exponent == 0 {
                break result;
            }

            let (new_base, _) = u64_overflow_mul(base, base);
            base = new_base;
        }
    }
}


impl U64WrappingExponentiationImpl of WrappingExponentiation<u64> {
    fn wrapping_pow(self: u64, mut exponent: u64) -> u64 {
        if self == 0 {
            return 1;
        }
        if exponent > 10 {
            internal_wrapping_pow_u64::wrapping_fpow(self, exponent)
        } else {
            internal_wrapping_pow_u64::wrapping_spow(self, exponent)
        }
    }
}


impl U128WrappingExponentiationImpl of WrappingExponentiation<u128> {
    fn wrapping_pow(self: u128, mut exponent: u128) -> u128 {
        if self == 0 {
            return 1;
        }
        if exponent > 10 {
            internal_wrapping_pow_u128::wrapping_fpow(self, exponent)
        } else {
            internal_wrapping_pow_u128::wrapping_spow(self, exponent)
        }
    }
}

mod internal_wrapping_pow_u128 {
    use integer::{u128_overflowing_mul};
    fn wrapping_spow(base: u128, exponent: u128) -> u128 {
        let mut exponent = exponent;
        let mut base = base;
        let mut result = 1;

        loop {
            if exponent == 0 {
                break result;
            }
            let (new_result, _) = u128_overflowing_mul(result, base);
            result = new_result;
            exponent -= 1;
        }
    }
    fn wrapping_fpow(base: u128, exponent: u128) -> u128 {
        let mut result = 1;
        let mut base = base;
        let mut exponent = exponent;

        loop {
            if exponent % 2 != 0 {
                let (new_result, _) = u128_overflowing_mul(result, base);
                result = new_result;
            }

            exponent = exponent / 2;
            if exponent == 0 {
                break result;
            }

            let (new_base, _) = u128_overflowing_mul(base, base);
            base = new_base;
        }
    }
}

impl U256WrappingExponentiationImpl of WrappingExponentiation<u256> {
    fn wrapping_pow(self: u256, mut exponent: u256) -> u256 {
        if self == 0 {
            return 0;
        }
        if exponent > 10 {
            internal_wrapping_pow_u256::wrapping_fpow(self, exponent)
        } else {
            internal_wrapping_pow_u256::wrapping_spow(self, exponent)
        }
    }
}

mod internal_wrapping_pow_u256 {
    use integer::{u256_overflow_mul, u256};
    fn wrapping_spow(base: u256, exponent: u256) -> u256 {
        let mut exponent = exponent;
        let mut base = base;
        let mut result = 1;

        loop {
            if exponent == 0 {
                break result;
            }
            let (new_result, _) = u256_overflow_mul(result, base);
            result = new_result;
            exponent -= 1;
        }
    }
    fn wrapping_fpow(base: u256, exponent: u256) -> u256 {
        let mut result = 1;
        let mut base = base;
        let mut exponent = exponent;

        loop {
            if exponent % 2 != 0 {
                let (new_result, _) = u256_overflow_mul(result, base);
                result = new_result;
            }

            exponent = exponent / 2;
            if exponent == 0 {
                break result;
            }

            let (new_base, _) = u256_overflow_mul(base, base);
            base = new_base;
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
    +Exponentiation<T>,
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

impl u64WrappingBitshiftImpl of WrappingBitshift<u64> {
    fn wrapping_shl(self: u64, shift: u64) -> u64 {
        let (result, _) = u64_overflow_mul(self, 2.wrapping_pow(shift));
        result
    }

    fn wrapping_shr(self: u64, shift: u64) -> u64 {
        // if we shift by more than 255 bits, the result is 0 (the type is 128 bits wide)
        // we early return to save gas
        // and prevent unexpected behavior, e.g. 2.pow(128) == 0 mod 2^128, given we can't divide by zero
        if shift > 63 {
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

fn u64_overflow_mul(lhs: u64, rhs: u64) -> (u64, bool) {
    let result = u64_wide_mul(lhs, rhs);
    let (top_word, bottom_word) = split_u128_into_u64(result);

    match u64_to_felt252(top_word) {
        0 => (bottom_word, false),
        _ => (bottom_word, true),
    }
}

fn split_u128_into_u64(v: u128) -> (u64, u64) {
    let bottom_word: u64 = (v & 0xFFFFFFFFFFFFFFFF).try_into().unwrap();
    let top_word = (v.shr(64) & 0xFFFFFFFFFFFFFFFF).try_into().unwrap();

    (top_word, bottom_word)
}
