use checked_math::CheckedMath;

//Temporary workaround to avoid auto-export of all the traits in this file.
//Once we have pub / priv visibility, we can just declare CheckedMath<T> as public,
// and make CheckedAdd and CheckedSub so that they are not exported.
mod checked_math {
    use super::checked_add::CheckedAdd;
    use super::checked_mul::CheckedMul;
    use super::checked_sub::CheckedSub;

    trait CheckedMath<T> {
        fn checked_add(self: T, rhs: T) -> Option<T>;
        fn checked_sub(self: T, rhs: T) -> Option<T>;
        fn checked_mul(self: T, rhs: T) -> Option<T>;
    }

    impl CheckedMathImpl<T, +CheckedAdd<T>, +CheckedSub<T>, +CheckedMul<T>> of CheckedMath<T> {
        fn checked_add(self: T, rhs: T) -> Option<T> {
            CheckedAdd::<T>::checked_add(self, rhs)
        }

        fn checked_sub(self: T, rhs: T) -> Option<T> {
            CheckedSub::<T>::checked_sub(self, rhs)
        }

        fn checked_mul(self: T, rhs: T) -> Option<T> {
            CheckedMul::<T>::checked_mul(self, rhs)
        }
    }
}

mod checked_add {
    use integer::{
        u8_checked_add, u16_checked_add, u32_checked_add, u64_checked_add, u128_checked_add,
        u256_checked_add
    };

    trait CheckedAdd<T> {
        fn checked_add(self: T, rhs: T) -> Option<T>;
    }

    impl U8CheckedAdd of CheckedAdd<u8> {
        fn checked_add(self: u8, rhs: u8) -> Option<u8> {
            u8_checked_add(self, rhs)
        }
    }

    impl U16CheckedAdd of CheckedAdd<u16> {
        fn checked_add(self: u16, rhs: u16) -> Option<u16> {
            u16_checked_add(self, rhs)
        }
    }

    impl U32CheckedAdd of CheckedAdd<u32> {
        fn checked_add(self: u32, rhs: u32) -> Option<u32> {
            u32_checked_add(self, rhs)
        }
    }

    impl U64CheckedAdd of CheckedAdd<u64> {
        fn checked_add(self: u64, rhs: u64) -> Option<u64> {
            u64_checked_add(self, rhs)
        }
    }

    impl U128CheckedAdd of CheckedAdd<u128> {
        fn checked_add(self: u128, rhs: u128) -> Option<u128> {
            u128_checked_add(self, rhs)
        }
    }

    impl U256CheckedAdd of CheckedAdd<u256> {
        fn checked_add(self: u256, rhs: u256) -> Option<u256> {
            u256_checked_add(self, rhs)
        }
    }
}

mod checked_sub {
    use integer::{
        u8_checked_sub, u16_checked_sub, u32_checked_sub, u64_checked_sub, u128_checked_sub,
        u256_checked_sub
    };
    trait CheckedSub<T> {
        fn checked_sub(self: T, rhs: T) -> Option<T>;
    }

    impl U8CheckedSub of CheckedSub<u8> {
        fn checked_sub(self: u8, rhs: u8) -> Option<u8> {
            u8_checked_sub(self, rhs)
        }
    }

    impl U16CheckedSub of CheckedSub<u16> {
        fn checked_sub(self: u16, rhs: u16) -> Option<u16> {
            u16_checked_sub(self, rhs)
        }
    }

    impl U32CheckedSub of CheckedSub<u32> {
        fn checked_sub(self: u32, rhs: u32) -> Option<u32> {
            u32_checked_sub(self, rhs)
        }
    }

    impl U64CheckedSub of CheckedSub<u64> {
        fn checked_sub(self: u64, rhs: u64) -> Option<u64> {
            u64_checked_sub(self, rhs)
        }
    }

    impl U128CheckedSub of CheckedSub<u128> {
        fn checked_sub(self: u128, rhs: u128) -> Option<u128> {
            u128_checked_sub(self, rhs)
        }
    }

    impl U256CheckedSub of CheckedSub<u256> {
        fn checked_sub(self: u256, rhs: u256) -> Option<u256> {
            u256_checked_sub(self, rhs)
        }
    }
}

