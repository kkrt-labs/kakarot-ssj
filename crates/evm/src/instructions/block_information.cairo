//! Block Information.

use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::starknet::SyscallResultTrait;

use evm::errors::{
    EVMError, BLOCK_HASH_SYSCALL_FAILED, EXECUTION_INFO_SYSCALL_FAILED, TYPE_CONVERSION_ERROR
};

use evm::gas;
use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Account};
use evm::stack::StackTrait;
use evm::state::StateTrait;

// Corelib imports
use starknet::info::get_block_number;
use starknet::{get_block_hash_syscall, EthAddress};

use utils::helpers::ResultExTrait;
use utils::traits::{EthAddressTryIntoResultContractAddress, EthAddressIntoU256};

#[generate_trait]
impl BlockInformation of BlockInformationTrait {
    /// 0x40 - BLOCKHASH
    /// Get the hash of one of the 256 most recent complete blocks.
    /// # Specification: https://www.evm.codes/#40?fork=shanghai
    fn exec_blockhash(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BLOCKHASH)?;

        let block_number = self.stack.pop_u64()?;
        let current_block = self.env.block_number;

        // If input block number is lower than current_block - 256, return 0
        // If input block number is higher than current_block - 10, return 0
        // Note: in the specs, input block number can be equal - at most - to the current block number minus one.
        // In Starknet, the `get_block_hash_syscall` is capped at current block minus ten.
        // TODO: monitor the changes in the `get_block_hash_syscall` syscall.
        // source: https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/system-calls-cairo1/#get_block_hash
        if block_number + 10 > current_block || block_number + 256 < current_block {
            return self.stack.push(0);
        }

        self.stack.push(get_block_hash_syscall(block_number).unwrap_syscall().into())
    }

    /// 0x41 - COINBASE
    /// Get the block's beneficiary address.
    /// # Specification: https://www.evm.codes/#41?fork=shanghai
    fn exec_coinbase(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let coinbase = self.env.coinbase;
        self.stack.push(coinbase.into())
    }

    /// 0x42 - TIMESTAMP
    /// Get the block’s timestamp
    /// # Specification: https://www.evm.codes/#42?fork=shanghai
    fn exec_timestamp(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_timestamp.into())
    }

    /// 0x43 - NUMBER
    /// Get the block number.
    /// # Specification: https://www.evm.codes/#43?fork=shanghai
    fn exec_number(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_number.into())
    }

    /// 0x44 - PREVRANDAO
    /// # Specification: https://www.evm.codes/#44?fork=shanghai
    fn exec_prevrandao(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        // PREVRANDAO does not exist in Starknet
        // PREVRANDAO used to be DIFFICULTY, which returns 0 for non-POW chains
        self.stack.push(0x00)
    }

    /// 0x45 - GASLIMIT
    /// Get the block’s gas limit
    /// # Specification: https://www.evm.codes/#45?fork=shanghai
    fn exec_gaslimit(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_gas_limit.into())
    }

    /// 0x46 - CHAINID
    /// Get the chain ID.
    /// # Specification: https://www.evm.codes/#46?fork=shanghai
    fn exec_chainid(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let chain_id = self.env.chain_id;
        self.stack.push(chain_id.into())
    }

    /// 0x47 - SELFBALANCE
    /// Get balance of currently executing contract
    /// # Specification: https://www.evm.codes/#47?fork=shanghai
    fn exec_selfbalance(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;

        let evm_address = self.message().target.evm;

        let balance = self.env.state.get_account(evm_address).balance;

        self.stack.push(balance)
    }

    /// 0x48 - BASEFEE
    /// Get base fee.
    /// # Specification: https://www.evm.codes/#48?fork=shanghai
    fn exec_basefee(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        // Get the current base fee. (Kakarot doesn't use EIP 1559 so basefee
        //  doesn't really exists there so we just use the gas price)
        self.stack.push(self.env.gas_price.into())
    }
}
