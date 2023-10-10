// === SizeOf ===
trait SizeOf<T> {
    /// Returns the size_of in bits of Self.
    fn size_of() -> T;
    fn size_of_val(self: @T) -> T;
}

impl U8SizeOf of SizeOf<u8> {
    fn size_of() -> u8 {
        8
    }
    fn size_of_val(self: @u8) -> u8 {
        U8SizeOf::size_of()
    }
}

impl U16SizeOf of SizeOf<u16> {
    fn size_of() -> u16 {
        16
    }
    fn size_of_val(self: @u16) -> u16 {
        U16SizeOf::size_of()
    }
}

impl U32SizeOf of SizeOf<u32> {
    fn size_of() -> u32 {
        32
    }
    fn size_of_val(self: @u32) -> u32 {
        U32SizeOf::size_of()
    }
}

impl U64SizeOf of SizeOf<u64> {
    fn size_of() -> u64 {
        64
    }
    fn size_of_val(self: @u64) -> u64 {
        U64SizeOf::size_of()
    }
}

impl U128SizeOf of SizeOf<u128> {
    fn size_of() -> u128 {
        128
    }
    fn size_of_val(self: @u128) -> u128 {
        U128SizeOf::size_of()
    }
}

impl Felt252SizeOf of SizeOf<felt252> {
    fn size_of() -> felt252 {
        252
    }
    fn size_of_val(self: @felt252) -> felt252 {
        Felt252SizeOf::size_of()
    }
}

impl U256SizeOf of SizeOf<u256> {
    fn size_of() -> u256 {
        256
    }
    fn size_of_val(self: @u256) -> u256 {
        U256SizeOf::size_of()
    }
}
