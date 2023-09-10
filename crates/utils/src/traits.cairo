use starknet::EthAddress;
use starknet::ContractAddress;
use math::{Zeroable, Oneable};

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

impl BoolIntoNumeric<T, impl TZeroable: Zeroable<T>, impl TOneable: Oneable<T>> of Into<bool, T> {
    #[inline(always)]
    fn into(self: bool) -> T {
        if self {
            Oneable::<T>::one()
        } else {
            Zeroable::<T>::zero()
        }
    }
}