mod checked_mul {
    use integer::{u32_wide_mul};
    use utils::math::{Bitshift, OverflowingMul};

    trait CheckedMul<T> {
        /// performs a checked multiplication, returning `None` if the multiplication overflows.
        /// # Arguments
        /// * `self` - The left hand side of the multiplication.
        /// * `rhs` - The right hand side of the multiplication.
        /// # Returns
        /// `Some(self * rhs)` if the multiplication doesn't overflow, and `None` otherwise.
        fn checked_mul(self: T, rhs: T) -> Option<T>;
    }

    impl CheckedMulImpl<T, +OverflowingMul<T>, +Drop<T>> of CheckedMul<T> {
        fn checked_mul(self: T, rhs: T) -> Option<T> {
            let (result, is_overflow) = self.overflowing_mul(rhs);

            match is_overflow {
                true => { Option::None },
                false => { Option::Some(result) }
            }
        }
    }
}


#[cfg(test)]
mod tests {
    use integer::BoundedInt;
    use super::{checked_math::CheckedMath};

    #[test]
    fn test_u8_checked_add() {
        assert_eq!(1_u8.checked_add(2), Option::Some(3));
        assert_eq!(BoundedInt::<u8>::max().checked_add(1), Option::<u8>::None);
    }

    #[test]
    fn test_u8_checked_sub() {
        assert_eq!(3_u8.checked_sub(2), Option::Some(1));
        assert_eq!(0_u8.checked_sub(1), Option::<u8>::None);
    }

    #[test]
    fn test_u16_checked_add() {
        assert_eq!(1_u16.checked_add(2), Option::Some(3));
        assert_eq!(BoundedInt::<u16>::max().checked_add(1), Option::<u16>::None);
    }

    #[test]
    fn test_u16_checked_sub() {
        assert_eq!(3_u16.checked_sub(2), Option::Some(1));
        assert_eq!(0_u16.checked_sub(1), Option::<u16>::None);
    }

    #[test]
    fn test_u32_checked_add() {
        assert_eq!(1_u32.checked_add(2), Option::Some(3));
        assert_eq!(BoundedInt::<u32>::max().checked_add(1), Option::<u32>::None);
    }

    #[test]
    fn test_u32_checked_sub() {
        assert_eq!(3_u32.checked_sub(2), Option::Some(1));
        assert_eq!(0_u32.checked_sub(1), Option::<u32>::None);
    }

    #[test]
    fn test_u64_checked_add() {
        assert_eq!(1_u64.checked_add(2), Option::Some(3));
        assert_eq!(BoundedInt::<u64>::max().checked_add(1), Option::<u64>::None);
    }

    #[test]
    fn test_u64_checked_sub() {
        assert_eq!(3_u64.checked_sub(2), Option::Some(1));
        assert_eq!(0_u64.checked_sub(1), Option::<u64>::None);
    }

    #[test]
    fn test_u128_checked_add() {
        assert_eq!(1_u128.checked_add(2), Option::Some(3));
        assert_eq!(BoundedInt::<u128>::max().checked_add(1), Option::<u128>::None);
    }

    #[test]
    fn test_u128_checked_sub() {
        assert_eq!(3_u128.checked_sub(2), Option::Some(1));
        assert_eq!(0_u128.checked_sub(1), Option::<u128>::None);
    }

    #[test]
    fn test_u256_checked_add() {
        assert_eq!(1_u256.checked_add(2), Option::Some(3));
        assert_eq!(BoundedInt::<u256>::max().checked_add(1), Option::<u256>::None);
    }

    #[test]
    fn test_u256_checked_sub() {
        assert_eq!(3_u256.checked_sub(2), Option::Some(1));
        assert_eq!(0_u256.checked_sub(1), Option::<u256>::None);
    }

    #[test]
    fn test_checked_mul() {
        assert_eq!(1_u8.checked_mul(2), Option::Some(2));
        assert_eq!(BoundedInt::<u8>::max().checked_mul(2), Option::<u8>::None);
    }
}
