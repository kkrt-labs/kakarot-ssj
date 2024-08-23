use contracts::kakarot_core::{IKakarotCore, KakarotCore};
use core::hash::{HashStateTrait, HashStateExTrait};
use core::nullable::{match_nullable, FromNullableResult};
use core::num::traits::{OverflowingAdd, OverflowingSub, OverflowingMul};
use core::poseidon::PoseidonTrait;
use core::starknet::SyscallResultTrait;
use core::starknet::{
    Store, StorageBaseAddress, storage_base_address_from_felt252, ContractAddress, EthAddress,
    emit_event_syscall
};
use evm::backend::starknet_backend::fetch_original_storage;

use evm::errors::{ensure, EVMError, WRITE_SYSCALL_FAILED, READ_SYSCALL_FAILED, BALANCE_OVERFLOW};
use evm::model::account::{AccountTrait, AccountInternalTrait};
use evm::model::{Event, Transfer, Account, Address, AddressTrait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::helpers::{ArrayExtTrait, ResultExTrait};
use utils::set::{Set, SetTrait};

/// The `StateChangeLog` tracks the changes applied to storage during the execution of a
/// transaction.
/// Upon exiting an execution context, contextual changes must be finalized into transactional
/// changes.
/// Upon exiting the transaction, transactional changes must be finalized into storage updates.
///
/// # Type Parameters
///
/// * `T` - The type of values stored in the log.
///
/// # Fields
///
/// * `changes` - A `Felt252Dict` of contextual changes. Tracks the changes applied inside a single
/// execution context.
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
    /// Values written to the StateChangeLog are not written to storage until the StateChangeLog is
    /// totally finalized at the end of the transaction.
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
        while let Option::Some(key) = keyset_span.pop_front() {
            let value = self.changes.get(*key).deref();
            cloned_changes.insert(*key, NullableTrait::new(value));
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
            Option::Some(acc) => { println!("Returning account {:?} with nonce {:?}", acc.evm_address(), acc.nonce);
            return acc; },
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
                return fetch_original_storage(@account, key);
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

        let (new_sender_balance, underflow) = sender.balance().overflowing_sub(transfer.amount);
        ensure(!underflow, EVMError::InsufficientBalance)?;

        let (new_recipient_balance, overflow) = recipient.balance.overflowing_add(transfer.amount);
        ensure(!overflow, EVMError::NumericOperations(BALANCE_OVERFLOW))?;

        sender.set_balance(new_sender_balance);
        recipient.set_balance(new_recipient_balance);

        self.set_account(sender);
        self.set_account(recipient);

        self.transfers.append(transfer);
        Result::Ok(())
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
/// Note: the storage_base_address_from_felt252 function always works for any felt - and returns the
/// number normalized into the range [0, 2^251 - 256). (x % (2^251 - 256))
/// https://github.com/starkware-libs/cairo/issues/4187
fn compute_storage_address(key: u256) -> StorageBaseAddress {
    let hash = PoseidonTrait::new().update_with(key).finalize();
    storage_base_address_from_felt252(hash)
}

#[cfg(test)]
mod tests {
    use contracts::test_utils::{deploy_contract_account, deploy_eoa};

    use evm::state::compute_state_key;
    use evm::test_utils;

    #[test]
    fn test_compute_state_key() {
        let key = 100;
        let evm_address = test_utils::evm_address();

        // The values can be computed externally by running a Rust program using the
        // `starknet_crypto` crate and `poseidon_hash_many`.
        // ```rust
        //     use starknet_crypto::{FieldElement,poseidon_hash_many};
        // use crypto_bigint::{U256};

        // fn main() {
        //     let keys: Vec<FieldElement> = vec![
        //         FieldElement::from_hex_be("0x65766d5f61646472657373").unwrap(),
        //         FieldElement::from_hex_be("0x64").unwrap(),
        //         FieldElement::from_hex_be("0x00").unwrap(),
        //         ];
        //     let values_to_hash = [keys[0],keys[1],keys[2]];
        //     let hash = poseidon_hash_many(&values_to_hash);
        //
        // }
        //
        let address = compute_state_key(evm_address, key);
        assert(
            address == 0x1b0f25b79b18f8734761533714f234825f965d6215cebdc391ceb3b964dd36,
            'hash not expected value'
        )
    }

    mod test_state_changelog {
        use evm::state::{StateChangeLog, StateChangeLogTrait};
        use evm::test_utils;
        use utils::set::{Set, SetTrait};

        #[test]
        fn test_read_empty_log() {
            let mut changelog: StateChangeLog<felt252> = Default::default();
            let key = test_utils::storage_base_address().into();
            assert(changelog.read(key).is_none(), 'should return None');
        }

        #[test]
        fn test_write_read() {
            let mut changelog: StateChangeLog = Default::default();
            let key = test_utils::storage_base_address().into();

            changelog.write(key, 42);
            assert(changelog.read(key).unwrap() == 42, 'value not stored correctly');
            assert(changelog.keyset.len() == 1, 'should add a key to tracking');

            changelog.write(key, 43);
            assert(changelog.read(key).unwrap() == 43, 'value should have been updated');
            assert(changelog.keyset.len() == 1, 'keys should not be added twice');

            // Write multiple keys
            let second_key = 'second_location';
            changelog.write(second_key, 1337.into());

            assert(changelog.read(second_key).unwrap() == 1337, 'wrong second value');
            assert(changelog.keyset.len() == 2, 'should have two keys');
        }
    }

    mod test_state {
        use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
        use contracts::kakarot_core::interface::{IExtendedKakarotCoreDispatcherTrait};
        use contracts::test_utils as contract_utils;
        use contracts::uninitialized_account::UninitializedAccount;
        use core::starknet::EthAddress;
        use core::starknet::testing::set_contract_address;
        use evm::backend::starknet_backend;
        use evm::model::account::{Account, AccountTrait, AccountInternalTrait};
        use evm::model::{Event, Transfer, Address};
        use evm::state::{State, StateTrait};
        use evm::test_utils;
        use openzeppelin::token::erc20::interface::{
            IERC20CamelDispatcher, IERC20CamelDispatcherTrait
        };
        use utils::helpers::compute_starknet_address;
        use utils::set::{Set, SetTrait};


        #[test]
        fn test_get_account_when_not_present() {
            let mut state: State = Default::default();
            // Transfer native tokens to sender
            let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
            let evm_address: EthAddress = test_utils::evm_address();
            let starknet_address = compute_starknet_address(
                kakarot_core.contract_address.into(),
                evm_address,
                UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
            );
            let expected_account = Account {
                address: Address { evm: evm_address, starknet: starknet_address },
                code: [].span(),
                nonce: 0,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            let account = state.get_account(evm_address);

            assert(account == expected_account, 'Account mismatch');
            assert(state.accounts.keyset.len() == 1, 'Account not written in context');
        }


        #[test]
        fn test_get_account_when_present() {
            let mut state: State = Default::default();
            let deployer = test_utils::kakarot_address();
            set_contract_address(deployer);

            let evm_address: EthAddress = test_utils::evm_address();
            let starknet_address = compute_starknet_address(
                deployer.into(),
                evm_address,
                UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
            );
            let expected_account = Account {
                address: Address { evm: evm_address, starknet: starknet_address }, code: [
                    0xab, 0xcd, 0xef
                ].span(), nonce: 1, balance: 420, selfdestruct: false, is_created: false,
            };

            state.set_account(expected_account);
            let account = state.get_account(evm_address);

            assert(account == expected_account, 'Account mismatch');
            assert(state.accounts.keyset.len() == 1, 'Account not written in context');
        }


        #[test]
        #[ignore]
        fn test_get_account_when_deployed() {
            let mut state: State = Default::default();
            let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
            let evm_address: EthAddress = test_utils::evm_address();
            let ca = contract_utils::deploy_contract_account(
                evm_address, [0xab, 0xcd, 0xef].span()
            );
            contract_utils::fund_account_with_native_token(ca.starknet, native_token, 420);

            let starknet_address = kakarot_core.compute_starknet_address(evm_address);
            let expected_account = Account {
                address: Address { evm: evm_address, starknet: starknet_address }, code: [
                    0xab, 0xcd, 0xef
                ].span(), nonce: 1, balance: 420, selfdestruct: false, is_created: false,
            };

            let account = state.get_account(evm_address);

            assert(account == expected_account, 'Account mismatch');
            assert(state.accounts.keyset.len() == 1, 'Account not written in context');
        }

        #[test]
        fn test_write_read_cached_storage() {
            let mut state: State = Default::default();
            let evm_address: EthAddress = test_utils::evm_address();
            let key = 10;
            let value = 100;

            state.write_state(evm_address, key, value);
            let read_value = state.read_state(evm_address, key);

            assert(value == read_value, 'Storage mismatch');
        }

        #[test]
        fn test_read_state_from_sn_storage() {
            // Transfer native tokens to sender
            contract_utils::setup_contracts_for_testing();
            let evm_address: EthAddress = test_utils::evm_address();
            let mut ca_address = contract_utils::deploy_contract_account(evm_address, [].span());

            let mut state: State = Default::default();
            let key = 10;
            let value = 100;
            let account = Account {
                address: ca_address, code: [
                    0xab, 0xcd, 0xef
                ].span(), nonce: 1, balance: 0, selfdestruct: false, is_created: false,
            };
            IAccountDispatcher { contract_address: account.starknet_address() }
                .write_storage(key, value);

            let read_value = state.read_state(evm_address, key);

            assert(value == read_value, 'Storage mismatch');
        }

        #[test]
        fn test_add_event() {
            let mut state: State = Default::default();
            let event = Event { keys: array![100, 200], data: array![0xab, 0xde] };

            state.add_event(event.clone());

            assert(state.events.len() == 1, 'Event not added');
            assert(state.events[0].clone() == event, 'Event mismatch');
        }

        #[test]
        fn test_add_transfer() {
            //Given
            let mut state: State = Default::default();
            contract_utils::setup_contracts_for_testing();

            let sender_evm_address = test_utils::evm_address();
            let sender_starknet_address = contract_utils::deploy_eoa(sender_evm_address)
                .contract_address;
            let sender_address = Address {
                evm: sender_evm_address, starknet: sender_starknet_address
            };
            let recipient_evm_address = test_utils::other_evm_address();
            let recipient_starknet_address = contract_utils::deploy_eoa(recipient_evm_address)
                .contract_address;
            let recipient_address = Address {
                evm: recipient_evm_address, starknet: recipient_starknet_address
            };
            let transfer = Transfer {
                sender: sender_address, recipient: recipient_address, amount: 100
            };
            // Write user balances in cache to avoid fetching from SN storage
            let mut sender = state.get_account(sender_address.evm);
            sender.set_balance(300);
            state.set_account(sender);

            // When
            state.add_transfer(transfer).unwrap();

            // Then, transfer appended to log and cached balances updated
            assert(state.transfers.len() == 1, 'Transfer not added');
            assert(*state.transfers[0] == transfer, 'Transfer mismatch');

            assert(
                state.get_account(sender_address.evm).balance() == 200, 'Sender balance mismatch'
            );
            assert(
                state.get_account(recipient_address.evm).balance() == 100,
                'Recipient balance mismatch'
            );
        }

        #[test]
        fn test_add_transfer_with_same_sender_and_recipient() {
            //Given
            let mut state: State = Default::default();
            contract_utils::setup_contracts_for_testing();

            let sender_evm_address = test_utils::evm_address();
            let sender_starknet_address = contract_utils::deploy_eoa(sender_evm_address)
                .contract_address;
            let sender_address = Address {
                evm: sender_evm_address, starknet: sender_starknet_address
            };

            // since sender and recipient is same
            let transfer = Transfer {
                sender: sender_address, recipient: sender_address, amount: 100
            };

            // Write user balances in cache to avoid fetching from SN storage
            let mut sender = state.get_account(sender_address.evm);
            sender.balance = 300;
            state.set_account(sender);

            // When
            state.add_transfer(transfer).unwrap();

            // Then, no transfer appended to log and cached balances updated
            assert(state.transfers.len() == 0, 'Transfer added');

            assert(
                state.get_account(sender_address.evm).balance() == 300, 'Sender balance mismatch'
            );
        }

        #[test]
        fn test_add_transfer_when_amount_is_zero() {
            //Given
            let mut state: State = Default::default();
            contract_utils::setup_contracts_for_testing();

            let sender_evm_address = test_utils::evm_address();
            let sender_starknet_address = contract_utils::deploy_eoa(sender_evm_address)
                .contract_address;
            let sender_address = Address {
                evm: sender_evm_address, starknet: sender_starknet_address
            };
            let recipient_evm_address = test_utils::other_evm_address();
            let recipient_starknet_address = contract_utils::deploy_eoa(recipient_evm_address)
                .contract_address;
            let recipient_address = Address {
                evm: recipient_evm_address, starknet: recipient_starknet_address
            };
            let transfer = Transfer {
                sender: sender_address, recipient: recipient_address, amount: 0
            };
            // Write user balances in cache to avoid fetching from SN storage
            // Write user balances in cache to avoid fetching from SN storage
            let mut sender = state.get_account(sender_address.evm);
            sender.balance = 300;
            state.set_account(sender);
            let mut recipient = state.get_account(recipient_address.evm);
            recipient.set_balance(0);
            state.set_account(recipient);

            // When
            state.add_transfer(transfer).unwrap();

            // Then, no transfer appended to log and cached balances updated
            assert(state.transfers.len() == 0, 'Transfer added');

            assert(
                state.get_account(sender_address.evm).balance() == 300, 'Sender balance mismatch'
            );
            assert(
                state.get_account(recipient_address.evm).balance() == 0,
                'Recipient balance mismatch'
            );
        }

        #[test]
        fn test_read_balance_cached() {
            let mut state: State = Default::default();
            contract_utils::setup_contracts_for_testing();

            let evm_address = test_utils::evm_address();
            let starknet_address = contract_utils::deploy_eoa(evm_address).contract_address;
            let address = Address { evm: evm_address, starknet: starknet_address };

            let balance = 100;

            let mut account = state.get_account(address.evm);
            account.set_balance(balance);
            state.set_account(account);
            let read_balance = state.get_account(address.evm).balance();

            assert(balance == read_balance, 'Balance mismatch');
        }


        #[test]
        fn test_read_balance_from_storage() {
            // Transfer native tokens to sender
            let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
            let evm_address: EthAddress = test_utils::evm_address();
            let eoa_account = starknet_backend::deploy(evm_address).expect('sender deploy failed');
            // Transfer native tokens to sender - we need to set the contract address for this
            set_contract_address(contract_utils::constants::ETH_BANK());
            IERC20CamelDispatcher { contract_address: native_token.contract_address }
                .transfer(eoa_account.starknet, 10000);
            // Revert back to contract_address = kakarot for the test
            set_contract_address(kakarot_core.contract_address);
            let mut state: State = Default::default();
            let read_balance = state.get_account(evm_address).balance();

            assert(read_balance == 10000, 'Balance mismatch');
        }
    }
}
