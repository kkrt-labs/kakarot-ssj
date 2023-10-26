mod contract_account;
mod eoa;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::EVMError;
use evm::execution::Status;
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::model::eoa::{EOA, EOATrait};
use evm::storage_journal::{Journal, JournalTrait};
use starknet::{EthAddress, get_contract_address, ContractAddress};
use utils::helpers::ByteArrayExTrait;

/// The struct representing an EVM event.
#[derive(Drop)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}


/// A struct to save Starknet native ETH transfers to be made when finalizing a
/// tx
#[derive(Copy, Drop)]
struct Transfer {
    sender: EthAddress,
    recipient: EthAddress,
    amount: u256
}

struct ExecutionResult {
    status: Status,
    return_data: Span<u8>,
    create_addresses: Span<EthAddress>,
    destroyed_contracts: Span<EthAddress>,
    events: Span<Event>,
    error: Option<EVMError>,
}


/// An EVM Account is either an EOA or a Contract Account.  In both cases, the
/// account is identified by an Ethereum address.  It has a corresponding
/// Starknet Address - The corresponding Starknet Contract for EOAs, and the
/// KakarotCore address for ContractAccounts.
#[derive(Copy, Drop)]
enum AccountType {
    EOA: EOA,
    ContractAccount: ContractAccount,
}

struct Account {
    account_type: AccountType,
    code: Span<u8>,
    storage: Journal,
    nonce: u64,
    selfdestruct: bool,
}

#[generate_trait]
impl AccountImpl of AccountTrait {
    /// Fetches an account from Starknet
    /// An non-deployed account is just an empty account.
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise an empty account.
    fn fetch_or_create(address: EthAddress) -> Result<Account, EVMError> {
        let maybe_acc = AccountImpl::account_type_at(address)?;

        match maybe_acc {
            Option::Some(account_type) => {
                match account_type {
                    AccountType::EOA(eoa) => { eoa.fetch() },
                    AccountType::ContractAccount(ca) => { ca.fetch() },
                }
            },
            Option::None => {
                return Result::Ok(
                    // If no account exists at `address`, then
                    // we are trying to access an undeployed contract account
                    Account {
                        account_type: AccountType::ContractAccount(
                            ContractAccount {
                                evm_address: address, starknet_address: get_contract_address()
                            }
                        ),
                        code: Default::default().span(),
                        storage: Default::default(),
                        nonce: 0,
                        selfdestruct: false,
                    }
                );
            }
        }
    }


    /// Returns the AccountType corresponding to an Ethereum address.
    /// If the address is not an EOA or a Contract Account (meaning that it is not deployed), returns None.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to look up.
    ///
    /// # Returns
    ///
    /// A `Result` containing an `Option` of the corresponding `AccountType` or an `EVMError` if there was an error.
    ///
    /// # Errors
    ///
    /// Returns an `EVMError` if there was an error while retrieving the nonce account of the account contract using the read_syscall.
    fn account_type_at(address: EthAddress) -> Result<Option<AccountType>, EVMError> {
        let maybe_eoa = EOATrait::at(address)?;
        if maybe_eoa.is_some() {
            return Result::Ok(Option::Some(AccountType::EOA(maybe_eoa.unwrap())));
        };

        let maybe_ca = ContractAccountTrait::at(address)?;
        match maybe_ca {
            Option::Some(ca) => { Result::Ok(Option::Some(AccountType::ContractAccount(ca))) },
            Option::None => { Result::Ok(Option::None) }
        }
    }

    /// Returns `true` if the account is an Externally Owned Account (EOA).
    #[inline(always)]
    fn is_eoa(self: @AccountType) -> bool {
        match self {
            AccountType::EOA => true,
            AccountType::ContractAccount => false
        }
    }

    /// Returns `true` if the account is a Contract Account (CA).
    #[inline(always)]
    fn is_ca(self: @AccountType) -> bool {
        match self {
            AccountType::EOA => false,
            AccountType::ContractAccount => true
        }
    }

    /// Returns the balance in native token for a given EVM account (EOA or CA)
    /// This is equivalent to checking the balance in native coin, i.e. ETHER of an account in Ethereum
    #[inline(always)]
    fn balance(self: @AccountType) -> Result<u256, EVMError> {
        match self {
            AccountType::EOA(eoa) => { eoa.balance() },
            AccountType::ContractAccount(ca) => { ca.balance() }
        }
    }

    /// Returns the bytecode of the EVM account (EOA or CA)
    fn bytecode(self: @AccountType) -> Result<Span<u8>, EVMError> {
        match self {
            AccountType::EOA(_) => Result::Ok(Default::default().span()),
            AccountType::ContractAccount(ca) => {
                let bytecode = ca.load_bytecode()?;
                Result::Ok(bytecode.into_bytes())
            }
        }
    }
}
