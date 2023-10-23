use contracts::kakarot_core::interface::{IKakarotCore};
use contracts::kakarot_core::{KakarotCore};
use core::hash::{HashStateExTrait, HashStateTrait};
use evm::context::ExecutionContextTrait;
use evm::errors::{EVMError, RETURNDATA_OUT_OF_BOUNDS_ERROR, READ_SYSCALL_FAILED};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::{AccountTrait, Account, ContractAccountTrait};
use evm::stack::StackTrait;
use integer::u32_as_non_zero;
use integer::u32_overflowing_add;
use keccak::cairo_keccak;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use pedersen::{PedersenTrait, HashState};
use starknet::{Store, storage_base_address_from_felt252, ContractAddress, get_contract_address};
use utils::constants::EMPTY_KECCAK;
use utils::helpers::{load_word, U256Trait, ByteArrayExTrait};
use utils::math::BitshiftImpl;
use utils::traits::{EthAddressIntoU256};


#[generate_trait]
impl EnvironmentInformationImpl of EnvironmentInformationTrait {
    /// 0x30 - ADDRESS
    /// Get address of currently executing account.
    /// # Specification: https://www.evm.codes/#30?fork=shanghai
    fn exec_address(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(self.evm_address().into())
    }

    /// 0x31 - BALANCE opcode.
    /// Get ETH balance of the specified address.
    /// # Specification: https://www.evm.codes/#31?fork=shanghai
    fn exec_balance(ref self: Machine) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        let maybe_account = AccountTrait::account_at(evm_address)?;
        let balance: u256 = match maybe_account {
            Option::Some(acc) => acc.balance()?,
            Option::None => 0
        };

        return self.stack.push(balance);
    }

    /// 0x32 - ORIGIN
    /// Get execution origination address.
    /// # Specification: https://www.evm.codes/#32?fork=shanghai
    fn exec_origin(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(self.origin().into())
    }

    /// 0x33 - CALLER
    /// Get caller address.
    /// # Specification: https://www.evm.codes/#33?fork=shanghai
    fn exec_caller(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(self.caller().into())
    }

    /// 0x34 - CALLVALUE
    /// Get deposited value by the instruction/transaction responsible for this execution.
    /// # Specification: https://www.evm.codes/#34?fork=shanghai
    fn exec_callvalue(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(self.value())
    }

    /// 0x35 - CALLDATALOAD
    /// Push a word from the calldata onto the stack.
    /// # Specification: https://www.evm.codes/#35?fork=shanghai
    fn exec_calldataload(ref self: Machine) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;

        let calldata = self.calldata();
        let calldata_len = calldata.len();

        // All bytes after the end of the calldata are set to 0.
        if offset >= calldata_len {
            return self.stack.push(0);
        }

        // Slice the calldata
        let bytes_len = cmp::min(32, calldata_len - offset);
        let sliced = calldata.slice(offset, bytes_len);

        // Fill data to load with bytes in calldata
        let mut data_to_load: u256 = load_word(bytes_len, sliced);

        // Fill the rest of the data to load with zeros
        // TODO: optimize once we have dw-based exponentiation
        let mut i = 32 - bytes_len;
        loop {
            if i == 0 {
                break;
            }
            data_to_load *= 256;
            i -= 1;
        };

        self.stack.push(data_to_load)
    }

    /// 0x36 - CALLDATASIZE
    /// Get the size of return data.
    /// # Specification: https://www.evm.codes/#36?fork=shanghai
    fn exec_calldatasize(ref self: Machine) -> Result<(), EVMError> {
        let size: u256 = self.calldata().len().into();
        self.stack.push(size)
    }

    /// 0x37 - CALLDATACOPY operation
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#37?fork=shanghai
    fn exec_calldatacopy(ref self: Machine) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let calldata: Span<u8> = self.calldata();

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
    fn exec_codesize(ref self: Machine) -> Result<(), EVMError> {
        let size: u256 = self.bytecode().len().into();
        self.stack.push(size)
    }

    /// 0x39 - CODECOPY
    /// Copies slice of bytecode to memory.
    /// # Specification: https://www.evm.codes/#39?fork=shanghai
    fn exec_codecopy(ref self: Machine) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let bytecode: Span<u8> = self.bytecode();

        let copied: Span<u8> = if offset > bytecode.len() {
            array![].span()
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
    fn exec_gasprice(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(self.gas_price().into())
    }

    /// 0x3B - EXTCODESIZE
    /// Get size of an account's code.
    /// # Specification: https://www.evm.codes/#3b?fork=shanghai
    fn exec_extcodesize(ref self: Machine) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x3C - EXTCODECOPY
    /// Copy an account's code to memory
    /// # Specification: https://www.evm.codes/#3c?fork=shanghai
    fn exec_extcodecopy(ref self: Machine) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x3D - RETURNDATASIZE
    /// Get the size of return data.
    /// # Specification: https://www.evm.codes/#3d?fork=shanghai
    fn exec_returndatasize(ref self: Machine) -> Result<(), EVMError> {
        let size = self.return_data().len();
        self.stack.push(size.into())
    }

    /// 0x3E - RETURNDATACOPY
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#3e?fork=shanghai
    fn exec_returndatacopy(ref self: Machine) -> Result<(), EVMError> {
        let dest_offset = self.stack.pop_usize()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let return_data: Span<u8> = self.return_data();

        match u32_overflowing_add(offset, size) {
            Result::Ok(x) => {
                if (x > return_data.len()) {
                    return Result::Err(EVMError::ReturnDataError(RETURNDATA_OUT_OF_BOUNDS_ERROR));
                }
            },
            Result::Err(x) => {
                return Result::Err(EVMError::ReturnDataError(RETURNDATA_OUT_OF_BOUNDS_ERROR));
            }
        }

        let data_to_copy: Span<u8> = return_data.slice(offset, size);
        self.memory.store_n(data_to_copy, dest_offset);

        Result::Ok(())
    }

    /// 0x3F - EXTCODEHASH
    /// Get hash of a contract's code.
    // If the account has no code (or is a precompile), return the empty hash:
    // `0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`
    // If the account does not exist of was destroyed (SELFDESTRUCT), return 0
    // Else return, the hash of the account's code
    /// # Specification: https://www.evm.codes/#3f?fork=shanghai
    fn exec_extcodehash(ref self: Machine) -> Result<(), EVMError> {
        let evm_address = self.stack.pop_eth_address()?;

        let maybe_account = AccountTrait::account_at(evm_address)?;
        let account = match maybe_account {
            Option::Some(account) => account,
            // Case 1: The address corresponds to a non-existing or destroyed contract account.
            Option::None => { return self.stack.push(0); },
        };

        match account {
            Account::EOA(eoa) => {
                // Case 2: The address corresponds to a EOA. If so, the account exists but has no code.
                // We return the empty hash.
                return self.stack.push(EMPTY_KECCAK);
            },
            Account::ContractAccount(ca) => {
                let mut bytecode = ca.load_bytecode()?;
                // If the bytecode is empty, return the empty keccak hash.
                if bytecode.is_empty() {
                    return self.stack.push(EMPTY_KECCAK);
                }
                // Else hash the bytecode and push the hash on the stack
                // Since bytecode is a ByteArray, we need to perform a couple of transformations.
                // `cairo_keccak` takes in an array of little-endian u64s
                let (mut keccak_input, last_input_word, last_input_num_bytes) = bytecode
                    .to_u64_words();
                let hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes);
                self.stack.push(hash.reverse_endianness())
            }
        }
    }
}
