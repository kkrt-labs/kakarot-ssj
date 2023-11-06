mod account;
mod contract_account;
mod eoa;

use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::EVMError;
use evm::execution::Status;
use evm::model::account::{Account, AccountTrait};
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::model::eoa::{EOA, EOATrait};
use evm::state::State;
use starknet::{EthAddress, get_contract_address, ContractAddress};
use utils::helpers::ByteArrayExTrait;
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
    status: Status,
    return_data: Span<u8>,
    create_addresses: Span<EthAddress>,
    destroyed_contracts: Span<EthAddress>,
    events: Span<Event>,
    state: State,
    error: Option<EVMError>,
}

/// An EVM Account is either an EOA or a Contract Account.  In both cases, the
/// account is identified by an Ethereum address.  It has a corresponding
/// Starknet Address - The corresponding Starknet Contract for EOAs, and the
/// KakarotCore address for ContractAccounts.
#[derive(Copy, Drop, PartialEq)]
enum AccountType {
    EOA: EOA,
    ContractAccount: ContractAccount,
}
