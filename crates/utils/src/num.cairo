// === SizeOf ===

trait SizeOf<T> {
    /// Returns the size in bits of Self.
    fn size() -> T;
    fn size_of(self: @T) -> T;
}

impl U8SizeOf of SizeOf<u8> {
    fn size() -> u8 {
        8
    }
    fn size_of(self: @u8) -> u8 {
        U8SizeOf::size()
    }
}

impl U16SizeOf of SizeOf<u16> {
    fn size() -> u16 {
        16
    }
    fn size_of(self: @u16) -> u16 {
        U16SizeOf::size()
    }
}

impl U32SizeOf of SizeOf<u32> {
    fn size() -> u32 {
        32
    }
    fn size_of(self: @u32) -> u32 {
        U32SizeOf::size()
    }
}

impl U64SizeOf of SizeOf<u64> {
    fn size() -> u64 {
        64
    }
    fn size_of(self: @u64) -> u64 {
        U64SizeOf::size()
    }
}

impl U128SizeOf of SizeOf<u128> {
    #[inline(always)]
    fn size() -> u128 {
        128
    }
    #[inline(always)]
    fn size_of(self: @u128) -> u128 {
        U128SizeOf::size()
    }
}

impl Felt252SizeOf of SizeOf<felt252> {
    #[inline(always)]
    fn size() -> felt252 {
        252
    }
    #[inline(always)]
    fn size_of(self: @felt252) -> felt252 {
        Felt252SizeOf::size()
    }
}

impl U256SizeOf of SizeOf<u256> {
    #[inline(always)]
    fn size() -> u256 {
        256
    }
    #[inline(always)]
    fn size_of(self: @u256) -> u256 {
        U256SizeOf::size()
    }
}


/// TODO: remove the Zero trait when it's integrated in Cairo
// === Zero ===

trait Zero<T> {
    /// Returns the additive identity element of Self, 0.
    fn zero() -> T;
    /// Returns whether self is equal to 0, the additive identity element.
    fn is_zero(self: @T) -> bool;
    /// Returns whether self is not equal to 0, the additive identity element.
    fn is_non_zero(self: @T) -> bool;
}

impl Felt252Zero of Zero<felt252> {
    #[inline(always)]
    fn zero() -> felt252 {
        0
    }

    #[inline(always)]
    fn is_zero(self: @felt252) -> bool {
        *self == Zero::zero()
    }

    #[inline(always)]
    fn is_non_zero(self: @felt252) -> bool {
        !self.is_zero()
    }
}

impl U32Zero of Zero<u32> {
    #[inline(always)]
    fn zero() -> u32 {
        0
    }

    #[inline(always)]
    fn is_zero(self: @u32) -> bool {
        *self == Zero::zero()
    }

    #[inline(always)]
    fn is_non_zero(self: @u32) -> bool {
        !self.is_zero()
    }
}

impl U64Zero of Zero<u64> {
    #[inline(always)]
    fn zero() -> u64 {
        0
    }

    #[inline(always)]
    fn is_zero(self: @u64) -> bool {
        *self == Zero::zero()
    }

    #[inline(always)]
    fn is_non_zero(self: @u64) -> bool {
        !self.is_zero()
    }
}

impl U128Zero of Zero<u128> {
    #[inline(always)]
    fn zero() -> u128 {
        0
    }

    #[inline(always)]
    fn is_zero(self: @u128) -> bool {
        *self == Zero::zero()
    }

    #[inline(always)]
    fn is_non_zero(self: @u128) -> bool {
        !self.is_zero()
    }
}


impl U256Zero of Zero<u256> {
    #[inline(always)]
    fn zero() -> u256 {
        0
    }

    #[inline(always)]
    fn is_zero(self: @u256) -> bool {
        *self == Zero::zero()
    }

    #[inline(always)]
    fn is_non_zero(self: @u256) -> bool {
        !self.is_zero()
    }
}


/// TODO: remove the One trait when it's integrated in Cairo
// === One ===

trait One<T> {
    /// Returns the multiplicative identity element of Self, 1.
    fn one() -> T;
    /// Returns whether self is equal to 1, the multiplicative identity element.
    fn is_one(self: @T) -> bool;
    /// Returns whether self is not equal to 1, the multiplicative identity element.
    fn is_non_one(self: @T) -> bool;
}

impl Felt252One of One<felt252> {
    #[inline(always)]
    fn one() -> felt252 {
        1
    }

    #[inline(always)]
    fn is_one(self: @felt252) -> bool {
        *self == One::one()
    }

    #[inline(always)]
    fn is_non_one(self: @felt252) -> bool {
        !self.is_one()
    }
}

impl U32One of One<u32> {
    #[inline(always)]
    fn one() -> u32 {
        1
    }

    #[inline(always)]
    fn is_one(self: @u32) -> bool {
        *self == One::one()
    }

    #[inline(always)]
    fn is_non_one(self: @u32) -> bool {
        !self.is_one()
    }
}

impl U64One of One<u64> {
    #[inline(always)]
    fn one() -> u64 {
        1
    }

    #[inline(always)]
    fn is_one(self: @u64) -> bool {
        *self == One::one()
    }

    #[inline(always)]
    fn is_non_one(self: @u64) -> bool {
        !self.is_one()
    }
}


impl U128One of One<u128> {
    #[inline(always)]
    fn one() -> u128 {
        1
    }

    #[inline(always)]
    fn is_one(self: @u128) -> bool {
        *self == One::one()
    }

    #[inline(always)]
    fn is_non_one(self: @u128) -> bool {
        !self.is_one()
    }
}

impl U256One of One<u256> {
    #[inline(always)]
    fn one() -> u256 {
        1
    }

    #[inline(always)]
    fn is_one(self: @u256) -> bool {
        *self == One::one()
    }

    #[inline(always)]
    fn is_non_one(self: @u256) -> bool {
        !self.is_one()
    }
}
