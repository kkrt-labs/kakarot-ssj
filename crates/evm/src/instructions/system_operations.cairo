use contracts::kakarot_core::{KakarotCore, IKakarotCore};
//! System operations.

use core::box::BoxTrait;
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
        let memory_expansion = gas::memory_expansion(self.memory.size(), max_memory_size);

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
            memory_expansion.expansion_cost,
            access_gas_cost + transfer_gas_cost + create_gas_cost
        );
        self.charge_gas(message_call_gas.cost + memory_expansion.expansion_cost)?;
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
            self.return_data = array![].span();
            self.gas_left += message_call_gas.stipend;
            return self.stack.push(0);
        }

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
        let memory_expansion = gas::memory_expansion(self.memory.size(), max_memory_size);

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
            value,
            gas,
            self.gas_left(),
            memory_expansion.expansion_cost,
            access_gas_cost + transfer_gas_cost
        );
        self.charge_gas(message_call_gas.cost + memory_expansion.expansion_cost)?;

        // If sender_balance < value, return early, pushing
        // 0 on the stack to indicate call failure.
        // The gas cost relative to the transfer is refunded.
        let sender_balance = self.env.state.get_account(self.message().target.evm).balance();
        if sender_balance < value {
            self.return_data = array![].span();
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
        let memory_expansion = gas::memory_expansion(self.memory.size(), offset + size);
        self.charge_gas(gas::ZERO + memory_expansion.expansion_cost)?;

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
        let memory_expansion = gas::memory_expansion(self.memory.size(), max_memory_size);

        let access_gas_cost = if self.accessed_addresses.contains(code_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(code_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let message_call_gas = gas::calculate_message_call_gas(
            0, gas, self.gas_left(), memory_expansion.expansion_cost, access_gas_cost
        );
        self.charge_gas(message_call_gas.cost + memory_expansion.expansion_cost)?;

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
        let memory_expansion = gas::memory_expansion(self.memory.size(), max_memory_size);

        let access_gas_cost = if self.accessed_addresses.contains(to) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(to);
            gas::COLD_ACCOUNT_ACCESS_COST
        };

        let message_call_gas = gas::calculate_message_call_gas(
            0, gas, self.gas_left(), memory_expansion.expansion_cost, access_gas_cost
        );
        self.charge_gas(message_call_gas.cost + memory_expansion.expansion_cost)?;

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

        let memory_expansion = gas::memory_expansion(self.memory.size(), offset + size);
        self.charge_gas(memory_expansion.expansion_cost)?;

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

        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;

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

#[cfg(test)]
mod tests {
    use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
    use contracts::test_data::{storage_evm_bytecode, storage_evm_initcode};
    use contracts::test_utils::{
        fund_account_with_native_token, setup_contracts_for_testing, deploy_contract_account,
        deploy_eoa
    };
    use core::result::ResultTrait;
    use core::traits::TryInto;
    use evm::backend::starknet_backend;
    use evm::call_helpers::{CallHelpers, CallHelpersImpl};
    use evm::errors::EVMErrorTrait;
    use evm::instructions::MemoryOperationTrait;
    use evm::instructions::SystemOperationsTrait;
    use evm::interpreter::{EVMTrait};
    use evm::memory::MemoryTrait;
    use evm::model::account::{Account};
    use evm::model::vm::{VM, VMTrait};
    use evm::model::{AccountTrait, Address, Transfer};
    use evm::stack::StackTrait;
    use evm::state::{StateTrait, State};
    use evm::test_utils::{
        VMBuilderTrait, initialize_contract_account, native_token, evm_address, test_address,
        other_evm_address,
    };
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::EthAddress;
    use starknet::testing::set_contract_address;
    use utils::helpers::load_word;
    use utils::traits::{EthAddressIntoU256};


    #[test]
    fn test_exec_return() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // When
        vm.stack.push(1000).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.exec_mstore().expect('exec_mstore failed');

        vm.stack.push(32).expect('push failed');
        vm.stack.push(0).expect('push failed');
        assert(vm.exec_return().is_ok(), 'Exec return failed');

        // Then
        assert(1000 == load_word(32, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
        assert_eq!(vm.error, false);
    }

    #[test]
    fn test_exec_revert() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // When
        vm.stack.push(1000).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.exec_mstore().expect('exec_mstore failed');

        vm.stack.push(32).expect('push failed');
        vm.stack.push(0).expect('push failed');
        assert(vm.exec_revert().is_ok(), 'Exec revert failed');

        // Then
        assert(1000 == load_word(32, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
        assert_eq!(vm.error, true);
    }

    #[test]
    fn test_exec_return_with_offset() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        // When
        vm.stack.push(1).expect('push failed');
        vm.stack.push(0).expect('push failed');
        vm.exec_mstore().expect('exec_mstore failed');

        vm.stack.push(32).expect('push failed');
        vm.stack.push(1).expect('push failed');
        assert(vm.exec_return().is_ok(), 'Exec return failed');

        // Then
        assert(256 == load_word(32, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
        assert_eq!(vm.error, false);
    }

    #[test]
    fn test_exec_call() {
        // Given
        let (_, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        kakarot_core.deploy_externally_owned_account(evm_address);

        // Set vm bytecode
        // (call 0xffffff 0xabfa740ccd 0 0 0 0 1)
        let bytecode = array![
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x64,
            0xab,
            0xfa,
            0x74,
            0x0c,
            0xcd,
            0x62,
            0xff,
            0xff,
            0xff,
            // CALL
            0xf1,
            0x00
        ]
            .span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        // Deploy bytecode at 0xabfa740ccd
        // ret (+ 0x1 0x1)
        let deployed_bytecode = array![
            0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x60, 0x20, 0x60, 0x00, 0xf3
        ]
            .span();
        let eth_address: EthAddress = 0xabfa740ccd_u256.into();
        initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
            .expect('set code failed');

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert(!vm.is_running(), 'run should be success');
        assert(2 == load_word(1, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');
    }

    #[test]
    fn test_exec_call_no_return() {
        // Given
        let (_, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        kakarot_core.deploy_externally_owned_account(evm_address);

        // Set vm bytecode
        // (call 0xffffff 0xabfa740ccd 0 0 0 0 1)
        let bytecode = array![
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x64,
            0xab,
            0xfa,
            0x74,
            0x0c,
            0xcd,
            0x62,
            0xff,
            0xff,
            0xff,
            // CALL
            0xf1,
            0x00
        ]
            .span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        // Deploy bytecode at 0xabfa740ccd
        // (+ 0x1 0x1)
        let deployed_bytecode = array![0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x00].span();
        let eth_address: EthAddress = 0xabfa740ccd_u256.into();
        initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
            .expect('set code failed');

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert(!vm.is_running(), 'run should be success');
        assert(vm.return_data().is_empty(), 'Wrong return_data len');
        assert(!vm.is_running(), 'vm should be stopped')
    }

    #[test]
    fn test_exec_staticcall() {
        // Given
        let (_, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        kakarot_core.deploy_externally_owned_account(evm_address);

        // Set vm bytecode
        // (call 0xffffff 0xabfa740ccd 0 0 0 0 1)
        let bytecode = array![
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x64,
            0xab,
            0xfa,
            0x74,
            0x0c,
            0xcd,
            0x62,
            0xff,
            0xff,
            0xff,
            // STATICCALL
            0xfa,
            0x00
        ]
            .span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        // Deploy bytecode at 0xabfa740ccd
        // ret (+ 0x1 0x1)
        let deployed_bytecode = array![
            0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x60, 0x20, 0x60, 0x00, 0xf3
        ]
            .span();
        let eth_address: EthAddress = 0xabfa740ccd_u256.into();
        initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
            .expect('set code failed');

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert(2 == load_word(1, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped')
    }

    #[test]
    fn test_exec_staticcall_no_return() {
        // Given

        let (_, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        kakarot_core.deploy_externally_owned_account(evm_address);

        // Set vm bytecode
        // (call 0xffffff 0xabfa740ccd 0 0 0 0 1)
        let bytecode = array![
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x64,
            0xab,
            0xfa,
            0x74,
            0x0c,
            0xcd,
            0x62,
            0xff,
            0xff,
            0xff,
            // STATICCALL
            0xfa,
            0x00
        ]
            .span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        // Deploy bytecode at 0xabfa740ccd
        // (+ 0x1 0x1)
        let deployed_bytecode = array![0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x00].span();
        let eth_address: EthAddress = 0xabfa740ccd_u256.into();
        initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
            .expect('set code failed');

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert(vm.return_data().is_empty(), 'Wrong return_data len');
        assert(!vm.is_running(), 'vm should be stopped')
    }

    #[test]
    fn test_exec_call_code() {
        // Given

        let (_, _) = setup_contracts_for_testing();

        let evm_address = evm_address();
        deploy_contract_account(evm_address, array![].span());

        // Set vm bytecode
        // (call 0xffffff 0x100 0 0 0 0 1)
        let bytecode = array![
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x61,
            0x01,
            0x00,
            0x62,
            0xff,
            0xff,
            0xff,
            // CALLCODE
            0xf2,
            0x00
        ]
            .span();
        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
        // Deploy bytecode at 0x100
        // ret (+ 0x1 0x1)
        let deployed_bytecode = array![
            0x60,
            0x01,
            0x60,
            0x01,
            0x01,
            0x60,
            0x00,
            0x53,
            0x60,
            0x42,
            0x60,
            0x42,
            0x55,
            0x60,
            0x20,
            0x60,
            0x00,
            0xf3
        ]
            .span();
        let eth_address: EthAddress = 0x100_u256.into();
        initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
            .expect('set code failed');

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert(!vm.is_running(), 'run should be success');
        assert(2 == load_word(1, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');

        let storage_val = vm.env.state.read_state(evm_address, 0x42);

        assert(storage_val == 0x42, 'storage value is not 0x42');
    }

    #[test]
    fn test_exec_delegatecall() {
        // Given

        let (_, _) = setup_contracts_for_testing();

        let evm_address = evm_address();
        deploy_contract_account(evm_address, array![].span());

        // Set vm bytecode
        // (call 0xffffff 0x100 0 0 0 0 1)
        let bytecode = array![
            0x60,
            0x01,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x60,
            0x00,
            0x61,
            0x01,
            0x00,
            0x62,
            0xff,
            0xff,
            0xff,
            // DELEGATECALL
            0xf4,
            0x00
        ]
            .span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        // ret (+ 0x1 0x1)
        let deployed_bytecode = array![
            0x60,
            0x01,
            0x60,
            0x01,
            0x01,
            0x60,
            0x00,
            0x53,
            0x60,
            0x42,
            0x60,
            0x42,
            0x55,
            0x60,
            0x20,
            0x60,
            0x00,
            0xf3
        ]
            .span();
        let eth_address: EthAddress = 0x100_u256.into();
        initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
            .expect('set code failed');

        // When
        EVMTrait::execute_code(ref vm);

        // Then
        assert(!vm.is_running(), 'run should be success');
        assert(2 == load_word(1, vm.return_data()), 'Wrong return_data');
        assert(!vm.is_running(), 'vm should be stopped');

        let storage_val = vm.env.state.read_state(evm_address, 0x42);

        assert(storage_val == 0x42, 'storage value is not 0x42');
    }

    #[test]
    fn test_exec_create_no_value_transfer() {
        // Given
        let (native_token, _) = setup_contracts_for_testing();
        let deployed_bytecode = array![0xff].span();
        let eth_address: EthAddress = evm_address();
        let contract_address = deploy_contract_account(eth_address, deployed_bytecode);

        let mut vm = VMBuilderTrait::new_with_presets().with_target(contract_address).build();

        fund_account_with_native_token(contract_address.starknet, native_token, 2);

        // Load into memory the bytecode of Storage.sol
        let storage_initcode = storage_evm_initcode();
        vm.memory.store_n(storage_initcode, 0);

        vm.stack.push(storage_initcode.len().into()).unwrap();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');

        // When
        vm.exec_create().unwrap();
        EVMTrait::execute_code(ref vm);

        // computed using `compute_create_address` script
        // run `bun run compute_create_address` -> CREATE -> EthAddress = evm_address() -> nonce = 1
        let account = vm
            .env
            .state
            .get_account(0x930b3d8D35621F2e27Db700cA5D16Df771642fdD.try_into().unwrap());

        assert_eq!(account.nonce(), 1);
        assert(account.code == storage_evm_bytecode(), 'wrong bytecode');
        assert_eq!(account.balance(), 0);

        let deployer = vm.env.state.get_account(eth_address);
        assert_eq!(deployer.nonce(), 2);
        assert_eq!(deployer.balance(), 2);
    }

    //TODO add test with value transfer

    #[test]
    #[ignore]
    fn test_exec_create_failure() {
        // Given
        let (native_token, _) = setup_contracts_for_testing();

        let deployed_bytecode = array![0xFF].span();
        let eth_address: EthAddress = evm_address();
        let contract_address = deploy_contract_account(eth_address, deployed_bytecode);
        fund_account_with_native_token(contract_address.starknet, native_token, 2);
        let mut vm = VMBuilderTrait::new_with_presets().with_target(contract_address).build();

        // Load into memory the bytecode to init, which is the revert opcode
        let revert_initcode = array![0xFD].span();
        vm.memory.store_n(revert_initcode, 0);

        vm.stack.push(revert_initcode.len().into()).unwrap();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(1).expect('push failed');

        // When
        vm.exec_create().expect('exec_create failed');
        EVMTrait::execute_code(ref vm);

        let expected_address = 0x930b3d8D35621F2e27Db700cA5D16Df771642fdD.try_into().unwrap();

        // computed using `compute_create_address` script
        let account = vm.env.state.get_account(expected_address);
        assert_eq!(account.nonce(), 0);
        assert_eq!(account.code.len(), 0);
        assert_eq!(account.balance(), 0);

        let deployer = vm.env.state.get_account(eth_address);
        assert_eq!(deployer.nonce(), 1);
        assert_eq!(deployer.balance(), 2);
    }

    #[test]
    fn test_exec_create2() {
        // Given
        setup_contracts_for_testing();

        let deployed_bytecode = array![0xff].span();
        let eth_address: EthAddress = evm_address();
        let contract_address = deploy_contract_account(eth_address, deployed_bytecode);
        let mut vm = VMBuilderTrait::new_with_presets().with_caller(contract_address).build();

        // Load into memory the bytecode of Storage.sol
        let storage_initcode = storage_evm_initcode();
        vm.memory.store_n(storage_initcode, 0);

        vm.stack.push(0).expect('push failed');
        vm.stack.push(storage_initcode.len().into()).unwrap();
        vm.stack.push(0).expect('push failed');
        vm.stack.push(0).expect('push failed');

        // When
        vm.exec_create2().unwrap();
        EVMTrait::execute_code(ref vm);

        assert!(!vm.is_running() && !vm.is_error());

        // Add SNJS script to precompute the address of the Storage.sol contract
        //     import { getContractAddress } from 'viem'

        // const address = getContractAddress({
        //   bytecode:
        //   '0x608060405234801561000f575f80fd5b506101438061001d5f395ff3fe608060405234801561000f575f80fd5b5060043610610034575f3560e01c80632e64cec1146100385780636057361d14610056575b5f80fd5b610040610072565b60405161004d919061009b565b60405180910390f35b610070600480360381019061006b91906100e2565b61007a565b005b5f8054905090565b805f8190555050565b5f819050919050565b61009581610083565b82525050565b5f6020820190506100ae5f83018461008c565b92915050565b5f80fd5b6100c181610083565b81146100cb575f80fd5b50565b5f813590506100dc816100b8565b92915050565b5f602082840312156100f7576100f66100b4565b5b5f610104848285016100ce565b9150509291505056fea2646970667358221220b5c3075f2f2034d039a227fac6dd314b052ffb2b3da52c7b6f5bc374d528ed3664736f6c63430008140033',
        //   from: '0x00000000000000000065766d5f61646472657373', opcode: 'CREATE2',
        //   salt: '0x00',
        // });
        // console.log(address)
        let account = vm
            .env
            .state
            .get_account(0x0f48B8c382B5234b1a92368ee0f6864a429d0Cb8.try_into().unwrap());

        assert(account.nonce() == 1, 'wrong nonce');
        assert(account.code == storage_evm_bytecode(), 'wrong bytecode');
    }

    #[test]
    #[ignore]
    fn test_exec_selfdestruct_existing_ca() {
        // Given
        let (native_token, _) = setup_contracts_for_testing();
        let destroyed_address = test_address().evm; // address in vm call context
        let ca_address = deploy_contract_account(destroyed_address, array![0x1, 0x2, 0x3].span());
        fund_account_with_native_token(ca_address.starknet, native_token, 1000);
        let recipient = starknet_backend::deploy(other_evm_address())
            .expect('failed deploying eoa');
        let mut vm = VMBuilderTrait::new_with_presets().with_target(ca_address).build();
        // When
        vm.stack.push(recipient.evm.into()).unwrap();
        vm.exec_selfdestruct().expect('selfdestruct failed');
        starknet_backend::commit(ref vm.env.state).expect('commit state failed');
        vm.env.state = Default::default(); //empty state to force re-fetch from SN
        // Then
        let destructed = vm.env.state.get_account(ca_address.evm);

        assert(destructed.nonce() == 0, 'destructed nonce should be 0');
        assert(destructed.balance() == 0, 'destructed balance should be 0');
        assert(destructed.bytecode().len() == 0, 'bytecode should be empty');

        let recipient = vm.env.state.get_account(recipient.evm);
        assert_eq!(recipient.balance(), 1000);
    }

    #[test]
    #[ignore]
    fn test_selfdestruct_undeployed_ca() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 'ca_address'.try_into().unwrap();
        let ca_address: Address = Address {
            evm: evm_address, starknet: kakarot_core.compute_starknet_address(evm_address)
        };
        let recipient_address: EthAddress = 'recipient_address'.try_into().unwrap();
        deploy_eoa(recipient_address);
        let ca_balance = 1000;
        fund_account_with_native_token(ca_address.starknet, native_token, ca_balance);
        let mut vm = VMBuilderTrait::new_with_presets().with_target(ca_address).build();
        // - call `get_account` on an undeployed account, set its type to CA, its nonce to 1, its
        // code to something to mock a cached CA that has not been committed yet.
        let mut ca_account = vm.env.state.get_account(ca_address.evm);
        ca_account.set_code(array![0x1, 0x2, 0x3].span());
        ca_account.set_nonce(1);
        vm.env.state.set_account(ca_account);
        // - call selfdestruct and commit the state
        vm.stack.push(recipient_address.into()).expect('push failed');
        vm.exec_selfdestruct().expect('selfdestruct failed');
        starknet_backend::commit(ref vm.env.state).expect('commit state failed');
        vm.env.state = Default::default(); //empty state to force re-fetch from SN

        // Then
        let destructed = vm.env.state.get_account(ca_address.evm);
        assert(destructed.nonce() == 0, 'destructed nonce should be 0');
        assert(destructed.balance() == 0, 'destructed balance should be 0');
        assert(destructed.bytecode().len() == 0, 'bytecode should be empty');
        let recipient = vm.env.state.get_account(recipient_address);
        assert(recipient.balance() == ca_balance, 'wrong recipient balance');
    }

    #[test]
    #[ignore]
    fn test_exec_selfdestruct_add_transfer_post_selfdestruct() {
        // Given
        let (native_token, _) = setup_contracts_for_testing();

        // Deploy sender and recipiens EOAs, and CA that will be selfdestructed and funded with 100
        // tokens
        let sender = starknet_backend::deploy('sender'.try_into().unwrap())
            .expect('failed deploy EOA',);
        let recipient = starknet_backend::deploy('recipient'.try_into().unwrap())
            .expect('failed deploy EOA',);
        let ca_address = deploy_contract_account('contract'.try_into().unwrap(), array![].span());
        fund_account_with_native_token(sender.starknet, native_token, 150);
        fund_account_with_native_token(ca_address.starknet, native_token, 100);
        let mut vm = VMBuilderTrait::new_with_presets().with_target(ca_address).build();

        // Cache the CA into state
        vm.env.state.get_account('contract'.try_into().unwrap());

        // When
        vm.stack.push(recipient.evm.into()).unwrap();
        vm.exec_selfdestruct().expect('selfdestruct failed');
        // Add a transfer from sender to CA - after it was selfdestructed in local state. This
        // transfer should go through.
        let transfer = Transfer { sender, recipient: ca_address, amount: 150 };
        vm.env.state.add_transfer(transfer).unwrap();
        starknet_backend::commit(ref vm.env.state).expect('commit state failed');
        vm.env.state = Default::default(); //empty state to force re-fetch from SN

        // Then
        let recipient_balance = native_token.balanceOf(recipient.starknet);
        let sender_balance = native_token.balanceOf(sender.starknet);
        let ca_balance = native_token.balanceOf(ca_address.starknet);

        assert(recipient_balance == 100, 'recipient wrong balance');
        assert(sender_balance == 0, 'sender wrong balance');
        assert(ca_balance == 150, 'ca wrong balance');
    }
}
