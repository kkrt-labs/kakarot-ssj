//! Block Information.

// Corelib imports
use starknet::info::{get_block_number, get_block_timestamp};

// Internal imports
use evm::stack::StackTrait;
use evm::errors::EVMError;
use utils::constants::CHAIN_ID;
use evm::machine::{Machine, MachineCurrentContext};

#[generate_trait]
impl BlockInformation of BlockInformationTrait {
    /// 0x40 - BLOCKHASH
    /// Get the hash of one of the 256 most recent complete blocks.
    /// # Specification: https://www.evm.codes/#40?fork=shanghai
    fn exec_blockhash(ref self: Machine) -> Result<(), EVMError> {
        Result::Err(EVMError::NotImplemented)
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
        Result::Err(EVMError::NotImplemented)
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
