//! System operations.

use box::BoxTrait;
use evm::errors::EVMError;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;

#[generate_trait]
impl SystemOperations of SystemOperationsTrait {
    /// CREATE
    /// # Specification: https://www.evm.codes/#f0?fork=shanghai
    fn exec_create(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }


    /// CREATE2
    /// # Specification: https://www.evm.codes/#f5?fork=shanghai
    fn exec_create2(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// INVALID
    /// # Specification: https://www.evm.codes/#fe?fork=shanghai
    fn exec_invalid(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// RETURN
    /// # Specification: https://www.evm.codes/#f3?fork=shanghai
    fn exec_return(ref self: Machine) -> Result<(), EVMError> {
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;
        let mut return_data = array![];
        self.memory.load_n(size, ref return_data, offset);
        self.set_return_data(return_data);
        self.stop();
        Result::Ok(())
    }

    /// REVERT
    /// # Specification: https://www.evm.codes/#fd?fork=shanghai
    fn exec_revert(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// CALL
    /// # Specification: https://www.evm.codes/#f1?fork=shanghai
    fn exec_call(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// STATICCALL
    /// # Specification: https://www.evm.codes/#fa?fork=shanghai
    fn exec_staticcall(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// CALLCODE
    /// # Specification: https://www.evm.codes/#f2?fork=shanghai
    fn exec_callcode(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// DELEGATECALL
    /// # Specification: https://www.evm.codes/#f4?fork=shanghai
    fn exec_delegatecall(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// SELFDESTRUCT
    /// # Specification: https://www.evm.codes/#ff?fork=shanghai
    fn exec_selfdestruct(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }
}
