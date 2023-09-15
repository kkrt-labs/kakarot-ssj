use utils::constants::POW_2_127;
use utils::u256_signed_math::u256_neg;
use utils::math::{Bitshift, Exponentiation};
use integer::{u256_try_as_non_zero, u256_safe_div_rem, BoundedInt};

#[derive(Copy, Drop, PartialEq)]
struct i256 {
    value: u256,
}

impl U256IntoI256 of Into<u256, i256> {
    #[inline(always)]
    fn into(self: u256) -> i256 {
        i256 { value: self }
    }
}

impl I256IntoU256 of Into<i256, u256> {
    #[inline(always)]
    fn into(self: i256) -> u256 {
        self.value
    }
}

impl I256PartialOrd of PartialOrd<i256> {
    #[inline(always)]
    fn le(lhs: i256, rhs: i256) -> bool {
        !(rhs < lhs)
    }

    #[inline(always)]
    fn ge(lhs: i256, rhs: i256) -> bool {
        !(lhs < rhs)
    }

    #[inline(always)]
    fn lt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.value.high < POW_2_127;
        let rhs_positive = rhs.value.high < POW_2_127;

        if (lhs_positive != rhs_positive) {
            !lhs_positive
        } else {
            lhs.value < rhs.value
        }
    }

    #[inline(always)]
    fn gt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.value.high < POW_2_127;
        let rhs_positive = rhs.value.high < POW_2_127;

        if (lhs_positive != rhs_positive) {
            lhs_positive
        } else {
            lhs.value > rhs.value
        }
    }
}

impl I256Div of Div<i256> {
    fn div(lhs: i256, rhs: i256) -> i256 {
        let (q, _) = i256_signed_div_rem(lhs, rhs.value.try_into().expect('Division by 0'));
        return q.into();
    }
}

impl I256Rem of Rem<i256> {
    fn rem(lhs: i256, rhs: i256) -> i256 {
        let (_, r) = i256_signed_div_rem(lhs, rhs.value.try_into().expect('Division by 0'));
        return r.into();
    }
}

impl I256BitshiftImpl of Bitshift<i256> {
    fn shl(self: i256, shift: i256) -> i256 {
        // Checks the MSB bit sign for a 256-bit integer
        let positive = self.value.high < POW_2_127;
        let sign = if positive {
            // If sign is positive, set it to 0.
            0
        } else {
            // If sign is negative, set the MSB bit to 1 and others to 0.
            0x8000000000000000000000000000000000000000000000000000000000000000
        };

        // XORing with sign before and ORing the shift propagates the sign bit of the operation
        let result = (sign ^ self.value).shl(shift.value) | sign;
        return result.into();
    }

    fn shr(self: i256, shift: i256) -> i256 {
        // Checks the MSB bit sign for a 256-bit integer
        let positive = self.value.high < POW_2_127;
        let sign = if positive {
            // If sign is positive, set it to 0.
            0
        } else {
            // If sign is negative, set the number to -1.
            BoundedInt::<u256>::max()
        };

        if (shift.value > 255) {
            return sign.into();
        } else {
            // XORing with sign before and after the shift propagates the sign bit of the operation
            let result = (sign ^ self.value).shr(shift.value) ^ sign;
            return result.into();
        }
    }
}

/// Signed integer division between two integers. Returns the quotient and the remainder.
/// Conforms to EVM specifications - except that the type system enforces div != zero.
/// See ethereum yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf, page 29).
/// Note that the remainder may be negative if one of the inputs is negative and that
/// (-2**255) / (-1) = -2**255 because 2*255 is out of range.
fn i256_signed_div_rem(a: i256, div: NonZero<u256>) -> (i256, i256) {
    let mut div = i256 { value: div.into() };

    // When div=-1, simply return -a.
    if div.value == BoundedInt::<u256>::max() {
        return (u256_neg(a.value).into(), 0_u256.into());
    }

    // Take the absolute value of a and div.
    // Checks the MSB bit sign for a 256-bit integer
    let a_positive = a.value.high < POW_2_127;
    let a = if a_positive {
        a
    } else {
        u256_neg(a.value).into()
    };

    let div_positive = div.value.high < POW_2_127;
    div = if div_positive {
        div
    } else {
        u256_neg(div.value).into()
    };

    // Compute the quotient and remainder.
    // Can't panic as zero case is handled in the first instruction
    let (quot, rem) = u256_safe_div_rem(a.value, div.value.try_into().unwrap());

    // Restore remainder sign.
    let rem = if a_positive {
        rem
    } else {
        u256_neg(rem)
    };

    // If the signs of a and div are the same, return the quotient and remainder.
    if a_positive == div_positive {
        return (quot.into(), rem.into());
    }

    // Otherwise, return the negation of the quotient and the remainder.
    (u256_neg(quot).into(), rem.into())
}
