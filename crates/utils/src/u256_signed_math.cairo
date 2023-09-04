use integer::u256_safe_div_rem;
use traits::{Into, TryInto};
use option::OptionTrait;

const ALL_ONES: u128 = 0xffffffffffffffffffffffffffffffff;
const TWO_POW_127: u128 = 0x80000000000000000000000000000000;
const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;


// Returns the negation of an integer.
// Note that the negation of -2**255 is -2**255.
fn u256_neg(a: u256) -> u256 {
    // If a is 0, adding one to its bitwise NOT will overflow and return 0.
    if a == 0 {
        return 0;
    }
    ~a + 1
}

/// Signed integer division between two integers. Returns the quotient and the remainder.
/// Conforms to EVM specifications - except that the type system enforces div != zero.
/// See ethereum yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf, page 29).
/// Note that the remainder may be negative if one of the inputs is negative and that
/// (-2**255) / (-1) = -2**255 because 2*255 is out of range.
fn u256_signed_div_rem(a: u256, div: NonZero<u256>) -> (u256, u256) {
    let mut div: u256 = div.into();

    // When div=-1, simply return -a.
    if div == MAX_U256 {
        return (u256_neg(a), 0);
    }

    // Take the absolute value of a and div.
    // Checks the MSB bit sign for a 256-bit integer
    let a_positive = a.high < TWO_POW_127;
    let a = if a_positive {
        a
    } else {
        u256_neg(a)
    };

    let div_positive = div.high < TWO_POW_127;
    div = if div_positive {
        div
    } else {
        u256_neg(div)
    };

    // Compute the quotient and remainder.
    // Can't panic as zero case is handled in the first instruction
    let (quot, rem) = u256_safe_div_rem(a, div.try_into().unwrap());

    // Restore remainder sign.
    let rem = if a_positive {
        rem
    } else {
        u256_neg(rem)
    };

    // If the signs of a and div are the same, return the quotient and remainder.
    if a_positive == div_positive {
        return (quot, rem);
    }

    // Otherwise, return the negation of the quotient and the remainder.
    (u256_neg(quot), rem)
}

// Signed integer comparaison
trait SignedPartialOrd<T> {
    fn slt(self: T, other: T) -> bool;
}

// Signed u256 comparaison
impl U256SignedPartialOrd of SignedPartialOrd<u256> {
    fn slt(self: u256, other: u256) -> bool {
        let self_positive = self.high < TWO_POW_127;
        let other_positive = other.high < TWO_POW_127;

        // First, check if signs are different
        if (self_positive != other_positive) {
            !self_positive
        } // otherwise, compare values
        else {
            self < other
        }
    }
}
