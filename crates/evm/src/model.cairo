mod account;
mod contract_account;
mod eoa;

use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::execution::Status;
use evm::model::account::{Account, AccountTrait};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::eoa::EOATrait;
use evm::state::State;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{EthAddress, get_contract_address, ContractAddress};
use utils::helpers::{ResultExTrait};
use utils::traits::{EthAddressDefault, ContractAddressDefault};

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
    fn is_deployed(self: EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let maybe_account = kakarot_state.address_registry(self);
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

#[derive(Destruct)]
struct ExecutionResult {
    address: Address,
    status: Status,
    return_data: Span<u8>,
    create_addresses: Span<EthAddress>,
    destroyed_contracts: Span<EthAddress>,
    events: Span<Event>,
    state: State,
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
