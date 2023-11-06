use contracts::kakarot_core::{KakarotCore, KakarotCore::account_class_hashContractMemberStateTrait};
use evm::errors::{EVMError};
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::model::eoa::{EOA, EOATrait};
use evm::model::{Address, AccountType};
use starknet::{ContractAddress, EthAddress, get_contract_address};
use utils::helpers::{ByteArrayExTrait, compute_starknet_address};

#[derive(Copy, Drop, PartialEq)]
struct Account {
    account_type: AccountType,
    code: Span<u8>,
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
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let starknet_address = compute_starknet_address(
                    get_contract_address(),
                    evm_address: address,
                    class_hash: kakarot_state.account_class_hash.read()
                );
                return Result::Ok(
                    // If no account exists at `address`, then
                    // we are trying to access an undeployed contract account
                    Account {
                        account_type: AccountType::ContractAccount(
                            ContractAccount {
                                evm_address: address, starknet_address: starknet_address
                            }
                        ),
                        code: Default::default().span(),
                        nonce: 0,
                        selfdestruct: false,
                    }
                );
            }
        }
    }

    /// Commits the account to Starknet by updating the account state if it
    /// exists, or deploying a new account if it doesn't.
    ///
    /// Only Contract Accounts can be modified.
    ///
    /// # Arguments
    /// * `self` - The account to commit
    ///
    /// # Returns
    ///
    /// `Ok(())` if the commit was successful, otherwise an `EVMError`.
    fn commit(self: @Account) -> Result<(), EVMError> {
        // Case account exists
        let maybe_acc = AccountImpl::account_type_at(self.address().evm)?;

        match maybe_acc {
            Option::Some(account_type) => {
                match account_type {
                    AccountType::EOA(eoa) => {
                        // no - op
                        Result::Ok(())
                    },
                    AccountType::ContractAccount(mut ca) => {
                        if *self.selfdestruct {
                            return ca.selfdestruct();
                        }
                        ca.set_nonce(*self.nonce)
                    //Storage is handled outside of the account and must be commited after all accounts are commited.
                    }
                }
            },
            Option::None => {
                //Case new account
                // If SELFDESTRUCT, just do nothing
                if (*self.selfdestruct == true) {
                    return Result::Ok(());
                }
                let mut ca = ContractAccountTrait::deploy(self.address().evm, *self.code)?;
                ca.set_nonce(*self.nonce);
                Result::Ok(())
            //Storage is handled outside of the account and must be commited after all accounts are commited.
            }
        }
    }

    #[inline(always)]
    fn address(self: @Account) -> Address {
        match self.account_type {
            AccountType::EOA(eoa) => { eoa.address() },
            AccountType::ContractAccount(ca) => { ca.address() }
        }
    }

    #[inline(always)]
    fn is_precompile(self: @Account) -> bool {
        let evm_address: felt252 = self.address().evm.into();
        if evm_address.into() < 0x10_u256 {
            return true;
        }
        false
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

    #[inline(always)]
    fn evm_address(self: @Account) -> EthAddress {
        match self.account_type {
            AccountType::EOA(eoa) => { eoa.evm_address() },
            AccountType::ContractAccount(ca) => { ca.evm_address() }
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
                Result::Ok(bytecode)
            }
        }
    }

    /// Reads the value stored at the given key for the corresponding account.
    /// If not there, reads the contract storage and cache the result.
    /// # Arguments
    ///
    /// * `self` The account to read from.
    /// * `key` The key to read.
    ///
    /// # Returns
    ///
    /// A `Result` containing the value stored at the given key or an `EVMError` if there was an error.
    fn read_storage(self: @Account, key: u256) -> Result<u256, EVMError> {
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
        panic_with_felt252('write storage unimplemented')
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
    /// This will cause the account to be erased at the end of the transaction
    fn selfdestruct(ref self: Account) {
        self.selfdestruct = true;
    }

    /// Returns whether the account is registered for SELFDESTRUCT
    /// `true` means that the account will be erased at the end of the transaction
    fn is_selfdestruct(self: @Account) -> bool {
        *self.selfdestruct
    }
}
