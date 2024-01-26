use contracts::kakarot_core::{IKakarotCore, KakarotCore};
use core::starknet::SyscallResultTrait;

use evm::errors::{ensure, EVMError, WRITE_SYSCALL_FAILED, READ_SYSCALL_FAILED, BALANCE_OVERFLOW};
use evm::model::account::{AccountTrait, AccountInternalTrait};
use evm::model::{Event, Transfer, Account, AccountType, Address, AddressTrait};
use hash::{HashStateTrait, HashStateExTrait};
use integer::{u256_overflow_sub, u256_overflowing_add};
use nullable::{match_nullable, FromNullableResult};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use poseidon::PoseidonTrait;
use starknet::{
    Store, StorageBaseAddress, storage_base_address_from_felt252, ContractAddress, EthAddress,
    emit_event_syscall
};
use utils::helpers::{ArrayExtTrait, ResultExTrait};
use utils::set::{Set, SetTrait};
use utils::traits::{StorageBaseAddressPartialEq, StorageBaseAddressIntoFelt252};

/// The `StateChangeLog` tracks the changes applied to storage during the execution of a transaction.
/// Upon exiting an execution context, contextual changes must be finalized into transactional changes.
/// Upon exiting the transaction, transactional changes must be finalized into storage updates.
///
/// # Type Parameters
///
/// * `T` - The type of values stored in the log.
///
/// # Fields
///
/// * `changes` - A `Felt252Dict` of contextual changes. Tracks the changes applied inside a single execution context.
/// * `keyset` - An `Array` of contextual keys.
struct StateChangeLog<T> {
    changes: Felt252Dict<Nullable<T>>,
    keyset: Set<felt252>,
}

impl StateChangeLogDestruct<T, +Drop<T>> of Destruct<StateChangeLog<T>> {
    fn destruct(self: StateChangeLog<T>) nopanic {
        self.changes.squash();
    }
}

impl StateChangeLogDefault<T, +Drop<T>> of Default<StateChangeLog<T>> {
    fn default() -> StateChangeLog<T> {
        StateChangeLog { changes: Default::default(), keyset: Default::default(), }
    }
}

#[generate_trait]
impl StateChangeLogImpl<T, +Drop<T>, +Copy<T>> of StateChangeLogTrait<T> {
    /// Reads a value from the StateChangeLog. Starts by looking for the value in the
    /// contextual changes. If the value is not found, looks for it in the
    /// transactional changes.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `StateChangeLog` instance.
    /// * `key` - The key of the value to read.
    ///
    /// # Returns
    ///
    /// An `Option` containing the value if it exists, or `None` if it does not.
    #[inline(always)]
    fn read(ref self: StateChangeLog<T>, key: felt252) -> Option<T> {
        match match_nullable(self.changes.get(key)) {
            FromNullableResult::Null => { Option::None },
            FromNullableResult::NotNull(value) => Option::Some(value.unbox()),
        }
    }

    /// Writes a value to the StateChangeLog.
    /// Values written to the StateChangeLog are not written to storage until the StateChangeLog is totally finalized at the end of the transaction.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `StateChangeLog` instance.
    /// * `key` - The key of the value to write.
    /// * `value` - The value to write.
    #[inline(always)]
    fn write(ref self: StateChangeLog<T>, key: felt252, value: T) {
        self.changes.insert(key, NullableTrait::new(value));
        self.keyset.add(key);
    }

    fn clone(ref self: StateChangeLog<T>) -> StateChangeLog<T> {
        let mut cloned_changes = Default::default();
        let mut keyset_span = self.keyset.to_span();
        loop {
            match keyset_span.pop_front() {
                Option::Some(key) => {
                    let value = self.changes.get(*key).deref();
                    cloned_changes.insert(*key, NullableTrait::new(value));
                },
                Option::None => { break; }
            }
        };

        StateChangeLog { changes: cloned_changes, keyset: self.keyset.clone(), }
    }
}

#[derive(Default, Destruct)]
struct State {
    /// Accounts states - without storage and balances, which are handled separately.
    accounts: StateChangeLog<Account>,
    /// Account storage states. `EthAddress` indicates the target contract,
    /// `u256` indicates the storage key.
    /// `u256` indicates the value stored.
    /// We have to store the target contract, as we can't derive it from the
    /// hashed address only when finalizing.
    accounts_storage: StateChangeLog<(EthAddress, u256, u256)>,
    /// Account states
    /// Pending emitted events
    events: Array<Event>,
    /// Pending transfers
    transfers: Array<Transfer>,
}

#[generate_trait]
impl StateImpl of StateTrait {
    fn get_account(ref self: State, evm_address: EthAddress) -> Account {
        let maybe_account = self.accounts.read(evm_address.into());
        match maybe_account {
            Option::Some(acc) => { return acc; },
            Option::None => {
                let account = AccountTrait::fetch_or_create(evm_address);
                self.accounts.write(evm_address.into(), account);
                return account;
            }
        }
    }

    #[inline(always)]
    fn set_account(ref self: State, account: Account) {
        let evm_address = account.evm_address();

        self.accounts.write(evm_address.into(), account)
    }

    #[inline(always)]
    fn read_state(ref self: State, evm_address: EthAddress, key: u256) -> u256 {
        let internal_key = compute_state_key(evm_address, key);
        let maybe_entry = self.accounts_storage.read(internal_key);
        match maybe_entry {
            Option::Some((_, _, value)) => { return value; },
            Option::None => {
                let account = self.get_account(evm_address);
                return account.read_storage(key);
            }
        }
    }

