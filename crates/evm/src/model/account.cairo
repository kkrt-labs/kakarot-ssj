use evm::errors::{EVMError};
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::model::eoa::EOATrait;
use evm::model::{AccountType, EOA};
use evm::storage_journal::{Journal, JournalTrait};
use starknet::{ContractAddress, EthAddress, get_contract_address};
use utils::helpers::ByteArrayExTrait;

#[derive(Destruct)]
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
    /// The fetched account if it existed, otherwise a new empty account.
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

    /// Reads the value stored at the given key for the corresponding account.
    ///TODO Fetch in local state
    /// If not there, reads the contract storage and cache the result.
    // @param self The pointer to the execution Account.
    // @param address The pointer to the Address.
    // @param key The pointer to the storage key
    // @return The updated Account
    // @return The read value
    fn read_storage(ref self: Account, key: u256) -> Result<u256, EVMError> {
        //TODO start by reading in local state
        match self.account_type {
            AccountType::EOA(eoa) => Result::Ok(0),
            AccountType::ContractAccount(ca) => ca.storage_at(key),
        }
    }

    /// Update a storage key in the account with the given value
    /// # Arguments
    /// * `self` The Account to update
    /// * `key` The storage key to modify
    /// * `value` The value to write
    fn write_storage(ref self: Account, key: u256, value: u256) {
        //TODO write to local state
        panic_with_felt252('unimplemented')
    }

    /// Sets the nonce of the Account
    /// # Arguments
    /// * `self` The Account to set the nonce on
    /// * `nonce` The new nonce
    #[inline(always)]
    fn set_nonce(ref self: Account, nonce: u64) {
        self.nonce = nonce;
    }

    /// Sets the code of the Account
    /// # Arguments
    /// * `self` The Account to set the code on
    /// * `code` The new code
    #[inline(always)]
    fn set_code(ref self: Account, code: Span<u8>) {
        self.code = code;
    }

    /// Registers an account for SELFDESTRUCT
    /// `true` means that the account will be erased at the end of the transaction
    fn selfdestruct(ref self: Account) {
        self.selfdestruct = true;
    }
}
