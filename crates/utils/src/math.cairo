use core::keccak::u128_split;
use core::num::traits::{Zero, One, BitSize};
use core::option::OptionTrait;
use core::starknet::secp256_trait::Secp256PointTrait;
use integer::{
    u256, u256_overflow_mul as u256_overflowing_mul, u256_overflowing_add, u512, BoundedInt,
    u128_overflowing_mul, u64_wide_mul, u64_to_felt252, u32_wide_mul, u32_to_felt252, u8_wide_mul,
    u8_to_felt252
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

    /// Performs exponentiation by repeatedly multiplying the base number with itself.
    ///
    /// This function uses a simple loop to perform exponentiation. It continues to multiply
    /// the base number (`self`) with itself, for the number of times specified by `exponent`.
    /// The method uses a wrapping strategy to handle overflow, which means if the result
    /// overflows the type `T`, then higher bits are discarded and the result is wrapped.
    ///
    /// # Examples
    /// ```
    /// let result = 2_u8.wrapping_spow(3);
    /// assert_eq!(result, 8);
    /// ```
    ///
    /// # Parameters
    /// - `self`: The base number of type `T`.
    /// - `exponent`: The exponent to which the base number is raised, also of type `T`.
    ///
    /// # Returns
    /// - Returns the result of raising `self` to the power of `exponent`, of type `T`.
    ///   The result is wrapped in case of overflow.
    fn wrapping_spow(self: T, exponent: T) -> T;

    /// Performs exponentiation using the binary exponentiation method.
    ///
    /// This function calculates the power of a number using binary exponentiation, which is
    /// an optimized method for exponentiation that reduces the number of multiplications.
    /// It works by repeatedly squaring the base and reducing the exponent by half, using
    /// a wrapping strategy to handle overflow. This means if intermediate or final results
    /// overflow the type `T`, then the higher bits are discarded and the result is wrapped.
    ///
    /// # Examples
    /// ```
    /// let result = 2_u8.wrapping_fpow(3);
    /// assert_eq!(result, 8);
    /// ```
    ///
    /// # Parameters
    /// - `self`: The base number of type `T`.
    /// - `exponent`: The exponent to which the base number is raised, also of type `T`.
    ///
    /// # Returns
    /// - Returns the result of raising `self` to the power of `exponent`, of type `T`.
    ///   The result is wrapped in case of overflow.
    fn wrapping_fpow(self: T, exponent: T) -> T;
}


impl WrappingExponentiationImpl<
    T,
    +OverflowingMul<T>,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Mul<T>,
    +Div<T>,
    +Rem<T>,
    +Copy<T>,
    +Drop<T>,
    +PartialEq<T>,
    +PartialOrd<T>,
    +SubEq<T>
