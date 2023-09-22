use utils::constants::POW_2_127_U128;
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
        let lhs_positive = lhs.value.high < POW_2_127_U128;
        let rhs_positive = rhs.value.high < POW_2_127_U128;

        if (lhs_positive != rhs_positive) {
            !lhs_positive
        } else {
            lhs.value < rhs.value
        }
    }

    #[inline(always)]
    fn gt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.value.high < POW_2_127_U128;
        let rhs_positive = rhs.value.high < POW_2_127_U128;

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

/// Signed integer division between two integers. Returns the quotient and the remainder.
/// Conforms to EVM specifications - except that the type system enforces div != zero.
/// See ethereum yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf, page 29).
/// Note that the remainder may be negative if one of the inputs is negative and that
/// (-2**255) / (-1) = -2**255 because 2*255 is out of range.
/// # Arguments
/// * `a` - The dividend.
/// * `div` - The divisor, passed as a signed NonZero<u256>.
/// # Returns
/// * (quotient, reminder) of the signed division of `a` by `div`
fn i256_signed_div_rem(a: i256, div: NonZero<u256>) -> (i256, i256) {
    let mut div = i256 { value: div.into() };

    // When div=-1, simply return -a.
    if div.value == BoundedInt::<u256>::max() {
        return (i256_neg(a).into(), 0_u256.into());
    }

    // Take the absolute value of a and div.
    // Checks the MSB bit sign for a 256-bit integer
    let a_positive = a.value.high < POW_2_127_U128;
    let a = if a_positive {
        a
    } else {
        i256_neg(a).into()
    };

    let div_positive = div.value.high < POW_2_127_U128;
    div = if div_positive {
        div
    } else {
        i256_neg(div).into()
    };

    // Compute the quotient and remainder.
    // Can't panic as zero case is handled in the first instruction
    let (quot, rem) = u256_safe_div_rem(a.value, div.value.try_into().unwrap());

    // Restore remainder sign.
    let rem = if a_positive {
        rem.into()
    } else {
        i256_neg(rem.into())
    };

    // If the signs of a and div are the same, return the quotient and remainder.
    if a_positive == div_positive {
        return (quot.into(), rem.into());
    }

    // Otherwise, return the negation of the quotient and the remainder.
    (i256_neg(quot.into()), rem.into())
}

// Returns the negation of an integer.
// Note that the negation of -2**255 is -2**255.
fn i256_neg(a: i256) -> i256 {
    // If a is 0, adding one to its bitwise NOT will overflow and return 0.
    if a.value == 0 {
        return 0_u256.into();
    }
    (~a.value + 1).into()
}
