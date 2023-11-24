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
