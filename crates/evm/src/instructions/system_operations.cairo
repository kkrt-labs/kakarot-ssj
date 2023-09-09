//! System operations.

// Corelib imports
use traits::TryInto;
use box::BoxTrait;

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
use evm::errors::EVMError;

#[generate_trait]
impl SystemOperations of SystemOperationsTrait {
    /// CREATE
    /// # Specification: https://www.evm.codes/#f0?fork=shanghai
    fn exec_create(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }


    /// CREATE2
    /// # Specification: https://www.evm.codes/#f5?fork=shanghai
    fn exec_create2(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// INVALID
    /// # Specification: https://www.evm.codes/#fe?fork=shanghai
    fn exec_invalid(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// RETURN
    /// # Specification: https://www.evm.codes/#f3?fork=shanghai
    fn exec_return(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset = self.stack.pop()?;
        let size = self.stack.pop()?;
        let mut return_data = array![];
        self
            .memory
            .load_n(
                size.low.try_into().expect('Too much return data'),
                ref return_data,
                offset.low.try_into().expect('Return data offset > u32')
            );
        self.set_return_data(return_data);
        self.stop();
        Result::Ok(())
    }

    /// REVERT
    /// # Specification: https://www.evm.codes/#fd?fork=shanghai
    fn exec_revert(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// CALL
    /// # Specification: https://www.evm.codes/#f1?fork=shanghai
    fn exec_call(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// STATICCALL
    /// # Specification: https://www.evm.codes/#fa?fork=shanghai
    fn exec_staticcall(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// CALLCODE
    /// # Specification: https://www.evm.codes/#f2?fork=shanghai
    fn exec_callcode(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// DELEGATECALL
    /// # Specification: https://www.evm.codes/#f4?fork=shanghai
    fn exec_delegatecall(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// SELFDESTRUCT
    /// # Specification: https://www.evm.codes/#ff?fork=shanghai
    fn exec_selfdestruct(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }
}