> of WrappingExponentiation<T> {
    fn wrapping_pow(self: T, exponent: T) -> T {
        if self == Zero::zero() {
            return Zero::zero();
        }

        let one = One::<T>::one();
        let ten = one + one + one + one + one + one + one + one + one + one;

        if exponent > ten {
            self.wrapping_fpow(exponent)
        } else {
            self.wrapping_spow(exponent)
        }
    }

    fn wrapping_spow(self: T, exponent: T) -> T {
        let mut exponent = exponent;
        let mut base = self;
        let mut result = One::one();

        loop {
            if exponent == Zero::zero() {
                break result;
            }
            let (new_result, _) = result.overflowing_mul(base);
            result = new_result;
            exponent -= One::one();
        }
    }

    fn wrapping_fpow(self: T, exponent: T) -> T {
        let mut result = One::one();
        let mut base = self;
        let mut exponent = exponent;
        let two = One::<T>::one() + One::<T>::one();

        loop {
            if exponent % two != Zero::zero() {
                let (new_result, _) = result.overflowing_mul(base);
                result = new_result;
            }

            exponent = exponent / two;
            if exponent == Zero::zero() {
                break result;
            }

            let (new_base, _) = base.overflowing_mul(base);
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

impl WrappingBitshiftImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Exponentiation<T>,
    +PartialOrd<T>,
    +Drop<T>,
    +Copy<T>,
    +OverflowingMul<T>,
    +WrappingExponentiation<T>,
    +SizeOf<T>
> of WrappingBitshift<T> {
    fn wrapping_shl(self: T, shift: T) -> T {
        let two = One::<T>::one() + One::<T>::one();
        let (result, _) = self.overflowing_mul(two.wrapping_pow(shift));
        result
    }

    fn wrapping_shr(self: T, shift: T) -> T {
        let two = One::<T>::one() + One::<T>::one();

        if shift > shift.size_of() - One::one() {
            return Zero::zero();
        }
        self / two.pow(shift)
    }
}

trait OverflowingMul<T> {
    /// Performs multiplication on two numbers of type `T`.
    ///
    /// This function multiplies two numbers and checks for overflow. If an overflow occurs,
    /// the overflow is discarded, and a boolean value is returned to indicate that the
    /// overflow happened. The function returns a tuple where the first element is the
    /// result of the multiplication (with overflow being wrapped) and the second element
    /// is a boolean flag that is `true` if an overflow occurred and `false` otherwise.
    ///
    /// # Examples
    /// ```
    /// let (result, overflowed) = 1_000_000_000_u256.overflowing_mul(2);
    /// assert_eq!(result, 2_000_000_000);
    /// assert!(!overflowed);
    ///
    /// let (result, overflowed) = BoundedInt::<u32>::max().overflowing_mul(BoundedInt::max());
    /// assert_eq!(result, u32::MAX.wrapping_mul(1));
    /// assert!(overflowed);
    /// ```
    ///
    /// # Parameters
    /// - `self`: The first operand of type `T` in the multiplication.
    /// - `rhs`: The second operand of type `T` in the multiplication.
    ///
    /// # Returns
    /// - A tuple `(T, bool)`. The first element of the tuple is the result of the
    ///   multiplication, and the second element is a boolean flag that is `true` if
    ///   an overflow occurred during the multiplication.
    ///
    fn overflowing_mul(self: T, rhs: T) -> (T, bool);
}

impl U8OverflowingMul of OverflowingMul<u8> {
    fn overflowing_mul(self: u8, rhs: u8) -> (u8, bool) {
        let result = u8_wide_mul(self, rhs);
        let mask: u16 = BoundedInt::<u8>::max().into();

        let top_word: u8 = (result.shr(BitSize::<u8>::bits().try_into().unwrap()) & mask)
            .try_into()
            .unwrap();
        let bottom_word = (result & mask).try_into().unwrap();

        match u8_to_felt252(top_word) {
            0 => (bottom_word, false),
            _ => (bottom_word, true),
        }
    }
}

impl U32OverflowingMul of OverflowingMul<u32> {
    fn overflowing_mul(self: u32, rhs: u32) -> (u32, bool) {
        let result = u32_wide_mul(self, rhs);

        let mask: u64 = BoundedInt::<u32>::max().into();

        let top_word: u32 = (result.shr(BitSize::<u32>::bits().into()) & mask).try_into().unwrap();
        let bottom_word = (result & mask).try_into().unwrap();

        match u32_to_felt252(top_word) {
            0 => (bottom_word, false),
            _ => (bottom_word, true),
        }
    }
}

impl U64OverflowingMul of OverflowingMul<u64> {
    fn overflowing_mul(self: u64, rhs: u64) -> (u64, bool) {
        let result = u64_wide_mul(self, rhs);
        let (top_word, bottom_word) = u128_split(result);

        match u64_to_felt252(top_word) {
            0 => (bottom_word, false),
            _ => (bottom_word, true),
        }
    }
}

impl U128OverflowingMul of OverflowingMul<u128> {
    fn overflowing_mul(self: u128, rhs: u128) -> (u128, bool) {
        u128_overflowing_mul(self, rhs)
    }
}

impl U256OverflowingMul of OverflowingMul<u256> {
    fn overflowing_mul(self: u256, rhs: u256) -> (u256, bool) {
        u256_overflowing_mul(self, rhs)
    }
}


trait WrappingMul<T> {
    /// Performs multiplication on two numbers of type `T`, discarding any overflow.
    ///
    /// This function multiplies two numbers and applies a wrapping strategy for handling
    /// overflow. If the result of the multiplication overflows the type `T`, it wraps
    /// around by discarding the higer bits.
    ///
    /// # Examples
    /// ```
    /// let result = 1_000_000_000_u256.overflowing_mul(2);
    /// assert_eq!(result, 2_000_000_000);
    ///
    /// let result = BoundedInt::<u32>::max().overflowing_mul(BoundedInt::max());
    /// assert_eq!(result, u32::MAX.wrapping_mul(1));
    /// ```
    ///
    /// # Parameters
    /// - `self`: The first operand of type `T` in the multiplication.
    /// - `rhs`: The second operand of type `T` in the multiplication.
    ///
    /// # Returns
    /// - Returns the result of multiplying `self` by `rhs`, of type `T`. If overflow occurs, the higher bits are discarded.
    fn wrapping_mul(self: T, rhs: T) -> T;
}

impl WrappingMulImpl<T, +OverflowingMul<T>> of WrappingMul<T> {
    fn wrapping_mul(self: T, rhs: T) -> T {
        let (res, _) = self.overflowing_mul(rhs);
        res
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
