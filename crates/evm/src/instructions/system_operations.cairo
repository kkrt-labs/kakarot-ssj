//! System operations.

use box::BoxTrait;
use evm::balance::balance;
use evm::call_helpers::MachineCallHelpers;
use evm::errors::EVMError;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
use utils::math::Exponentiation;

const VALUE_TRANSFER_IN_STATIC_CALL: felt252 = 'KKT: transfer value in static';

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
        // Pop the offset and size to load return data from memory
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        // Load the data from memory
        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the context output
        // and halt the context.
        self.set_output(return_data.span());
        self.set_stopped();
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
        // Prepare the call arguments with with_value = true for a call.
        let call_args = self.prepare_call(true)?;
        let read_only = self.read_only();
        let value = call_args.value;

        // Check if current context is read only that value == 0.
        if read_only & (value != 0) {
            return Result::Err(EVMError::WriteInStaticContext(VALUE_TRANSFER_IN_STATIC_CALL));
        }

        // If sender_balance > value, return early, pushing
        // 0 on the stack to indicate call failure.
        let caller_address = self.evm_address();
        let sender_balance = balance(caller_address)?;
        if sender_balance < value {
            self.stack.push(0);
            return Result::Ok(());
        }

        // Initialize the sub context.
        self.init_sub_call_ctx(call_args, read_only,);

        Result::Ok(())
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
