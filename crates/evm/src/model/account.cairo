use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait, IAccount};
use contracts::kakarot_core::kakarot::KakarotCore::KakarotCoreInternal;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::num::traits::Zero;
use core::traits::TryInto;
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::model::{Address, AddressTrait, Transfer};
use evm::state::State;
use evm::state::StateTrait;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{
    ContractAddress, EthAddress, get_contract_address, deploy_syscall, get_tx_info,
    SyscallResultTrait
};
use utils::helpers::{ResultExTrait, ByteArrayExTrait, compute_starknet_address};

#[derive(Copy, Drop, PartialEq)]
struct Account {
    address: Address,
    code: Span<u8>,
    nonce: u64,
    balance: u256,
    selfdestruct: bool,
}

#[derive(Drop)]
struct AccountBuilder {
    account: Account
}

#[generate_trait]
impl AccountBuilderImpl of AccountBuilderTrait {
    fn new(address: Address) -> AccountBuilder {
        AccountBuilder {
            account: Account {
                address: address,
                code: Default::default().span(),
                nonce: 0,
                balance: 0,
                selfdestruct: false,
            }
        }
    }

    #[inline(always)]
    fn fetch_balance(mut self: AccountBuilder) -> AccountBuilder {
        self.account.balance = self.account.address.fetch_balance();
        self
    }

    #[inline(always)]
    fn fetch_nonce(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        self.account.nonce = account.get_nonce();
        self
    }

    #[inline(always)]
    fn set_nonce(mut self: AccountBuilder, nonce: u64) -> AccountBuilder {
        self.account.nonce = nonce;
        self
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a Span<u8>.
    /// # Arguments
    /// * `self` - The address of the Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    fn fetch_bytecode(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        let bytecode = account.bytecode();
        self.account.code = bytecode;
        self
    }

    #[inline(always)]
    fn build(self: AccountBuilder) -> Account {
        self.account
    }
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
    fn fetch_or_create(evm_address: EthAddress) -> Account {
        let maybe_acc = AccountTrait::fetch(evm_address);

        match maybe_acc {
            Option::Some(account) => account,
            Option::None => {
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let starknet_address = kakarot_state.compute_starknet_address(evm_address);
                // If no account exists at `address`, then we are trying to
                // access an undeployed account (CA or EOA). We create an
                // empty account with the correct address and return it.
                AccountBuilderTrait::new(Address { starknet: starknet_address, evm: evm_address })
                    .fetch_balance()
                    .build()
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
    fn fetch(evm_address: EthAddress) -> Option<Account> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let starknet_address = kakarot_state.address_registry(evm_address);
        if starknet_address.is_zero() {
            return Option::None;
        }
        let address = Address { starknet: starknet_address, evm: evm_address };
        Option::Some(
            AccountBuilderTrait::new(address).fetch_nonce().fetch_bytecode().fetch_balance().build()
        )
    }


    /// Returns whether an account exists at the given address by checking
    /// whether it has code or a nonce.
    ///
    /// Based on the state of the account in the cache - the account can
    /// not be deployed on-chain yet, but already exist in the KakarotState.
    /// The account can also be EVM-undeployed but Starknet-deployed. In that case,
    /// is_known is true, but we should be able to deploy on top of it
    /// # Arguments
    ///
    /// * `account` - The instance of the account to check.
    ///
    /// # Returns
    ///
    /// `true` if an account exists at this address (has code or nonce), `false` otherwise.
    #[inline(always)]
    fn has_code_or_nonce(self: @Account) -> bool {
        if *self.nonce != 0 || !(*self.code).is_empty() {
            return true;
        };
        false
    }


    fn is_created(self: @Account) -> bool {
        panic!("unimplemented is created")
    }

    fn deploy(self: @Account) {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let uninitialized_account_class_hash = kakarot_state.uninitialized_account_class_hash();
        let kakarot_address = get_contract_address();
        let calldata: Span<felt252> = array![kakarot_address.into(), self.address().evm.into()]
            .span();

        let (starknet_address, _) = deploy_syscall(
            uninitialized_account_class_hash, self.address().evm.into(), calldata, true
        )
            .unwrap_syscall();
    }

    fn commit_storage(self: @Account, key: u256, value: u256) {
        IAccountDispatcher { contract_address: self.get_registered_starknet_address() }
            .write_storage(key, value);
    }


    #[inline(always)]
    fn balance(self: @Account) -> u256 {
        *self.balance
    }

    #[inline(always)]
    fn address(self: @Account) -> Address {
        *self.address
    }

    #[inline(always)]
    fn is_precompile(self: @Account) -> bool {
        let evm_address: felt252 = self.evm_address().into();
        if evm_address.into() < 0x10_u256 {
            return true;
        }
        false
    }

    #[inline(always)]
    fn evm_address(self: @Account) -> EthAddress {
        *self.address.evm
    }

    #[inline(always)]
    fn get_registered_starknet_address(self: @Account) -> ContractAddress {
        *self.address.starknet
    }

    /// Returns the bytecode of the EVM account (EOA or CA)
    #[inline(always)]
    fn bytecode(self: @Account) -> Span<u8> {
        *self.code
    }

    /// Fetches the value stored at the given key for the corresponding contract accounts.
    /// If the account is not deployed (in case of a create/deploy transaction), returns 0.
    /// If the account is an EOA, returns 0.
    /// # Arguments
    ///
    /// * `self` The account to read from.
    /// * `key` The key to read.
    ///
    /// # Returns
    ///
    /// A `Result` containing the value stored at the given key or an `EVMError` if there was an error.
    fn read_storage(self: @Account, key: u256) -> u256 {
        let is_deployed = self.address().evm.is_deployed();
        if is_deployed {
            return IAccountDispatcher { contract_address: self.address().starknet }.storage(key);
        }
        0
    }

    /// Sets the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The address of the Contract Account
    /// * `key` - The key to set
    /// * `value` - The value to set
    #[inline(always)]
    fn store_storage(self: @Account, key: u256, value: u256) {
        let mut contract_account = IAccountDispatcher {
            contract_address: self.get_registered_starknet_address()
        };
        contract_account.write_storage(key, value);
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

#[generate_trait]
impl AccountInternals of AccountInternalTrait {
    #[inline(always)]
    fn set_balance(ref self: Account, value: u256) {
        self.balance = value;
    }
}
