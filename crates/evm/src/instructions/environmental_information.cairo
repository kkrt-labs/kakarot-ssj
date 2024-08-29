use contracts::kakarot_core::interface::{IKakarotCore};
use contracts::kakarot_core::{KakarotCore};
use core::hash::{HashStateExTrait, HashStateTrait};
use core::keccak::cairo_keccak;
use core::num::traits::OverflowingAdd;
use core::num::traits::Zero;
use core::pedersen::{PedersenTrait, HashState};
use core::starknet::{
    Store, storage_base_address_from_felt252, ContractAddress, get_contract_address
};
use evm::errors::{ensure, EVMError, READ_SYSCALL_FAILED};
use evm::gas;
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{AddressTrait};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::constants::EMPTY_KECCAK;
use utils::helpers::ResultExTrait;
use utils::helpers::{ceil32, load_word, U256Trait, U8SpanExTrait};
use utils::math::BitshiftImpl;
use utils::set::SetTrait;
use utils::traits::{EthAddressIntoU256};


#[generate_trait]
impl EnvironmentInformationImpl of EnvironmentInformationTrait {
    /// 0x30 - ADDRESS
    /// Get address of currently executing account.
    /// # Specification: https://www.evm.codes/#30?fork=shanghai
    fn exec_address(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.message().target.evm.into())
    }

    /// 0x31 - BALANCE opcode.
    /// Get ETH balance of the specified address.
    /// # Specification: https://www.evm.codes/#31?fork=shanghai
    fn exec_balance(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        // GAS
        if self.accessed_addresses.contains(evm_address) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_addresses.add(evm_address);
            self.charge_gas(gas::COLD_ACCOUNT_ACCESS_COST)?
        }

        let balance = self.env.state.get_account(evm_address).balance();
        self.stack.push(balance)
    }

    /// 0x32 - ORIGIN
    /// Get execution origination address.
    /// # Specification: https://www.evm.codes/#32?fork=shanghai
    fn exec_origin(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.env.origin.into())
    }

    /// 0x33 - CALLER
    /// Get caller address.
    /// # Specification: https://www.evm.codes/#33?fork=shanghai
    fn exec_caller(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.message().caller.evm.into())
    }

    /// 0x34 - CALLVALUE
    /// Get deposited value by the instruction/transaction responsible for this execution.
    /// # Specification: https://www.evm.codes/#34?fork=shanghai
    fn exec_callvalue(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.message().value)
    }

    /// 0x35 - CALLDATALOAD
    /// Push a word from the calldata onto the stack.
    /// # Specification: https://www.evm.codes/#35?fork=shanghai
    fn exec_calldataload(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::VERYLOW)?;

        let offset: usize = self.stack.pop_usize()?;

        let calldata = self.message().data;
        let calldata_len = calldata.len();

        // All bytes after the end of the calldata are set to 0.
        if offset >= calldata_len {
            return self.stack.push(0);
        }

        // Slice the calldata
        let bytes_len = core::cmp::min(32, calldata_len - offset);
        let sliced = calldata.slice(offset, bytes_len);

        // Fill data to load with bytes in calldata
        let mut data_to_load: u256 = load_word(bytes_len, sliced);

        // Fill the rest of the data to load with zeros
        // TODO: optimize once we have dw-based exponentiation
        let mut i = 32 - bytes_len;
        while i != 0 {
            data_to_load *= 256;
            i -= 1;
        };
        self.stack.push(data_to_load)
    }

    /// 0x36 - CALLDATASIZE
    /// Get the size of return data.
    /// # Specification: https://www.evm.codes/#36?fork=shanghai
    fn exec_calldatasize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        let size: u256 = self.message().data.len().into();
        self.stack.push(size)
    }

    /// 0x37 - CALLDATACOPY operation
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#37?fork=shanghai
    fn exec_calldatacopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let words_size: u128 = (ceil32(size) / 32).into();
        let copy_gas_cost = gas::COPY * words_size;
        let memory_expansion = gas::memory_expansion(self.memory.size(), dest_offset + size);
        self.charge_gas(gas::VERYLOW + copy_gas_cost + memory_expansion.expansion_cost)?;

        let calldata: Span<u8> = self.message().data;

        let copied: Span<u8> = if (offset + size > calldata.len()) {
            calldata.slice(offset, calldata.len() - offset)
        } else {
            calldata.slice(offset, size)
        };

        self.memory.store_padded_segment(dest_offset, size, copied);

        Result::Ok(())
    }

    /// 0x38 - CODESIZE
    /// Get size of bytecode running in current environment.
    /// # Specification: https://www.evm.codes/#38?fork=shanghai
    fn exec_codesize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        let size: u256 = self.message().code.len().into();
        self.stack.push(size)
    }

    /// 0x39 - CODECOPY
    /// Copies slice of bytecode to memory.
    /// # Specification: https://www.evm.codes/#39?fork=shanghai
    fn exec_codecopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let words_size: u128 = (ceil32(size) / 32).into();
        let copy_gas_cost = gas::COPY * words_size;
        let memory_expansion = gas::memory_expansion(self.memory.size(), dest_offset + size);
        self.charge_gas(gas::VERYLOW + copy_gas_cost + memory_expansion.expansion_cost)?;

        let bytecode: Span<u8> = self.message().code;

        let copied: Span<u8> = if offset > bytecode.len() {
            [].span()
        } else if (offset + size > bytecode.len()) {
            bytecode.slice(offset, bytecode.len() - offset)
        } else {
            bytecode.slice(offset, size)
        };

        self.memory.store_padded_segment(dest_offset, size, copied);

        Result::Ok(())
    }

    /// 0x3A - GASPRICE
    /// Get price of gas in current environment.
    /// # Specification: https://www.evm.codes/#3a?fork=shanghai
    fn exec_gasprice(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push(self.env.gas_price.into())
    }

    /// 0x3B - EXTCODESIZE
    /// Get size of an account's code.
    /// # Specification: https://www.evm.codes/#3b?fork=shanghai
    fn exec_extcodesize(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        // GAS
        if self.accessed_addresses.contains(evm_address) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_addresses.add(evm_address);
            self.charge_gas(gas::COLD_ACCOUNT_ACCESS_COST)?
        }

        let account = self.env.state.get_account(evm_address);
        self.stack.push(account.code.len().into())
    }

    /// 0x3C - EXTCODECOPY
    /// Copy an account's code to memory
    /// # Specification: https://www.evm.codes/#3c?fork=shanghai
    fn exec_extcodecopy(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        // GAS
        let words_size: u128 = (ceil32(size) / 32).into();
        let memory_expansion = gas::memory_expansion(self.memory.size(), dest_offset + size);
        let copy_gas_cost = gas::COPY * words_size;
        let access_gas_cost = if self.accessed_addresses.contains(evm_address) {
            gas::WARM_ACCESS_COST
        } else {
            self.accessed_addresses.add(evm_address);
            gas::COLD_ACCOUNT_ACCESS_COST
        };
        self.charge_gas(access_gas_cost + copy_gas_cost + memory_expansion.expansion_cost)?;

        let bytecode = self.env.state.get_account(evm_address).code;
        let bytecode_len = bytecode.len();
        let bytecode_slice = if offset < bytecode_len {
            bytecode.slice(offset, bytecode_len - offset)
        } else {
            [].span()
        };
        self.memory.store_padded_segment(dest_offset, size, bytecode_slice);
        Result::Ok(())
    }

    /// 0x3D - RETURNDATASIZE
    /// Get the size of return data.
    /// # Specification: https://www.evm.codes/#3d?fork=shanghai
    fn exec_returndatasize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        let size = self.return_data().len();
        self.stack.push(size.into())
    }

    /// 0x3E - RETURNDATACOPY
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#3e?fork=shanghai
    fn exec_returndatacopy(ref self: VM) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;
        let return_data: Span<u8> = self.return_data();

        let (last_returndata_index, overflow) = offset.overflowing_add(size);
        if overflow {
            return Result::Err(EVMError::ReturnDataOutOfBounds);
        }
        ensure(!(last_returndata_index > return_data.len()), EVMError::ReturnDataOutOfBounds)?;

        //TODO: handle overflow in ceil32 function.
        let words_size: u128 = (ceil32(size.into()) / 32).into();
        let copy_gas_cost = gas::COPY * words_size;

        let (max_memory_size, overflow) = dest_offset.overflowing_add(size);
        if overflow {
            return Result::Err(EVMError::OutOfGas);
        }

        let memory_expansion = gas::memory_expansion(self.memory.size(), max_memory_size);
        self.charge_gas(gas::VERYLOW + copy_gas_cost + memory_expansion.expansion_cost)?;

        let data_to_copy: Span<u8> = return_data.slice(offset, size);
        self.memory.store_n(data_to_copy, dest_offset);

        Result::Ok(())
    }

    /// 0x3F - EXTCODEHASH
    /// Get hash of a contract's code.
    // If the account has no code, return the empty hash:
    // `0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`
    // If the account does not exist, is a precompile or was destroyed (SELFDESTRUCT), return 0
    // Else return, the hash of the account's code
    /// # Specification: https://www.evm.codes/#3f?fork=shanghai
    fn exec_extcodehash(ref self: VM) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        // GAS
        if self.accessed_addresses.contains(evm_address) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_addresses.add(evm_address);
            self.charge_gas(gas::COLD_ACCOUNT_ACCESS_COST)?
        }

        let account = self.env.state.get_account(evm_address);
        // Relevant cases:
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/instructions.go#L392
        if account.evm_address().is_precompile()
            || (!account.has_code_or_nonce() && account.balance.is_zero()) {
            return self.stack.push(0);
        }
        let bytecode = account.code;

        if bytecode.is_empty() {
            return self.stack.push(EMPTY_KECCAK);
        }

        // `cairo_keccak` takes in an array of little-endian u64s
        let hash = bytecode.compute_keccak256_hash();
        self.stack.push(hash)
    }
}


