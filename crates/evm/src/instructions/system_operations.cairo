//! System operations.

use box::BoxTrait;
use evm::call_helpers::{MachineCallHelpers, CallType};
use evm::errors::{EVMError, VALUE_TRANSFER_IN_STATIC_CALL, WRITE_IN_STATIC_CONTEXT};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait, AccountTypeTrait};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use utils::math::Exponentiation;


#[generate_trait]
impl SystemOperations of SystemOperationsTrait {
    /// CREATE
    /// # Specification: https://www.evm.codes/#f0?fork=shanghai
    fn exec_create(ref self: Machine) -> Result<(), EVMError> {
        if self.read_only() {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }
        Result::Err(EVMError::NotImplemented)
    }


    /// CREATE2
    /// # Specification: https://www.evm.codes/#f5?fork=shanghai
    fn exec_create2(ref self: Machine) -> Result<(), EVMError> {
        if self.read_only() {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }
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

        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the parent context return data
        // and halt the context.
        self.set_return_data(return_data.span());
        self.set_stopped();
        Result::Ok(())
    }

    /// REVERT
    /// # Specification: https://www.evm.codes/#fd?fork=shanghai
    fn exec_revert(ref self: Machine) -> Result<(), EVMError> {
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the parent context return data
        // and halt the context.
        self.set_return_data(return_data.span());
        self.set_reverted();
        Result::Ok(())
    }

    /// CALL
    /// # Specification: https://www.evm.codes/#f1?fork=shanghai
    fn exec_call(ref self: Machine) -> Result<(), EVMError> {
        let call_args = self.prepare_call(CallType::Call)?;
        let read_only = self.read_only();
        let value = call_args.value;

        // Check if current context is read only that value == 0.
        if read_only && (value != 0) {
            return Result::Err(EVMError::WriteInStaticContext(VALUE_TRANSFER_IN_STATIC_CALL));
        }

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        let caller_address = self.address();
        let sender_balance = self.state.read_balance(caller_address.evm)?;
        if sender_balance < value {
            return self.stack.push(0);
        }

        // Initialize the sub context.
        self.init_sub_ctx(call_args, read_only)
    }

    /// STATICCALL
    /// # Specification: https://www.evm.codes/#fa?fork=shanghai
    fn exec_staticcall(ref self: Machine) -> Result<(), EVMError> {
        let call_args = self.prepare_call(CallType::StaticCall)?;
        let read_only = self.read_only();

        // Initialize the sub context.
        self.init_sub_ctx(call_args, read_only)
    }

    /// CALLCODE
    /// # Specification: https://www.evm.codes/#f2?fork=shanghai
    fn exec_callcode(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// DELEGATECALL
    /// # Specification: https://www.evm.codes/#f4?fork=shanghai
    fn exec_delegatecall(ref self: Machine) -> Result<(), EVMError> {
        let call_args = self.prepare_call(CallType::DelegateCall)?;
        let read_only = self.read_only();

        // Initialize the sub context.
        self.init_sub_ctx(call_args, read_only)
    }

    /// SELFDESTRUCT
    /// # Specification: https://www.evm.codes/#ff?fork=shanghai
    fn exec_selfdestruct(ref self: Machine) -> Result<(), EVMError> {
        if self.read_only() {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }
        Result::Err(EVMError::NotImplemented)
    }
}
