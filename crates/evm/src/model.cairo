pub mod account;
pub mod vm;
pub use account::{Account, AccountTrait};
pub use vm::{VM, VMTrait};
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::num::traits::{CheckedSub, Zero};
use core::starknet::{EthAddress, ContractAddress};
use evm::errors::EVMError;
use evm::precompiles::{
    FIRST_ROLLUP_PRECOMPILE_ADDRESS, FIRST_ETHEREUM_PRECOMPILE_ADDRESS,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS
};
use evm::state::State;
use utils::fmt::{TSpanSetDebug};
use utils::set::SpanSet;
use utils::traits::{EthAddressDefault, ContractAddressDefault, SpanDefault};

#[derive(Destruct, Default)]
pub struct Environment {
    pub origin: EthAddress,
    pub gas_price: u128,
    pub chain_id: u128,
    pub prevrandao: u256,
    pub block_number: u64,
    pub block_gas_limit: u128,
    pub block_timestamp: u64,
    pub coinbase: EthAddress,
    pub base_fee: u128,
    pub state: State
}
#[derive(Copy, Drop, Default, PartialEq, Debug)]
pub struct Message {
    pub caller: Address,
    pub target: Address,
    pub gas_limit: u128,
    pub data: Span<u8>,
    pub code: Span<u8>,
    pub code_address: Address,
    pub value: u256,
    pub should_transfer_value: bool,
    pub depth: usize,
    pub read_only: bool,
    pub accessed_addresses: SpanSet<EthAddress>,
    pub accessed_storage_keys: SpanSet<(EthAddress, u256)>,
}

#[derive(Drop, Debug)]
pub struct ExecutionResult {
    pub status: ExecutionResultStatus,
    pub return_data: Span<u8>,
    pub gas_left: u128,
    pub accessed_addresses: SpanSet<EthAddress>,
    pub accessed_storage_keys: SpanSet<(EthAddress, u256)>,
    pub gas_refund: u128,
}

#[derive(Copy, Drop, PartialEq, Debug)]
pub enum ExecutionResultStatus {
    Success,
    Revert,
    Exception,
}

#[generate_trait]
pub impl ExecutionResultImpl of ExecutionResultTrait {
    fn exceptional_failure(
        error: Span<u8>,
        accessed_addresses: SpanSet<EthAddress>,
        accessed_storage_keys: SpanSet<(EthAddress, u256)>
    ) -> ExecutionResult {
        ExecutionResult {
            status: ExecutionResultStatus::Exception,
            return_data: error,
            gas_left: 0,
            accessed_addresses,
            accessed_storage_keys,
            gas_refund: 0,
        }
    }

    /// Decrements the gas_left field of the current execution context by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_left - value < 0
    #[inline(always)]
    fn charge_gas(ref self: ExecutionResult, value: u128) -> Result<(), EVMError> {
        self.gas_left = self.gas_left.checked_sub(value).ok_or(EVMError::OutOfGas)?;
        Result::Ok(())
    }

    fn is_success(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Success
    }

    fn is_exception(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Exception
    }

    fn is_revert(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Revert
    }
}

#[derive(Destruct)]
pub struct ExecutionSummary {
    pub status: ExecutionResultStatus,
    pub return_data: Span<u8>,
    pub gas_left: u128,
    pub state: State,
    pub gas_refund: u128
}

#[generate_trait]
pub impl ExecutionSummaryImpl of ExecutionSummaryTrait {
    fn exceptional_failure(error: Span<u8>) -> ExecutionSummary {
        ExecutionSummary {
            status: ExecutionResultStatus::Exception,
            return_data: error,
            gas_left: 0,
            state: Default::default(),
            gas_refund: 0
        }
    }

    fn is_success(self: @ExecutionSummary) -> bool {
        *self.status == ExecutionResultStatus::Success
    }

    fn is_exception(self: @ExecutionSummary) -> bool {
        *self.status == ExecutionResultStatus::Exception
    }

    fn is_revert(self: @ExecutionSummary) -> bool {
        *self.status == ExecutionResultStatus::Revert
    }
}

