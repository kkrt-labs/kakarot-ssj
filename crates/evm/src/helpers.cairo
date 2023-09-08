use traits::{Into, TryInto};
use option::OptionTrait;
use result::ResultTrait;
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};

// Try converting u256 to u32
impl U256IntoResultU32 of Into<u256, Result<u32, EVMError>> {
    fn into(self: u256) -> Result<u32, EVMError> {
        match self.try_into() {
            Option::Some(value) => Result::Ok(value),
            Option::None(_) => Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
        }
    }
}
