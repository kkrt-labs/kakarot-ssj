use math::{Zeroable, Oneable};

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
    fn size() -> u128 {
        128
    }
    fn size_of(self: @u128) -> u128 {
        U128SizeOf::size()
    }
}

impl Felt252SizeOf of SizeOf<felt252> {
    fn size() -> felt252 {
        252
    }
    fn size_of(self: @felt252) -> felt252 {
        Felt252SizeOf::size()
    }
}

impl U256SizeOf of SizeOf<u256> {
    fn size() -> u256 {
        256
    }
    fn size_of(self: @u256) -> u256 {
        U256SizeOf::size()
    }
}


/// TODO: remove the Zero trait when it's integrated in Cairo
// === Zero ===

trait Zero<T> {
    /// Returns the multiplicative identity element of Self, 0.
    fn zero() -> T;
    /// Returns whether self is equal to 0, the multiplicative identity element.
    fn is_zero(self: @T) -> bool;
    /// Returns whether self is not equal to 0, the multiplicative identity element.
    fn is_non_zero(self: @T) -> bool;
}

impl ZeroImpl<T, +Zeroable<T>, +PartialEq<T>, +Drop<T>, +Copy<T>> of Zero<T> {
    fn zero() -> T {
        Zeroable::zero()
    }
    fn is_zero(self: @T) -> bool {
        *self == ZeroImpl::zero()
    }

    fn is_non_zero(self: @T) -> bool {
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

impl OneImpl<T, +Oneable<T>, +PartialEq<T>, +Drop<T>, +Copy<T>> of One<T> {
    fn one() -> T {
        Oneable::one()
    }

    fn is_one(self: @T) -> bool {
        *self == OneImpl::one()
    }

    fn is_non_one(self: @T) -> bool {
        !self.is_one()
    }
}
