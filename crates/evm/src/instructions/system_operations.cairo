//! System operations.

use box::BoxTrait;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::call_helpers::{MachineCallHelpers, CallType};
use evm::create_helpers::{MachineCreateHelpers, CreateType};
use evm::errors::{EVMError, VALUE_TRANSFER_IN_STATIC_CALL, WRITE_IN_STATIC_CONTEXT};
use evm::machine::{Machine, MachineTrait};
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::{Address, Transfer};
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
        let create_args = self.prepare_create(CreateType::CreateOrDeployTx)?;

        self.init_create_sub_ctx(create_args)
    }


    /// CREATE2
    /// # Specification: https://www.evm.codes/#f5?fork=shanghai
    fn exec_create2(ref self: Machine) -> Result<(), EVMError> {
        if self.read_only() {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }
        let create_args = self.prepare_create(CreateType::Create2)?;

        self.init_create_sub_ctx(create_args)
    }

    /// INVALID
    /// # Specification: https://www.evm.codes/#fe?fork=shanghai
    fn exec_invalid(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::InvalidOpcode(0xfe))
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
        let call_args = self.prepare_call(@CallType::Call)?;
        let read_only = self.read_only();
        let value = call_args.value;

        // Check if current context is read only that value == 0.
        if read_only && (value != 0) {
            return Result::Err(EVMError::WriteInStaticContext(VALUE_TRANSFER_IN_STATIC_CALL));
        }

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        let caller_address = self.address();
        let sender_balance = self.state.get_account(caller_address.evm).balance();
        if sender_balance < value {
            return self.stack.push(0);
        }

        // Initialize the sub context.
        self.init_call_sub_ctx(call_args, read_only)
    }

    /// STATICCALL
    /// # Specification: https://www.evm.codes/#fa?fork=shanghai
    fn exec_staticcall(ref self: Machine) -> Result<(), EVMError> {
        let call_args = self.prepare_call(@CallType::StaticCall)?;
        let read_only = self.read_only();

        // Initialize the sub context.
        self.init_call_sub_ctx(call_args, read_only)
    }

    /// CALLCODE
    /// # Specification: https://www.evm.codes/#f2?fork=shanghai
    fn exec_callcode(ref self: Machine) -> Result<(), EVMError> {
        let call_args = self.prepare_call(@CallType::CallCode)?;
        let read_only = self.read_only();

        // Initialize the sub context.
        self.init_call_sub_ctx(call_args, read_only)
    }

    /// DELEGATECALL
    /// # Specification: https://www.evm.codes/#f4?fork=shanghai
    fn exec_delegatecall(ref self: Machine) -> Result<(), EVMError> {
        let call_args = self.prepare_call(@CallType::DelegateCall)?;
        let read_only = self.read_only();

        // Initialize the sub context.
        self.init_call_sub_ctx(call_args, read_only)
    }

    /// SELFDESTRUCT
    /// # Specification: https://www.evm.codes/#ff?fork=shanghai
    fn exec_selfdestruct(ref self: Machine) -> Result<(), EVMError> {
        if self.read_only() {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let address = self.stack.pop_eth_address()?;

        //TODO Remove this when https://eips.ethereum.org/EIPS/eip-6780 is validated
        let recipient_evm_address = if (address == self.address().evm) {
            0.try_into().unwrap()
        } else {
            address
        };
        let recipient_starknet_address = kakarot_state
            .compute_starknet_address(recipient_evm_address);
        let mut account = self.state.get_account(self.address().evm);

        let recipient = Address {
            evm: recipient_evm_address, starknet: recipient_starknet_address
        };

        // Transfer balance
        self
            .state
            .add_transfer(
                Transfer {
                    sender: account.address(),
                    recipient,
                    amount: self.state.get_account(account.address().evm).balance
                }
            );

        // Register for selfdestruct
        account.selfdestruct();
        self.state.set_account(account);
        self.set_stopped();
        Result::Ok(())
    }
}
