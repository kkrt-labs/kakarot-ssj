use starknet::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252, EthAddress,
    ContractAddress
};
use utils::math::{Zero, One};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};

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

impl BoolIntoNumeric<T, +Zero<T>, +One<T>> of Into<bool, T> {
    #[inline(always)]
    fn into(self: bool) -> T {
        if self {
            One::<T>::one()
        } else {
            Zero::<T>::zero()
        }
    }
}

impl EthAddressIntoU256 of Into<EthAddress, u256> {
    fn into(self: EthAddress) -> u256 {
        let intermediate: felt252 = self.into();
        intermediate.into()
    }
}

impl U256TryIntoContractAddress of TryInto<u256, ContractAddress> {
    fn try_into(self: u256) -> Option<ContractAddress> {
        let intermediate: Option<felt252> = self.try_into();
        match intermediate {
            Option::Some(value) => value.try_into(),
            Option::None => Option::None,
        }
    }
}

//TODO remove once merged in corelib
impl StorageBaseAddressIntoFelt252 of Into<StorageBaseAddress, felt252> {
    fn into(self: StorageBaseAddress) -> felt252 {
        storage_address_from_base(self).into()
    }
}


impl StorageBaseAddressIntoU256 of Into<StorageBaseAddress, u256> {
    fn into(self: StorageBaseAddress) -> u256 {
        let self: felt252 = storage_address_from_base(self).into();
        self.into()
    }
}

//TODO remove once merged in corelib
impl StorageBaseAddressPartialEq of PartialEq<StorageBaseAddress> {
    fn eq(lhs: @StorageBaseAddress, rhs: @StorageBaseAddress) -> bool {
        let lhs: felt252 = (*lhs).into();
        let rhs: felt252 = (*rhs).into();
        lhs == rhs
    }
    fn ne(lhs: @StorageBaseAddress, rhs: @StorageBaseAddress) -> bool {
        !(*lhs == *rhs)
    }
}

trait TryIntoResult<T, U> {
    fn try_into_result(self: T) -> Result<U, EVMError>;
}

impl U256TryIntoResultU32 of TryIntoResult<u256, usize> {
    /// Converts a u256 into a Result<u32, EVMError>
    /// If the u256 is larger than MAX_U32, it returns an error.
    /// Otherwise, it returns the casted value.
    fn try_into_result(self: u256) -> Result<usize, EVMError> {
        match self.try_into() {
            Option::Some(value) => Result::Ok(value),
            Option::None => Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
        }
    }
}
