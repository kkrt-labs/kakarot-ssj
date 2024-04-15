mod account;
mod vm;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};

use core::num::traits::Zero;
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::model::account::{Account, AccountTrait};
use evm::state::State;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{EthAddress, get_contract_address, ContractAddress};
use utils::checked_math::CheckedMath;
use utils::fmt::{TSpanSetDebug};
use utils::helpers::{ResultExTrait};
use utils::set::{Set, SpanSet};
use utils::traits::{EthAddressDefault, ContractAddressDefault, SpanDefault};

#[derive(Destruct, Default)]
struct Environment {
    origin: EthAddress,
    gas_price: u128,
    chain_id: u128,
    prevrandao: u256,
    block_number: u64,
    block_gas_limit: u128,
    block_timestamp: u64,
    coinbase: EthAddress,
    base_fee: u128,
    state: State
}
#[derive(Copy, Drop, Default, PartialEq, Debug)]
struct Message {
    caller: Address,
    target: Address,
    gas_limit: u128,
    data: Span<u8>,
    code: Span<u8>,
    value: u256,
    should_transfer_value: bool,
    depth: usize,
    read_only: bool,
    accessed_addresses: SpanSet<EthAddress>,
    accessed_storage_keys: SpanSet<(EthAddress, u256)>,
}

#[derive(Drop, Debug)]
struct ExecutionResult {
    success: bool,
    return_data: Span<u8>,
    gas_left: u128,
    accessed_addresses: SpanSet<EthAddress>,
    accessed_storage_keys: SpanSet<(EthAddress, u256)>,
    gas_refund: u128,
}

#[generate_trait]
impl ExecutionResultImpl of ExecutionResultTrait {
    fn exceptional_failure(
        error: Span<u8>,
        accessed_addresses: SpanSet<EthAddress>,
        accessed_storage_keys: SpanSet<(EthAddress, u256)>
    ) -> ExecutionResult {
        ExecutionResult {
            success: false,
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
}

#[derive(Destruct)]
struct ExecutionSummary {
    success: bool,
    return_data: Span<u8>,
    gas_left: u128,
    state: State,
    gas_refund: u128
}

#[generate_trait]
impl ExecutionSummaryImpl of ExecutionSummaryTrait {
    fn exceptional_failure(error: Span<u8>) -> ExecutionSummary {
        ExecutionSummary {
            success: false,
            return_data: error,
            gas_left: 0,
            state: Default::default(),
            gas_refund: 0
        }
    }
}

struct TransactionResult {
    success: bool,
    return_data: Span<u8>,
    gas_used: u128,
    state: State
}

#[generate_trait]
impl TransactionResultImpl of TransactionResultTrait {
    fn exceptional_failure(error: Span<u8>, gas_used: u128) -> TransactionResult {
        TransactionResult {
            success: false, return_data: error, gas_used, state: Default::default()
        }
    }
}

/// The struct representing an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}

#[derive(Copy, Drop, PartialEq, Default, Debug)]
struct Address {
    evm: EthAddress,
    starknet: ContractAddress,
}

#[generate_trait]
impl AddressImpl of AddressTrait {
    fn is_deployed(self: @EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let address = kakarot_state.address_registry(*self);
        return address.is_non_zero();
    }

    fn fetch_balance(self: @Address) -> u256 {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token_address = kakarot_state.get_native_token();
        let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
        native_token.balanceOf(*self.starknet)
    }
}

/// A struct to save native token transfers to be made when finalizing
/// a tx
#[derive(Copy, Drop, PartialEq)]
struct Transfer {
    sender: Address,
    recipient: Address,
    amount: u256
}
