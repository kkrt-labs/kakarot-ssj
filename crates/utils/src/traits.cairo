use core::array::SpanTrait;
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use starknet::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252, EthAddress,
    ContractAddress, Store, SyscallResult
};
use utils::math::{Zero, One, Bitshift};


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
        let maybe_value: Option<felt252> = self.try_into();
        match maybe_value {
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

impl SpanU8TryIntoResultEthAddress of TryIntoResult<Span<u8>, EthAddress> {
    fn try_into_result(mut self: Span<u8>) -> Result<EthAddress, EVMError> {
        let len = self.len();
        if len == 0 {
            return Result::Ok(EthAddress { address: 0 });
        }
        if len > 20 {
            return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
        }
        let offset: u32 = len.into() - 1;
        let mut result: u256 = 0;
        let mut i: u32 = 0;
        loop {
            if i == len {
                break ();
            }
            let byte: u256 = (*self.at(i)).into();
            result += byte.shl(8 * (offset - i).into());

            i += 1;
        };
        let address: felt252 = result.try_into_result()?;

        Result::Ok(EthAddress { address })
    }
}

impl EthAddressTryIntoResultContractAddress of TryIntoResult<ContractAddress, EthAddress> {
    fn try_into_result(self: ContractAddress) -> Result<EthAddress, EVMError> {
        let tmp: felt252 = self.into();
        tmp.try_into().ok_or(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
    }
}

impl U256TryIntoResult<U, +TryInto<u256, U>> of TryIntoResult<u256, U> {
    fn try_into_result(self: u256) -> Result<U, EVMError> {
        match self.try_into() {
            Option::Some(value) => Result::Ok(value),
            Option::None => Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
        }
    }
}

impl U256TryIntoEthAddress of TryInto<u256, EthAddress> {
    fn try_into(self: u256) -> Option<EthAddress> {
        let maybe_value: Option<felt252> = self.try_into();
        match maybe_value {
            Option::Some(value) => value.try_into(),
            Option::None => Option::None,
        }
    }
}
