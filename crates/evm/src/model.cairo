mod account;
mod contract_account;
mod eoa;
mod vm;

use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::model::account::{Account, AccountTrait};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::eoa::EOATrait;
use evm::state::State;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{EthAddress, get_contract_address, ContractAddress};
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
    state: State
}
#[derive(Copy, Drop, Default, PartialEq)]
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
}

#[derive(Drop)]
struct ExecutionResult {
    success: bool,
    return_data: Span<u8>,
    gas_used: u128,
}

#[derive(Destruct)]
struct ExecutionSummary {
    state: State,
    return_data: Span<u8>,
    address: EthAddress,
    success: bool
}

/// The struct representing an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}

#[derive(Copy, Drop, PartialEq, Default)]
struct Address {
    evm: EthAddress,
    starknet: ContractAddress,
}

#[generate_trait]
impl AddressImpl of AddressTrait {
    fn is_deployed(self: @EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let maybe_account = kakarot_state.address_registry(*self);
        match maybe_account {
            Option::Some(_) => true,
            Option::None => false
        }
    }

    fn fetch_balance(self: @Address) -> u256 {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token_address = kakarot_state.native_token();
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

/// An EVM Account is either an EOA or a Contract Account.  In both cases, the
/// account is identified by an Ethereum address.  It has a corresponding
/// Starknet Address - The corresponding Starknet Contract for EOAs, and the
/// KakarotCore address for ContractAccounts.
#[derive(Copy, Drop, PartialEq, Serde)]
enum AccountType {
    EOA,
    ContractAccount,
    Unknown
}
