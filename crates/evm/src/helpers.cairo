use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use starknet::StorageBaseAddress;
use utils::traits::Felt252TryIntoStorageBaseAddress;

trait TryIntoResult<T, U> {
    fn try_into_result(self: T) -> Result<U, EVMError>;
}

impl U256TryIntoResultU32 of TryIntoResult<u256, u32> {
    /// Converts a u256 into a Result<u32, EVMError>
    /// If the u256 is larger than MAX_U32, it returns an error.
    /// Otherwise, it returns the casted value.
    fn try_into_result(self: u256) -> Result<u32, EVMError> {
        match self.try_into() {
            Option::Some(value) => Result::Ok(value),
            Option::None => Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
        }
    }
}

impl U256TryIntoResultStorageBaseAddress of TryIntoResult<u256, StorageBaseAddress> {
    /// Converts a u256 into a Result<u32, EVMError>
    /// If the u256 is larger than MAX_U32, it returns an error.
    /// Otherwise, it returns the casted value.
    fn try_into_result(self: u256) -> Result<StorageBaseAddress, EVMError> {
        let res_felt: felt252 = self
            .try_into()
            .ok_or(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))?;
        let res_sba: StorageBaseAddress = res_felt
            .try_into()
            .ok_or(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))?;
        Result::Ok(res_sba)
    }
}