pub struct TransactionResult {
    pub success: bool,
    pub return_data: Span<u8>,
    pub gas_used: u128,
    pub state: State
}

#[generate_trait]
pub impl TransactionResultImpl of TransactionResultTrait {
    fn exceptional_failure(error: Span<u8>, gas_used: u128) -> TransactionResult {
        TransactionResult {
            success: false, return_data: error, gas_used, state: Default::default()
        }
    }
}

/// The struct representing an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
pub struct Event {
    pub keys: Array<u256>,
    pub data: Array<u8>,
}

#[derive(Copy, Drop, PartialEq, Default, Debug)]
pub struct Address {
    pub evm: EthAddress,
    pub starknet: ContractAddress,
}


impl ZeroAddress of core::num::traits::Zero<Address> {
    fn zero() -> Address {
        Address { evm: Zero::zero(), starknet: Zero::zero(), }
    }
    fn is_zero(self: @Address) -> bool {
        self.evm.is_zero() && self.starknet.is_zero()
    }
    fn is_non_zero(self: @Address) -> bool {
        !self.is_zero()
    }
}

#[generate_trait]
pub impl AddressImpl of AddressTrait {
    fn is_deployed(self: @EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let address = kakarot_state.address_registry(*self);
        return address.is_non_zero();
    }

    /// Check whether an address for a call-family opcode is a precompile.
    fn is_precompile(self: EthAddress) -> bool {
        let self: felt252 = self.into();
        return self != 0x00
            && (FIRST_ETHEREUM_PRECOMPILE_ADDRESS <= self.into()
                && self.into() <= LAST_ETHEREUM_PRECOMPILE_ADDRESS)
                || self.into() == FIRST_ROLLUP_PRECOMPILE_ADDRESS;
    }
}

/// A struct to save native token transfers to be made when finalizing
/// a tx
#[derive(Copy, Drop, PartialEq, Debug)]
pub struct Transfer {
    pub sender: Address,
    pub recipient: Address,
    pub amount: u256
}

#[cfg(test)]
mod tests {
    mod test_is_deployed {
        use evm::model::AddressTrait;
        use evm::test_utils;
        use snforge_std::test_address;
        use utils::helpers::compute_starknet_address;


        #[test]
        fn test_is_deployed_returns_true_if_in_registry() {
            // Given
            test_utils::setup_test_storages();
            let starknet_address = compute_starknet_address(
                test_address(), test_utils::evm_address(), test_utils::uninitialized_account()
            );
            test_utils::register_account(test_utils::evm_address(), starknet_address);

            // When
            let is_deployed = test_utils::evm_address().is_deployed();

            // Then
            assert!(is_deployed);
        }

        #[test]
        fn test_is_deployed_undeployed() {
            // Given
            test_utils::setup_test_storages();

            // When
            let is_deployed = test_utils::evm_address().is_deployed();

            // Then
            assert!(!is_deployed);
        }
    }
    mod test_is_precompile {
        use core::starknet::EthAddress;
        use evm::model::{AddressTrait};
        #[test]
        fn test_is_precompile() {
            // Given
            let valid_precompiles = array![
                0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x0a, 0x100
            ];

            //When
            for el in valid_precompiles {
                let evm_address: EthAddress = (el).try_into().unwrap();
                //Then
                assert_eq!(true, evm_address.is_precompile());
            };
        }

        #[test]
        fn test_is_precompile_zero() {
            // Given
            let evm_address: EthAddress = 0x0.try_into().unwrap();

            // When
            let is_precompile = evm_address.is_precompile();

            // Then
            assert_eq!(false, is_precompile);
        }

        #[test]
        fn test_is_not_precompile() {
            // Given
            let not_valid_precompiles = array![0xb, 0xc, 0xd, 0xe, 0xf, 0x99];

            //When
            for el in not_valid_precompiles {
                let evm_address: EthAddress = (el).try_into().unwrap();
                //Then
                assert_eq!(false, evm_address.is_precompile());
            };
        }
    }
}
