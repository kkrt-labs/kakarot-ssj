use evm::balance::balance;
//! Block Information.

use evm::errors::{EVMError, BLOCK_HASH_SYSCALL_FAILED};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::stack::StackTrait;

// Corelib imports
use starknet::info::{get_block_number, get_block_timestamp, get_block_info};
use starknet::{get_block_hash_syscall};
use utils::constants::CHAIN_ID;

#[generate_trait]
impl BlockInformation of BlockInformationTrait {
    /// 0x40 - BLOCKHASH
    /// Get the hash of one of the 256 most recent complete blocks.
    /// # Specification: https://www.evm.codes/#40?fork=shanghai
    fn exec_blockhash(ref self: Machine) -> Result<(), EVMError> {
        let block_number = self.stack.pop_u64()?;
        let current_block = get_block_number();

        // If input block number is lower than current_block - 256, return 0
        // If input block number is higher than current_block - 10, return 0
        // Note: in the specs, input block number can be equal - at most - to the current block number minus one.
        // In Starknet, the `get_block_hash_syscall` is capped at current block minus ten.
        // TODO: monitor the changes in the `get_block_hash_syscall` syscall.
        // source: https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/system-calls-cairo1/#get_block_hash
        if block_number + 10 > current_block || block_number + 256 < current_block {
            return self.stack.push(0);
        }

        let maybe_block_hash = get_block_hash_syscall(block_number);
        match maybe_block_hash {
            Result::Ok(block_hash) => self.stack.push(block_hash.into()),
            // This syscall should not error out, as we made sure block_number =< current_block - 10
            // In case of failed syscall, we can either return 0, or revert.
            // Since this situation would be highly breaking, we choose to revert.
            Result::Err(_) => Result::Err(EVMError::SyscallFailed(BLOCK_HASH_SYSCALL_FAILED)),
        }
    }

    /// 0x41 - COINBASE
    /// Get the block's beneficiary address.
    /// # Specification: https://www.evm.codes/#41?fork=shanghai
    fn exec_coinbase(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// 0x42 - TIMESTAMP
    /// Get the block’s timestamp
    /// # Specification: https://www.evm.codes/#42?fork=shanghai
    fn exec_timestamp(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(get_block_timestamp().into())
    }

    /// 0x43 - NUMBER
    /// Get the block number.
    /// # Specification: https://www.evm.codes/#43?fork=shanghai
    fn exec_number(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(get_block_number().into())
    }

    /// 0x44 - PREVRANDAO
    /// # Specification: https://www.evm.codes/#44?fork=shanghai
    fn exec_prevrandao(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
    }

    /// 0x45 - GASLIMIT
    /// Get gas limit
    /// # Specification: https://www.evm.codes/#45?fork=shanghai
    fn exec_gaslimit(ref self: Machine) -> Result<(), EVMError> {
        self.stack.push(self.gas_limit().into())
    }

    /// 0x46 - CHAINID
    /// Get the chain ID.
    /// # Specification: https://www.evm.codes/#46?fork=shanghai
    fn exec_chainid(ref self: Machine) -> Result<(), EVMError> {
        // CHAIN_ID = KKRT (0x4b4b5254) in ASCII
        // TODO: Replace the hardcoded value by a value set in kakarot main contract constructor
        // Push the chain ID to stack
        self.stack.push(CHAIN_ID)
    }

    /// 0x47 - SELFBALANCE
    /// Get balance of currently executing contract
    /// # Specification: https://www.evm.codes/#47?fork=shanghai
    fn exec_selfbalance(ref self: Machine) -> Result<(), EVMError> {
        let evm_address = self.evm_address();

        let balance = balance(evm_address);

        self.stack.push(balance)
    }

    /// 0x48 - BASEFEE
    /// Get base fee.
    /// # Specification: https://www.evm.codes/#48?fork=shanghai
    fn exec_basefee(ref self: Machine) -> Result<(), EVMError> {
        // Get the current base fee. (Kakarot doesn't use EIP 1559 so basefee
        //  doesn't really exists there so we just use the gas price)
        self.stack.push(self.gas_price().into())
    }
}