    #[inline(always)]
    fn write_state(ref self: State, evm_address: EthAddress, key: u256, value: u256) {
        let internal_key = compute_state_key(evm_address, key);
        self.accounts_storage.write(internal_key.into(), (evm_address, key, value));
    }

    #[inline(always)]
    fn add_event(ref self: State, event: Event) {
        self.events.append(event)
    }

    #[inline(always)]
    fn add_transfer(ref self: State, transfer: Transfer) -> Result<(), EVMError> {
        if (transfer.amount == 0 || transfer.sender.evm == transfer.recipient.evm) {
            return Result::Ok(());
        }
        let mut sender = self.get_account(transfer.sender.evm);
        let mut recipient = self.get_account(transfer.recipient.evm);

        let (new_sender_balance, underflow) = u256_overflow_sub(sender.balance(), transfer.amount);
        ensure(!underflow, EVMError::InsufficientBalance)?;

        let (new_recipient_balance, overflow) = u256_overflowing_add(
            recipient.balance, transfer.amount
        );
        ensure(!overflow, EVMError::NumericOperations(BALANCE_OVERFLOW))?;

        sender.set_balance(new_sender_balance);
        recipient.set_balance(new_recipient_balance);

        self.set_account(sender);
        self.set_account(recipient);

        self.transfers.append(transfer);
        Result::Ok(())
    }

    #[inline(always)]
    fn commit_state(ref self: State) -> Result<(), EVMError> {
        self.commit_accounts()?;
        self.transfer_native_token()?;
        self.commit_storage()?;
        self.emit_events()
    }

    fn clone(ref self: State) -> State {
        State {
            accounts: self.accounts.clone(),
            accounts_storage: self.accounts_storage.clone(),
            events: self.events.clone(),
            transfers: self.transfers.clone(),
        }
    }

    // Check whether is an account is both in the global state and non empty.
    fn is_account_alive(ref self: State, evm_address: EthAddress) -> bool {
        let account = self.get_account(evm_address);
        return !(account.nonce == 0 && account.code.len() == 0 && account.balance == 0);
    }
}
#[generate_trait]
impl StateInternalImpl of StateInternalTrait {
    /// Commits storage changes to the KakarotCore contract by writing pending
    /// state changes to Starknet Storage.
    /// commit_storage MUST be called after commit_accounts.
    fn commit_storage(ref self: State) -> Result<(), EVMError> {
        let mut storage_keys = self.accounts_storage.keyset.to_span();
        let result = loop {
            match storage_keys.pop_front() {
                Option::Some(state_key) => {
                    let (evm_address, key, value) = self
                        .accounts_storage
                        .changes
                        .get(*state_key)
                        .deref();
                    let mut account = self.get_account(evm_address);
                    account.commit_storage(key, value);
                },
                Option::None => { break Result::Ok(()); }
            }
        };
        result
    }


    /// Iterates through the list of events and emits them.
    fn emit_events(ref self: State) -> Result<(), EVMError> {
        loop {
            match self.events.pop_front() {
                Option::Some(event) => {
                    let mut keys = Default::default();
                    let mut data = Default::default();
                    Serde::<Array<u256>>::serialize(@event.keys, ref keys);
                    Serde::<Array<u8>>::serialize(@event.data, ref data);
                    emit_event_syscall(keys.span(), data.span()).unwrap_syscall();
                },
                Option::None => { break Result::Ok(()); }
            }
        }
    }
    /// Iterates through the list of pending transfer and triggers them
    fn transfer_native_token(ref self: State) -> Result<(), EVMError> {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token = kakarot_state.native_token();
        loop {
            match self.transfers.pop_front() {
                Option::Some(transfer) => {
                    IERC20CamelDispatcher { contract_address: native_token }
                        .transferFrom(
                            transfer.sender.starknet, transfer.recipient.starknet, transfer.amount
                        );
                },
                Option::None => { break; }
            }
        };
        Result::Ok(())
    }

    fn commit_accounts(ref self: State) -> Result<(), EVMError> {
        let mut account_keys = self.accounts.keyset.to_span();
        loop {
            match account_keys.pop_front() {
                Option::Some(evm_address) => {
                    let account = self.accounts.changes.get(*evm_address).deref();
                    account.commit();
                },
                Option::None => { break Result::Ok(()); }
            };
        }
    }
}

/// Computes the key for the internal state for a given EVM storage key.
/// The key is computed as follows:
/// 1. Compute the hash of the EVM address and the key(low, high) using Poseidon.
/// 2. Return the hash
fn compute_state_key(evm_address: EthAddress, key: u256) -> felt252 {
    let hash = PoseidonTrait::new().update_with(evm_address).update_with(key).finalize();
    hash
}

/// Computes the storage address for a given EVM storage key.
/// The storage address is computed as follows:
/// 1. Compute the hash of the key (low, high) using Poseidon.
/// 2. Use `storage_base_address_from_felt252` to obtain the starknet storage base address.
/// Note: the storage_base_address_from_felt252 function always works for any felt - and returns the number
/// normalized into the range [0, 2^251 - 256). (x % (2^251 - 256))
/// https://github.com/starkware-libs/cairo/issues/4187
fn compute_storage_address(key: u256) -> StorageBaseAddress {
    let hash = PoseidonTrait::new().update_with(key).finalize();
    storage_base_address_from_felt252(hash)
}
