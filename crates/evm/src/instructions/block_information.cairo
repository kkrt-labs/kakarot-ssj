//! Block Information.

// Corelib imports
use starknet::syscalls::get_execution_info_syscall;
use result::ResultTrait;

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use evm::errors::EVMError;

#[generate_trait]
impl BlockInformation of BlockInformationTrait {
    /// 0x40 - BLOCKHASH 
    /// Get the hash of one of the 256 most recent complete blocks.
    /// # Specification: https://www.evm.codes/#40?fork=shanghai
    fn exec_blockhash(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x41 - COINBASE 
    /// Get the block's beneficiary address.
    /// # Specification: https://www.evm.codes/#41?fork=shanghai
    fn exec_coinbase(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x42 - TIMESTAMP 
    /// Get the block’s timestamp
    /// # Specification: https://www.evm.codes/#42?fork=shanghai
    fn exec_timestamp(ref self: ExecutionContext) -> Result<(), EVMError> {
        match get_execution_info_syscall() {
            Result::Ok(execution_info) => {
                let timestamp = execution_info.unbox().block_info.unbox().block_timestamp.into();
                self.stack.push(timestamp)
            },
            Result::Err(_) => Result::Err(EVMError::SyscallError('Could not get block exec info')),
        }
    }

    /// 0x43 - NUMBER 
    /// Get the block number.
    /// # Specification: https://www.evm.codes/#43?fork=shanghai
    fn exec_number(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x44 - PREVRANDAO 
    /// # Specification: https://www.evm.codes/#44?fork=shanghai
    fn exec_prevrandao(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x45 - GASLIMIT 
    /// Get gas limit
    /// # Specification: https://www.evm.codes/#45?fork=shanghai
    fn exec_gaslimit(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x46 - CHAINID 
    /// Get the chain ID.
    /// # Specification: https://www.evm.codes/#46?fork=shanghai
    fn exec_chainid(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x47 - SELFBALANCE 
    /// Get balance of currently executing contract
    /// # Specification: https://www.evm.codes/#47?fork=shanghai
    fn exec_selfbalance(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x48 - BASEFEE 
    /// Get base fee.
    /// # Specification: https://www.evm.codes/#48?fork=shanghai
    fn exec_basefee(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }
}
