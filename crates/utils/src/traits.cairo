use starknet::EthAddress;
use starknet::ContractAddress;

impl SpanDefault<T, impl TDrop: Drop<T>> of Default<Span<T>> {
    #[inline(always)]
    fn default() -> Span<T> {
        Default::default().span()
    }
}

impl EthAddressDefault of Default<EthAddress> {
    #[inline(always)]
    fn default() -> EthAddress {
        0.try_into().unwrap()
    }
}

impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        0.try_into().unwrap()
    }
}

impl BoolIntoU8 of Into<bool, u8> {
    fn into(self: bool) -> u8 {
        if (self) {
            1
        } else {
            0
        }
    }
}

impl BoolIntoU16 of Into<bool, u16> {
    fn into(self: bool) -> u16 {
        BoolIntoU8::into(self).into()
    }
}


impl BoolIntoU32 of Into<bool, u32> {
    fn into(self: bool) -> u32 {
        BoolIntoU8::into(self).into()
    }
}

impl BoolIntoU64 of Into<bool, u64> {
    fn into(self: bool) -> u64 {
        BoolIntoU8::into(self).into()
    }
}

impl BoolIntoU128 of Into<bool, u128> {
    fn into(self: bool) -> u128 {
        BoolIntoU8::into(self).into()
    }
}

impl BoolIntoU256 of Into<bool, u256> {
    fn into(self: bool) -> u256 {
        BoolIntoU8::into(self).into()
    }
}
