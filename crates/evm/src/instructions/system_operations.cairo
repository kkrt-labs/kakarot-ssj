//! System operations.

use box::BoxTrait;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::call_helpers::{CallHelpers, CallType};
use evm::create_helpers::{CreateHelpers, CreateType};
use evm::errors::{ensure, EVMError, VALUE_TRANSFER_IN_STATIC_CALL};
use evm::gas;
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Address, Transfer};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use utils::math::Exponentiation;
use utils::set::SetTrait;

#[generate_trait]
impl SystemOperations of SystemOperationsTrait {
    /// CREATE
    /// # Specification: https://www.evm.codes/#f0?fork=shanghai
    fn exec_create(ref self: VM) -> Result<(), EVMError> {
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        let create_args = self.prepare_create(CreateType::Create)?;
        self.generic_create(create_args)
    }


    /// CALL
    /// # Specification: https://www.evm.codes/#f1?fork=shanghai
    fn exec_call(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_u128()?;
        let to = self.stack.pop_eth_address()?;
        let value = self.stack.pop()?;
        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;
        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let args_max_offset = args_offset + args_size;
        let ret_max_offset = ret_offset + ret_size;

        let max_memory_size = if args_max_offset > ret_max_offset {
            args_max_offset
        } else {
            ret_max_offset
        };

        // GAS
        //TODO(optimization): if we know how much the memory is going to be expanded,
        // we can return the new size and save a computation later.
        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), max_memory_size);

        let access_gas_cost = if self.accessed_addresses.contains(to) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(to);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let create_gas_cost = if self.env.state.is_account_alive(to) || value == 0 {
            0
        } else {
            gas::NEWACCOUNT
        };

        let transfer_gas_cost = if value != 0 {
            gas::CALLVALUE
        } else {
            0
        };

        let message_call_gas = gas::calculate_message_call_gas(
            value,
            gas,
            self.gas_left(),
            expand_memory_cost,
            access_gas_cost + transfer_gas_cost + create_gas_cost
        );
        self.charge_gas(message_call_gas.cost + expand_memory_cost)?;
        // Only the transfer gas is left to charge.

        let read_only = self.message().read_only;

        // Check if current context is read only that value == 0.
        // De Morgan's law: !(read_only && value != 0) == !read_only || value == 0
        ensure(!read_only || value == 0, EVMError::WriteInStaticContext)?;

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        // The gas cost relative to the transfer is refunded.
        let sender_balance = self.env.state.get_account(self.message().target.evm).balance();
        if sender_balance < value {
            self.return_data = Default::default().span();
            self.gas_left += message_call_gas.stipend;
            return self.stack.push(0);
        }

        // Initialize the sub context.
        // TODO(elias)
        // create a new sub context here
        // with the correct arguments
        // let result = sub_ctx.process_message();
        // store the return data in the memory of the parent context with the correct offsets and size
        // store the return data whole in the return data field of the parent context
        self
            .generic_call(
                gas: message_call_gas.stipend,
                :value,
                caller: self.message().target.evm,
                :to,
                code_address: to,
                should_transfer_value: true,
                is_staticcall: false,
                :args_offset,
                :args_size,
                :ret_offset,
                :ret_size,
            )
    }


    /// CALLCODE
    /// # Specification: https://www.evm.codes/#f2?fork=shanghai
    fn exec_callcode(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_u128()?;
        let code_address = self.stack.pop_eth_address()?;
        let value = self.stack.pop()?;
        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;
        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let args_max_offset = args_offset + args_size;
        let ret_max_offset = ret_offset + ret_size;

        let to = self.message().target.evm;

        let max_memory_size = if args_max_offset > ret_max_offset {
            args_max_offset
        } else {
            ret_max_offset
        };

        // GAS
        //TODO(optimization): if we know how much the memory is going to be expanded,
        // we can return the new size and save a computation later.
        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), max_memory_size);

        let access_gas_cost = if self.accessed_addresses.contains(code_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(code_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let transfer_gas_cost = if value != 0 {
            gas::CALLVALUE
        } else {
            0
        };

        let message_call_gas = gas::calculate_message_call_gas(
            value, gas, self.gas_left(), expand_memory_cost, access_gas_cost + transfer_gas_cost
        );
        self.charge_gas(message_call_gas.cost + expand_memory_cost)?;

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        // The gas cost relative to the transfer is refunded.
        let sender_balance = self.env.state.get_account(self.message().target.evm).balance();
        if sender_balance < value {
            self.return_data = Default::default().span();
            self.gas_left += message_call_gas.stipend;
            return self.stack.push(0);
        }

        self
            .generic_call(
                message_call_gas.stipend,
                value,
                self.message().target.evm,
                to,
                code_address,
                true,
                false,
                args_offset,
                args_size,
                ret_offset,
                ret_size,
            )
    }
    /// RETURN
    /// # Specification: https://www.evm.codes/#f3?fork=shanghai
    fn exec_return(ref self: VM) -> Result<(), EVMError> {
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;
        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), offset + size);
        self.charge_gas(gas::ZERO + expand_memory_cost)?;

        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the parent context return data
        // and halt the context.
        self.set_return_data(return_data.span());
        self.stop();
        Result::Ok(())
    }

    /// DELEGATECALL
    /// # Specification: https://www.evm.codes/#f4?fork=shanghai
    fn exec_delegatecall(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_u128()?;
        let code_address = self.stack.pop_eth_address()?;
        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;
        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let args_max_offset = args_offset + args_size;
        let ret_max_offset = ret_offset + ret_size;

        let max_memory_size = if args_max_offset > ret_max_offset {
            args_max_offset
        } else {
            ret_max_offset
        };

        // GAS
        //TODO(optimization): if we know how much the memory is going to be expanded,
        // we can return the new size and save a computation later.
        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), max_memory_size);

        let access_gas_cost = if self.accessed_addresses.contains(code_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(code_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let message_call_gas = gas::calculate_message_call_gas(
            0, gas, self.gas_left(), expand_memory_cost, access_gas_cost
        );
        self.charge_gas(message_call_gas.cost + expand_memory_cost)?;

        self
            .generic_call(
                message_call_gas.stipend,
                self.message().value,
                self.message().caller.evm,
                self.message().target.evm,
                code_address,
                false,
                false,
                args_offset,
                args_size,
                ret_offset,
                ret_size,
            )
    }

    /// CREATE2
    /// # Specification: https://www.evm.codes/#f5?fork=shanghai
    fn exec_create2(ref self: VM) -> Result<(), EVMError> {
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        // TODO: add dynamic gas costs
        self.charge_gas(gas::CREATE)?;

        let create_args = self.prepare_create(CreateType::Create2)?;
        self.generic_create(create_args)
    }

    /// STATICCALL
    /// # Specification: https://www.evm.codes/#fa?fork=shanghai
    fn exec_staticcall(ref self: VM) -> Result<(), EVMError> {
        let gas = self.stack.pop_u128()?;
        let to = self.stack.pop_eth_address()?;
        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;
        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let args_max_offset = args_offset + args_size;
        let ret_max_offset = ret_offset + ret_size;

        let max_memory_size = if args_max_offset > ret_max_offset {
            args_max_offset
        } else {
            ret_max_offset
        };

        // GAS
        //TODO(optimization): if we know how much the memory is going to be expanded,
        // we can return the new size and save a computation later.
        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), max_memory_size);

        let access_gas_cost = if self.accessed_addresses.contains(to) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(to);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let message_call_gas = gas::calculate_message_call_gas(
            0, gas, self.gas_left(), expand_memory_cost, access_gas_cost
        );
        self.charge_gas(message_call_gas.cost + expand_memory_cost)?;

        self
            .generic_call(
                message_call_gas.stipend,
                0,
                self.message().target.evm,
                to,
                to,
                true,
                true,
                args_offset,
                args_size,
                ret_offset,
                ret_size,
            )
    }


    /// REVERT
    /// # Specification: https://www.evm.codes/#fd?fork=shanghai
    fn exec_revert(ref self: VM) -> Result<(), EVMError> {
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), offset + size);
        self.charge_gas(expand_memory_cost)?;

        let mut return_data = Default::default();
        self.memory.load_n(size, ref return_data, offset);

        // Set the memory data to the parent context return data
        // and halt the context.
        self.set_return_data(return_data.span());
        self.stop();
        self.set_error();
        Result::Ok(())
    }

    /// INVALID
    /// # Specification: https://www.evm.codes/#fe?fork=shanghai
    fn exec_invalid(ref self: VM) -> Result<(), EVMError> {
        Result::Err(EVMError::InvalidOpcode(0xfe))
    }


    /// SELFDESTRUCT
    /// # Specification: https://www.evm.codes/#ff?fork=shanghai
    fn exec_selfdestruct(ref self: VM) -> Result<(), EVMError> {
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

        // TODO: add dynamic gas costs
        self.charge_gas(gas::SELFDESTRUCT)?;

        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let address = self.stack.pop_eth_address()?;

        // GAS
        let mut gas_cost = gas::SELFDESTRUCT;
        if !self.accessed_addresses.contains(address) {
            gas_cost += gas::COLD_ACCOUNT_ACCESS_COST;
        };

        if (!self.env.state.is_account_alive(address)
            && self.env.state.get_account(address).balance() != 0) {
            gas_cost += gas::NEWACCOUNT;
        }
        self.charge_gas(gas_cost)?;

        //TODO Remove this when https://eips.ethereum.org/EIPS/eip-6780 is validated
        let recipient_evm_address = if (address == self.message().target.evm) {
            0.try_into().unwrap()
        } else {
            address
        };
        let recipient_starknet_address = kakarot_state
            .compute_starknet_address(recipient_evm_address);
        let mut account = self.env.state.get_account(self.message().target.evm);

        let recipient = Address {
            evm: recipient_evm_address, starknet: recipient_starknet_address
        };

        // Transfer balance
        self
            .env
            .state
            .add_transfer(
                Transfer {
                    sender: account.address(),
                    recipient,
                    amount: self.env.state.get_account(account.address().evm).balance
                }
            )?;

        // Register for selfdestruct
        account.selfdestruct();
        self.env.state.set_account(account);
        self.stop();
        Result::Ok(())
    }
}
