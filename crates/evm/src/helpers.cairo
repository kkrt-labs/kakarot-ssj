use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};

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
            Option::None(_) => Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
        }
    }
}
