use utils::constants::POW_2_127;
use utils::u256_signed_math::u256_signed_div_rem;
use utils::math::{Bitshift, Exponentiation};
use integer::u256_try_as_non_zero;
use integer::BoundedInt;

#[derive(Copy, Drop)]
struct i256 {
    unsigned_value: u256,
}

impl U256IntoI256 of Into<u256, i256> {
    fn into(self: u256) -> i256 {
        i256 { unsigned_value: self }
    }
}

impl I256IntoU256 of Into<i256, u256> {
    fn into(self: i256) -> u256 {
        self.unsigned_value
    }
}

impl I256PartialEq of PartialEq<i256> {
    fn eq(lhs: @i256, rhs: @i256) -> bool {
        lhs.unsigned_value == rhs.unsigned_value
    }
    fn ne(lhs: @i256, rhs: @i256) -> bool {
        !(lhs == rhs)
    }
}

impl I256PartialOrd of PartialOrd<i256> {
    fn le(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.unsigned_value.high < POW_2_127;
        let rhs_positive = rhs.unsigned_value.high < POW_2_127;

        // First, check if signs are different
        if (lhs_positive != rhs_positive) {
            !lhs_positive
        } // rhswise, compare values
        else {
            lhs.unsigned_value <= rhs.unsigned_value
        }
    }
    fn ge(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.unsigned_value.high < POW_2_127;
        let rhs_positive = rhs.unsigned_value.high < POW_2_127;

        // First, check if signs are different
        if (lhs_positive != rhs_positive) {
            lhs_positive
        } // rhswise, compare values
        else {
            lhs.unsigned_value >= rhs.unsigned_value
        }
    }

    fn lt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.unsigned_value.high < POW_2_127;
        let rhs_positive = rhs.unsigned_value.high < POW_2_127;

        // First, check if signs are different
        if (lhs_positive != rhs_positive) {
            !lhs_positive
        } // rhswise, compare values
        else {
            lhs.unsigned_value < rhs.unsigned_value
        }
    }
    fn gt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.unsigned_value.high < POW_2_127;
        let rhs_positive = rhs.unsigned_value.high < POW_2_127;

        // First, check if signs are different
        if (lhs_positive != rhs_positive) {
            lhs_positive
        } // rhswise, compare values
        else {
            lhs.unsigned_value > rhs.unsigned_value
        }
    }
}

impl I256Div of Div<i256> {
    fn div(lhs: i256, rhs: i256) -> i256 {
        let result: u256 = match u256_try_as_non_zero(rhs.into()) {
            Option::Some(nonzero_rhs) => {
                let (q, _) = u256_signed_div_rem(lhs.into(), nonzero_rhs);
                q
            },
            Option::None => 0,
        };
        return result.into();
    }
}

impl I256Rem of Rem<i256> {
    fn rem(lhs: i256, rhs: i256) -> i256 {
        let result: u256 = match u256_try_as_non_zero(rhs.into()) {
            Option::Some(nonzero_rhs) => {
                let (_, r) = u256_signed_div_rem(lhs.into(), nonzero_rhs);
                r
            },
            Option::None => 0,
        };
        return result.into();
    }
}

impl I256BitshiftImpl of Bitshift<i256> {
    fn shl(self: i256, shift: i256) -> i256 {
        // Checks the MSB bit sign for a 256-bit integer
        let positive = self.unsigned_value.high < POW_2_127;
        let sign = if positive {
            // If sign is positive, set it to 0.
            0
        } else {
            // If sign is negative, set the number to -1.
            BoundedInt::<u256>::max()
        };

        if (shift.unsigned_value > 256) {
            return sign.into();
        } else {
            // XORing with sign before and after the shift propagates the sign bit of the operation
            let result = (sign ^ self.unsigned_value).shl(shift.unsigned_value) ^ sign;
            return result.into();
        }
    }

    fn shr(self: i256, shift: i256) -> i256 {
        // Checks the MSB bit sign for a 256-bit integer
        let positive = self.unsigned_value.high < POW_2_127;
        let sign = if positive {
            // If sign is positive, set it to 0.
            0
        } else {
            // If sign is negative, set the number to -1.
            BoundedInt::<u256>::max()
        };

        if (shift.unsigned_value > 256) {
            return sign.into();
        } else {
            // XORing with sign before and after the shift propagates the sign bit of the operation
            let result = (sign ^ self.unsigned_value).shr(shift.unsigned_value) ^ sign;
            return result.into();
        }
    }
}