#[cfg(test)]
mod tests {
    use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore};
    use contracts::test_data::counter_evm_bytecode;
    use core::num::traits::CheckedAdd;
    use core::starknet::EthAddress;

    use core::starknet::testing::set_contract_address;
    use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
    use evm::instructions::EnvironmentInformationTrait;
    use evm::memory::{InternalMemoryTrait, MemoryTrait};

    use evm::model::vm::{VM, VMTrait};
    use evm::model::{Account, Address};
    use evm::stack::StackTrait;
    use evm::state::StateTrait;
    use evm::test_utils::{
        VMBuilderTrait, evm_address, origin, callvalue, native_token, other_address, gas_price,
        tx_gas_limit, register_account
    };
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
    use snforge_std::{test_address, start_mock_call};
    use utils::helpers::{u256_to_bytes_array, ArrayExtTrait, compute_starknet_address};
    use utils::traits::{EthAddressIntoU256};

    const EMPTY_KECCAK: u256 = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    // *************************************************************************
    // 0x30: ADDRESS
    // *************************************************************************

    #[test]
    fn test_address_basic() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_address().expect('exec_address failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop_eth_address().unwrap(), vm.message().target.evm.into());
    }

    // *************************************************************************
    // 0x31: BALANCE
    // *************************************************************************
    #[test]
    fn test_exec_balance_eoa() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 400,
            nonce: 0,
            code: [].span(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(vm.message.target.evm.into()).unwrap();

        // When
        vm.exec_balance().expect('exec_balance failed');

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 400);
    }

    // *************************************************************************
    // 0x33: CALLER
    // *************************************************************************
    #[test]
    fn test_caller() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_caller().expect('exec_caller failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), origin().into());
    }


    // *************************************************************************
    // 0x32: ORIGIN
    // *************************************************************************
    #[test]
    fn test_origin_nested_ctx() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_origin().expect('exec_origin failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), origin().into());
    }


    // *************************************************************************
    // 0x34: CALLVALUE
    // *************************************************************************
    #[test]
    fn test_exec_callvalue() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_callvalue().expect('exec_callvalue failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop().unwrap(), callvalue());
    }

    // *************************************************************************
    // 0x35: CALLDATALOAD
    // *************************************************************************

    #[test]
    fn test_calldataload() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = 0;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();
        assert_eq!(result, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    #[test]
    fn test_calldataload_with_offset() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );

        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = 31;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();

        assert_eq!(result, 0xFF00000000000000000000000000000000000000000000000000000000000000);
    }

    #[test]
    fn test_calldataload_with_offset_beyond_calldata() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = calldata.len() + 1;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();
        assert_eq!(result, 0);
    }

    #[test]
    fn test_calldataload_with_function_selector() {
        // Given
        let calldata = array![0x6d, 0x4c, 0xe6, 0x3c];
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();

        let offset: u32 = 0;
        vm.stack.push(offset.into()).expect('push failed');

        // When
        vm.exec_calldataload().expect('exec_calldataload failed');

        // Then
        let result: u256 = vm.stack.pop().unwrap();
        assert_eq!(result, 0x6d4ce63c00000000000000000000000000000000000000000000000000000000);
    }


    #[test]
    fn test_calldataload_with_offset_conversion_error() {
        // Given
        let calldata = u256_to_bytes_array(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        );
        let mut vm = VMBuilderTrait::new_with_presets().with_calldata(calldata.span()).build();
        let offset: u256 = 5000000000;
        vm.stack.push(offset).expect('push failed');

        // When
        let result = vm.exec_calldataload();

        // Then
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    // *************************************************************************
    // 0x36: CALLDATASIZE
    // *************************************************************************

    #[test]
    fn test_calldata_size() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let calldata: Span<u8> = vm.message.data;

        // When
        vm.exec_calldatasize().expect('exec_calldatasize failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), calldata.len().into());
    }

    // *************************************************************************
    // 0x37: CALLDATACOPY
    // *************************************************************************

    #[test]
    fn test_calldatacopy_type_conversion_error() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');

        // When
        let res = vm.exec_calldatacopy();

        // Then
        assert!(res.is_err());
        assert_eq!(res.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    #[test]
    fn test_calldatacopy_basic() {
        test_calldatacopy(32, 0, 3, [4, 5, 6].span());
    }

    #[test]
    fn test_calldatacopy_with_offset() {
        test_calldatacopy(32, 2, 1, [6].span());
    }

    #[test]
    fn test_calldatacopy_with_out_of_bound_bytes() {
        // For out of bound bytes, 0s will be copied.
        let mut expected = array![4, 5, 6];
        expected.append_n(0, 5);

        test_calldatacopy(32, 0, 8, expected.span());
    }

    #[test]
    fn test_calldatacopy_with_out_of_bound_bytes_multiple_words() {
        // For out of bound bytes, 0s will be copied.
        let mut expected = array![4, 5, 6];
        expected.append_n(0, 31);

        test_calldatacopy(32, 0, 34, expected.span());
    }

    fn test_calldatacopy(dest_offset: u32, offset: u32, mut size: u32, expected: Span<u8>) {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let _calldata: Span<u8> = vm.message.data;

        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        // Memory initialization with a value to verify that if the offset + size is out of the
        // bound bytes, 0's have been copied.
        // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
        let mut i = 0;
        while i != (size / 32) + 1 {
            vm
                .memory
                .store(
                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                    dest_offset + (i * 32)
                );

            let initial: u256 = vm.memory.load_internal(dest_offset + (i * 32)).into();

            assert_eq!(initial, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

            i += 1;
        };

        // When
        vm.exec_calldatacopy().expect('exec_calldatacopy failed');

        // Then
        assert!(vm.stack.is_empty());

        let mut results: Array<u8> = ArrayTrait::new();
        vm.memory.load_n_internal(size, ref results, dest_offset);

        assert_eq!(results.span(), expected);
    }

    // *************************************************************************
    // 0x38: CODESIZE
    // *************************************************************************

    #[test]
    fn test_codesize() {
        // Given
        let bytecode: Span<u8> = [1, 2, 3, 4, 5].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        // When
        vm.exec_codesize().expect('exec_codesize failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop().unwrap(), bytecode.len().into());
    }

    // *************************************************************************
    // 0x39: CODECOPY
    // *************************************************************************

    #[test]
    fn test_codecopy_type_conversion_error() {
        // Given
        let bytecode: Span<u8> = [1, 2, 3, 4, 5].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');

        // When
        let res = vm.exec_codecopy();

        // Then
        assert!(res.is_err());
        assert_eq!(res.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    #[test]
    fn test_codecopy_basic() {
        test_codecopy(32, 0, 0);
    }

    #[test]
    fn test_codecopy_with_offset() {
        test_codecopy(32, 2, 0);
    }

    #[test]
    fn test_codecopy_with_out_of_bound_bytes() {
        test_codecopy(32, 0, 8);
    }

    #[test]
    fn test_codecopy_with_out_of_bound_offset() {
        test_codecopy(0, 0xFFFFFFFE, 2);
    }

    fn test_codecopy(dest_offset: u32, offset: u32, mut size: u32) {
        // Given
        let bytecode: Span<u8> = [1, 2, 3, 4, 5].span();

        let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

        if (size == 0) {
            size = bytecode.len() - offset;
        }

        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        vm
            .memory
            .store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, dest_offset);
        let initial: u256 = vm.memory.load_internal(dest_offset).into();
        assert_eq!(initial, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        // When
        vm.exec_codecopy().expect('exec_codecopy failed');

        // Then
        assert!(vm.stack.is_empty());

        let result: u256 = vm.memory.load_internal(dest_offset).into();
        let mut results: Array<u8> = u256_to_bytes_array(result);

        let mut i = 0;
        while i != size {
            // For out of bound bytes, 0s will be copied.
            if (i + offset >= bytecode.len()) {
                assert_eq!(*results[i], 0);
            } else {
                assert_eq!(*results[i], *bytecode[i + offset]);
            }

            i += 1;
        };
    }

    // *************************************************************************
    // 0x3A: GASPRICE
    // *************************************************************************

    #[test]
    fn test_gasprice() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_gasprice().expect('exec_gasprice failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.peek().unwrap(), gas_price().into());
    }

    // *************************************************************************
    // 0x3B - EXTCODESIZE
    // *************************************************************************
    #[test]
    fn test_exec_extcodesize_should_push_bytecode_len_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: [].span(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodesize().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_exec_extcodesize_should_push_bytecode_len() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target, balance: 1, nonce: 1, code: [
                0xff
            ; 350].span(), selfdestruct: false, is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodesize().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 350);
    }

    #[test]
    fn test_exec_extcodecopy_should_copy_bytecode_slice() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: counter_evm_bytecode(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);

        vm.stack.push(account.address.evm.into()).expect('push failed');
        // size
        vm.stack.push(50).expect('push failed');
        // offset
        vm.stack.push(200).expect('push failed');
        // destOffset (memory offset)
        vm.stack.push(20).expect('push failed');
        vm.stack.push(account.address.evm.into()).unwrap();

        // When
        vm.exec_extcodecopy().unwrap();

        // Then
        let mut bytecode_slice = array![];
        vm.memory.load_n(50, ref bytecode_slice, 20);
        assert_eq!(bytecode_slice.span(), counter_evm_bytecode().slice(200, 50));
    }

    // *************************************************************************
    // 0x3C - EXTCODECOPY
    // *************************************************************************
    #[test]
    fn test_exec_extcodecopy_ca_offset_out_of_bounds_should_return_zeroes() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: counter_evm_bytecode(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // size
        vm.stack.push(5).expect('push failed');
        // offset
        vm.stack.push(5000).expect('push failed');
        // destOffset
        vm.stack.push(20).expect('push failed');
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodecopy().unwrap();

        // Then
        let mut bytecode_slice = array![];
        vm.memory.load_n(5, ref bytecode_slice, 20);
        assert_eq!(bytecode_slice.span(), [0, 0, 0, 0, 0].span());
    }

    #[test]
    fn test_exec_returndatasize() {
        // Given
        let return_data: Array<u8> = array![1, 2, 3, 4, 5];
        let size = return_data.len();

        let mut vm = VMBuilderTrait::new_with_presets()
            .with_return_data(return_data.span())
            .build();

        vm.exec_returndatasize().expect('exec_returndatasize failed');

        // Then
        assert_eq!(vm.stack.len(), 1);
        assert_eq!(vm.stack.pop().unwrap(), size.into());
    }

    // *************************************************************************
    // 0x3E: RETURNDATACOPY
    // *************************************************************************

    #[test]
    fn test_returndata_copy_type_conversion_error() {
        // Given
        let return_data: Array<u8> = array![1, 2, 3, 4, 5];
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_return_data(return_data.span())
            .build();

        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');
        vm
            .stack
            .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            .expect('push failed');

        // When
        let res = vm.exec_returndatacopy();

        // Then
        assert_eq!(res.unwrap_err(), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
    }

    #[test]
    fn test_returndata_copy_overflowing_add_error() {
        test_returndata_copy(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
    }

    #[test]
    fn test_returndata_copy_basic() {
        test_returndata_copy(32, 0, 0);
    }

    #[test]
    fn test_returndata_copy_with_offset() {
        test_returndata_copy(32, 2, 0);
    }

    #[test]
    fn test_returndata_copy_with_out_of_bound_bytes() {
        test_returndata_copy(32, 30, 10);
    }

    #[test]
    fn test_returndata_copy_with_multiple_words() {
        test_returndata_copy(32, 0, 33);
    }

    fn test_returndata_copy(dest_offset: u32, offset: u32, mut size: u32) {
        // Given
        // Set the return data of the current context
        let return_data = array![
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            19,
            20,
            21,
            22,
            23,
            24,
            25,
            26,
            27,
            28,
            29,
            30,
            31,
            32,
            33,
            34,
            35,
            36
        ];
        let mut vm = VMBuilderTrait::new_with_presets()
            .with_return_data(return_data.span())
            .build();

        if (size == 0) {
            size = return_data.len() - offset;
        }

        vm.stack.push(size.into()).expect('push failed');
        vm.stack.push(offset.into()).expect('push failed');
        vm.stack.push(dest_offset.into()).expect('push failed');

        // When
        let res = vm.exec_returndatacopy();

        // Then
        assert!(vm.stack.is_empty());

        match offset.checked_add(size) {
            Option::Some(x) => {
                if (x > return_data.len()) {
                    assert_eq!(res.unwrap_err(), EVMError::ReturnDataOutOfBounds);
                    return;
                }
            },
            Option::None => {
                assert_eq!(res.unwrap_err(), EVMError::ReturnDataOutOfBounds);
                return;
            }
        }

        let _result: u256 = vm.memory.load_internal(dest_offset).into();
        let mut results: Array<u8> = ArrayTrait::new();

        let mut i = 0;
        while i != (size / 32) + 1 {
            let result: u256 = vm.memory.load_internal(dest_offset + (i * 32)).into();
            let result_span = u256_to_bytes_array(result).span();

            if ((i + 1) * 32 > size) {
                ArrayExtTrait::concat(ref results, result_span.slice(0, size - (i * 32)));
            } else {
                ArrayExtTrait::concat(ref results, result_span);
            }

            i += 1;
        };
        assert_eq!(results.span(), return_data.span().slice(offset, size));
    }

    // *************************************************************************
    // 0x3F: EXTCODEHASH
    // *************************************************************************
    #[test]
    fn test_exec_extcodehash_precompile() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let precompile_evm_address: EthAddress = evm::model::LAST_ETHEREUM_PRECOMPILE_ADDRESS
            .try_into()
            .unwrap();
        let precompile_starknet_address = compute_starknet_address(
            test_address(), precompile_evm_address, 0.try_into().unwrap()
        );
        let account = Account {
            address: Address {
                evm: precompile_evm_address, starknet: precompile_starknet_address,
            },
            balance: 1,
            nonce: 0,
            code: [].span(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(precompile_evm_address.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_exec_extcodehash_empty_account() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 0,
            nonce: 0,
            code: [].span(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), 0);
    }

    #[test]
    fn test_exec_extcodehash_no_bytecode() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: [].span(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(vm.stack.peek().unwrap(), EMPTY_KECCAK);
    }

    #[test]
    fn test_exec_extcodehash_with_bytecode() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let account = Account {
            address: vm.message().target,
            balance: 1,
            nonce: 1,
            code: counter_evm_bytecode(),
            selfdestruct: false,
            is_created: true,
        };
        vm.env.state.set_account(account);
        vm.stack.push(account.address.evm.into()).expect('push failed');

        // When
        vm.exec_extcodehash().unwrap();

        // Then
        assert_eq!(
            vm.stack.peek() // extcodehash(Counter.sol) :=
            // 0x82abf19c13d2262cc530f54956af7e4ec1f45f637238ed35ed7400a3409fd275 (source:
            // remix)
            // <https://emn178.github.io/online-tools/keccak_256.html?input=608060405234801561000f575f80fd5b506004361061004a575f3560e01c806306661abd1461004e578063371303c01461006c5780636d4ce63c14610076578063b3bcfa8214610094575b5f80fd5b61005661009e565b60405161006391906100f7565b60405180910390f35b6100746100a3565b005b61007e6100bd565b60405161008b91906100f7565b60405180910390f35b61009c6100c5565b005b5f5481565b60015f808282546100b4919061013d565b92505081905550565b5f8054905090565b60015f808282546100d69190610170565b92505081905550565b5f819050919050565b6100f1816100df565b82525050565b5f60208201905061010a5f8301846100e8565b92915050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f610147826100df565b9150610152836100df565b925082820190508082111561016a57610169610110565b5b92915050565b5f61017a826100df565b9150610185836100df565b925082820390508181111561019d5761019c610110565b5b9291505056fea26469706673582212207e792fcff28a4bf0bad8675c5bc2288b07835aebaa90b8dc5e0df19183fb72cf64736f6c63430008160033&input_type=hex>
            .unwrap(),
            0xec976f44607e73ea88910411e3da156757b63bea5547b169e1e0d733443f73b0,
        );
    }
}
