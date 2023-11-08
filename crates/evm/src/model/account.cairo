use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::{Address, AccountType};
use openzeppelin::token::erc20::interface::{
    IERC20CamelSafeDispatcher, IERC20CamelSafeDispatcherTrait
};
use starknet::{ContractAddress, EthAddress, get_contract_address};
use utils::helpers::{ResultExTrait, ByteArrayExTrait, compute_starknet_address};

#[derive(Copy, Drop, PartialEq)]
struct Account {
    account_type: AccountType,
    address: Address,
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
    fn fetch_or_create(evm_address: EthAddress) -> Result<Account, EVMError> {
        let maybe_acc = AccountTrait::fetch(evm_address)?;

        match maybe_acc {
            Option::Some(account) => Result::Ok(account),
            Option::None => {
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let starknet_address = kakarot_state.compute_starknet_address(evm_address);
                Result::Ok(
                    // If no account exists at `address`, then we are trying to
                    // access an undeployed contract account.  Simple value
                    // transfers between EOAs don't call this function -
                    // Therefore, we're sure that only contract accounts are
                    // undeployed.
                    Account {
                        account_type: AccountType::Unknown,
                        address: Address { starknet: starknet_address, evm: evm_address, },
                        code: Default::default().span(),
                        nonce: 0,
                        selfdestruct: false,
                    }
                )
            }
        }
    }

    /// Fetches an account from Starknet
    ///
    /// There is no way to access the nonce of an EOA currently but putting 1
    /// shouldn't have any impact and is safer than 0 since has_code_or_nonce is
    /// used in some places to check collision
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise `None`.
    fn fetch(evm_address: EthAddress) -> Result<Option<Account>, EVMError> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let maybe_stored_account = kakarot_state.address_registry(evm_address);
        let mut account = match maybe_stored_account {
            Option::Some((
                account_type, starknet_address
            )) => {
                match account_type {
                    AccountType::EOA => Option::Some(
                        Account {
                            account_type: AccountType::EOA,
                            address: Address { evm: evm_address, starknet: starknet_address },
                            code: Default::default().span(),
                            nonce: 1,
                            selfdestruct: false,
                        }
                    ),
                    AccountType::ContractAccount => {
                        let address = Address { evm: evm_address, starknet: starknet_address };
                        Option::Some(
                            Account {
                                account_type: AccountType::ContractAccount,
                                address,
                                code: ContractAccountTrait::fetch_bytecode(@address)?,
                                nonce: ContractAccountTrait::fetch_nonce(@address)?,
                                selfdestruct: false,
                            }
                        )
                    },
                    AccountType::Unknown(_) => Option::None,
                }
            },
            Option::None => Option::None,
        };
        Result::Ok(account)
    }

    /// Returns whether an account should be deployed or not.  If the nonce is
    /// not 0 and it has code, the account should be deployed - provided it's not already
    /// deployed yet.
    // If the nonce is 0, the account is just "touched" (e.g.
    // balance transfer) and is not set for deployment.
    #[inline(always)]
    fn should_deploy(self: @Account) -> bool {
        if self.is_ca() && (*self.nonce != 0 || !(*self.code).is_empty()) {
            return true;
        };
        false
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
        let is_deployed = AccountTrait::is_deployed(self.address().evm);

        if is_deployed {
            match self.account_type {
                AccountType::EOA(eoa) => {
                    // no - op
                    Result::Ok(())
                },
                AccountType::ContractAccount => {
                    let mut ca_address = self.address();
                    if *self.selfdestruct {
                        return ca_address.selfdestruct();
                    }
                    ca_address.store_nonce(*self.nonce)
                //Storage is handled outside of the account and must be commited after all accounts are commited.
                },
                AccountType::Unknown => { Result::Ok(()) }
            }
        } else if self.should_deploy() {
            //Case new account
            // If SELFDESTRUCT, just do nothing
            if (*self.selfdestruct == true) {
                return Result::Ok(());
            };
            let mut ca_address = ContractAccountTrait::deploy(self.address().evm, *self.code)?;
            ca_address.store_nonce(*self.nonce)
        //Storage is handled outside of the account and must be commited after all accounts are commited.
        } else {
            Result::Ok(())
        }
    }

    #[inline(always)]
    fn address(self: @Account) -> Address {
        *self.address
    }

    #[inline(always)]
    fn is_precompile(self: @Account) -> bool {
        let evm_address: felt252 = self.address().evm.into();
        if evm_address.into() < 0x10_u256 {
            return true;
        }
        false
    }

    /// Returns whether an accound is deployed at the given address.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to look up.
    ///
    /// # Returns
    ///
    /// `true` if an account is deployed at this address, `false` otherwise.
    #[inline(always)]
    fn is_deployed(address: EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let maybe_account = kakarot_state.address_registry(address);
        match maybe_account {
            Option::Some(_) => true,
            Option::None => false
        }
    }

    /// Returns `true` if the account is a Contract Account (CA).
    #[inline(always)]
    fn is_ca(self: @Account) -> bool {
        match self.account_type {
            AccountType::EOA => false,
            AccountType::ContractAccount => true,
            AccountType::Unknown => false
        }
    }

    #[inline(always)]
    fn evm_address(self: @Account) -> EthAddress {
        self.address().evm
    }

    /// Returns the balance in native token for a given EVM account (EOA or CA)
    /// This is equivalent to checking the balance in native coin, i.e. ETHER of an account in Ethereum
    #[inline(always)]
    fn balance(self: @Account) -> Result<u256, EVMError> {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token_address = kakarot_state.native_token();
        let native_token = IERC20CamelSafeDispatcher { contract_address: native_token_address };
        //Note: Starknet OS doesn't allow error management of failed syscalls yet.
        // If this call fails, the entire transaction will revert.
        native_token
            .balanceOf(self.address().starknet)
            .map_err(EVMError::SyscallFailed(CONTRACT_SYSCALL_FAILED))
    }

    /// Returns the bytecode of the EVM account (EOA or CA)
    #[inline(always)]
    fn bytecode(self: @Account) -> Span<u8> {
        *self.code
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
    #[inline(always)]
    fn read_storage(self: @Account, key: u256) -> Result<u256, EVMError> {
        match self.account_type {
            AccountType::EOA => Result::Ok(0),
            AccountType::ContractAccount => self.address().fetch_storage(key),
            AccountType::Unknown(_) => Result::Ok(0),
        }
    }

    #[inline(always)]
    fn set_type(ref self: Account, account_type: AccountType) {
        self.account_type = account_type;
    }

    /// Sets the nonce of the Account
    /// # Arguments
    /// * `self` The Account to set the nonce on
    /// * `nonce` The new nonce
    #[inline(always)]
    fn set_nonce(ref self: Account, nonce: u64) {
        self.nonce = nonce;
    }

    #[inline(always)]
    fn nonce(self: @Account) -> u64 {
        *self.nonce
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
    #[inline(always)]
    fn selfdestruct(ref self: Account) {
        self.selfdestruct = true;
    }

    /// Returns whether the account is registered for SELFDESTRUCT
    /// `true` means that the account will be erased at the end of the transaction
    #[inline(always)]
    fn is_selfdestruct(self: @Account) -> bool {
        *self.selfdestruct
    }
}
