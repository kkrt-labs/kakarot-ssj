use contracts::tests::test_utils::{deploy_contract_account};
use evm::state::compute_state_key;
use evm::tests::test_utils;

#[test]
#[available_gas(200000)]
fn test_compute_state_key() {
    let key = 100;
    let evm_address = test_utils::evm_address();

    // The values can be computed externally by running a Rust program using the `starknet_crypto` crate and `poseidon_hash_many`.
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
    //     println!("hash: {}", hash);
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
    use evm::tests::test_utils;
    use utils::traits::StorageBaseAddressIntoFelt252;

    #[test]
    #[available_gas(200000000)]
    fn test_read_empty_log() {
        let mut changelog: StateChangeLog<felt252> = Default::default();
        let key = test_utils::storage_base_address().into();
        assert(changelog.read(key).is_none(), 'should return None');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_write_read() {
        let mut changelog: StateChangeLog = Default::default();
        let key = test_utils::storage_base_address().into();

        changelog.write(key, 42);
        assert(changelog.read(key).unwrap() == 42, 'value not stored correctly');
        assert(changelog.contextual_keyset.len() == 1, 'should add a key to tracking');

        changelog.write(key, 43);
        assert(changelog.read(key).unwrap() == 43, 'value should have been updated');
        assert(changelog.contextual_keyset.len() == 1, 'keys should not be added twice');

        // Write multiple keys
        let second_key = 'second_location';
        changelog.write(second_key, 1337.into());

        assert(changelog.read(second_key).unwrap() == 1337, 'wrong second value');
        assert(changelog.contextual_keyset.len() == 2, 'should have two keys');

        // Verify that there was no impact on global changes
        assert(changelog.transactional_keyset.len() == 0, 'shouldnt impact global changes');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_commit_context() {
        let mut changelog: StateChangeLog = Default::default();
        let key = test_utils::storage_base_address().into();
        changelog.write(key, 42.into());
        changelog.commit_context();

        assert(changelog.transactional_keyset.len() == 1, 'keys should be finalized');
        assert(changelog.contextual_keyset.len() == 0, 'local keys should be reset');
        assert(changelog.read(key).unwrap() == 42, 'read should return 42');

        let second_address = 'second_address';
        changelog.write(key, 44.into());
        changelog.write(second_address, 1337.into());

        changelog.commit_context();
        assert(changelog.transactional_keyset.len() == 2, 'keys should be finalized');
        assert(changelog.contextual_keyset.len() == 0, 'local keys should be reset');
        assert(changelog.read(key).unwrap() == 44, 'read should return 44');
        assert(changelog.read(second_address).unwrap() == 1337, 'read should return 1337');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_commit_empty_context() {
        let mut changelog: StateChangeLog<felt252> = Default::default();
        changelog.commit_context();
        assert(changelog.transactional_keyset.len() == 0, 'shouldnt have keys');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_clear_contextual_changes() {
        let mut changelog: StateChangeLog<felt252> = Default::default();
        let key = test_utils::storage_base_address().into();
        changelog.write(key, 42);
        changelog.clear_context();
        assert(changelog.contextual_keyset.len() == 0, 'context should be cleared');
        assert(changelog.read(key).is_none(), 'should return None');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_contextual_changes_override_transactional() {
        let mut changelog: StateChangeLog = Default::default();
        let key = test_utils::storage_base_address().into();
        changelog.write(key, 42.into());
        changelog.commit_context();
        changelog.write(key, 43.into());
        assert(changelog.read(key).unwrap() == 43, 'contextual not overriding');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_clear_context_does_not_affect_transactional() {
        let mut changelog: StateChangeLog = Default::default();
        let key = test_utils::storage_base_address().into();
        changelog.write(key, 42.into());
        changelog.commit_context();
        changelog.clear_context();
        assert(changelog.transactional_keyset.len() == 1, 'transactional changes affected');
        assert(changelog.read(key).unwrap() == 42, 'tx value should remain');
    }
}

mod test_simple_log {
    use evm::state::{SimpleLog, SimpleLogTrait};

    #[test]
    #[available_gas(200000000)]
    fn test_append_to_contextual_logs() {
        let mut log: SimpleLog<felt252> = Default::default();
        log.append(42);

        assert(log.contextual_logs.len() == 1, 'wrong len');
        assert(*log.contextual_logs[0] == 42, 'wrong value');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_commit_empty_context() {
        let mut log: SimpleLog<felt252> = Default::default();
        log.commit_context();

        assert(log.transactional_logs.len() == 0, 'tx logs should be empty');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_clear_contextual_logs() {
        let mut log: SimpleLog<felt252> = Default::default();
        log.append(42);
        log.clear_context();

        assert(log.contextual_logs.len() == 0, 'ctx logs should be cleared');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_contextual_logs_override_transactional() {
        let mut log: SimpleLog<felt252> = Default::default();
        log.append(42);
        log.commit_context();
        log.append(43);
        log.commit_context();

        assert(*log.transactional_logs[1] == 43, 'tx log value not 43');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_clear_context_does_not_affect_transactional() {
        let mut log: SimpleLog<felt252> = Default::default();
        log.append(42);
        log.commit_context();
        log.clear_context();

        assert(log.transactional_logs.len() == 1, 'tx logs affected by clear');
        assert(*log.transactional_logs[0] == 42, 'tx log value not 42');
    }
}

mod test_state {
    use contracts::tests::test_utils as contract_utils;
    use contracts::uninitialized_account::UninitializedAccount;
    use evm::model::account::{Account, AccountType, AccountTrait};
    use evm::model::contract_account::{ContractAccountTrait};
    use evm::model::eoa::EOATrait;
    use evm::model::{Event, Transfer, Address};
    use evm::state::{State, StateTrait, StateInternalTrait};
    use evm::tests::test_utils;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::EthAddress;
    use starknet::testing::set_contract_address;
    use utils::helpers::compute_starknet_address;

    #[test]
    #[available_gas(200000000)]
    fn test_get_account_when_not_present() {
        let mut state: State = Default::default();
        // Transfer native tokens to sender
        let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
        let evm_address: EthAddress = test_utils::evm_address();
        let starknet_address = compute_starknet_address(
            kakarot_core.contract_address.into(),
            evm_address,
            UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
        );
        let expected_type = AccountType::Unknown;
        let expected_account = Account {
            account_type: expected_type,
            address: Address { evm: evm_address, starknet: starknet_address },
            code: Default::default().span(),
            nonce: 0,
            selfdestruct: false
        };

        let account = state.get_account(evm_address);

        assert(account == expected_account, 'Account mismatch');
        assert(state.accounts.contextual_keyset.len() == 1, 'Account not written in context');
    }


    #[test]
    #[available_gas(200000000)]
    fn test_get_account_when_present() {
        let mut state: State = Default::default();
        let deployer = test_utils::kakarot_address();
        set_contract_address(deployer);

        let evm_address: EthAddress = test_utils::evm_address();
        let starknet_address = compute_starknet_address(
            deployer.into(), evm_address, UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
        );
        let expected_type = AccountType::ContractAccount;
        let expected_account = Account {
            account_type: expected_type,
            address: Address { evm: evm_address, starknet: starknet_address },
            code: array![0xab, 0xcd, 0xef].span(),
            nonce: 1,
            selfdestruct: false
        };

        state.set_account(expected_account);
        let account = state.get_account(evm_address);

        assert(account == expected_account, 'Account mismatch');
        assert(state.accounts.contextual_keyset.len() == 1, 'Account not written in context');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_write_read_cached_storage() {
        let mut state: State = Default::default();
        let evm_address: EthAddress = test_utils::evm_address();
        let key = 10;
        let value = 100;

        state.write_state(evm_address, key, value);
        let read_value = state.read_state(evm_address, key).unwrap();

        assert(value == read_value, 'Storage mismatch');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_read_state_from_sn_storage() {
        // Transfer native tokens to sender
        let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
        let evm_address: EthAddress = test_utils::evm_address();
        let mut ca_address = contract_utils::deploy_contract_account(evm_address, array![].span());

        let mut state: State = Default::default();
        let key = 10;
        let value = 100;
        let account = Account {
            account_type: AccountType::ContractAccount,
            address: ca_address,
            code: array![0xab, 0xcd, 0xef].span(),
            nonce: 1,
            selfdestruct: false
        };
        account.store_storage(key, value);

        let read_value = state.read_state(evm_address, key).unwrap();

        assert(value == read_value, 'Storage mismatch');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_add_event() {
        let mut state: State = Default::default();
        let event = Event { keys: array![100, 200], data: array![0xab, 0xde] };

        state.add_event(event.clone());

        assert(state.events.contextual_logs.len() == 1, 'Event not added');
        assert(state.events.contextual_logs[0].clone() == event, 'Event mismatch');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_add_transfer() {
        //Given
        let mut state: State = Default::default();
        let deployer = test_utils::kakarot_address();
        set_contract_address(deployer);

        let sender_evm_address = test_utils::evm_address();
        let sender_starknet_address = compute_starknet_address(
            deployer.into(),
            sender_evm_address,
            UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
        );
        let sender = Address { evm: sender_evm_address, starknet: sender_starknet_address };
        let recipient_evm_address = test_utils::other_evm_address();
        let recipient_starknet_address = compute_starknet_address(
            deployer.into(),
            recipient_evm_address,
            UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
        );
        let recipient = Address {
            evm: recipient_evm_address, starknet: recipient_starknet_address
        };
        let transfer = Transfer { sender, recipient, amount: 100 };
        // Write user balances in cache to avoid fetching from SN storage
        state.write_balance(sender.evm, 300);
        state.write_balance(recipient.evm, 0);

        // When
        state.add_transfer(transfer).unwrap();

        // Then, transfer appended to log and cached balances updated
        assert(state.transfers.contextual_logs.len() == 1, 'Transfer not added');
        assert(*state.transfers.contextual_logs[0] == transfer, 'Transfer mismatch');

        assert(state.read_balance(sender.evm).unwrap() == 200, 'Sender balance mismatch');
        assert(state.read_balance(recipient.evm).unwrap() == 100, 'Recipient balance mismatch');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_read_balance_cached() {
        let mut state: State = Default::default();
        let deployer = test_utils::kakarot_address();
        let evm_address: EthAddress = test_utils::evm_address();
        let starknet_address = compute_starknet_address(
            deployer.into(), evm_address, UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
        );
        let address = Address { evm: evm_address, starknet: starknet_address };

        let balance = 100;

        state.write_balance(address.evm, balance);
        let read_balance = state.read_balance(address.evm).unwrap();

        assert(balance == read_balance, 'Balance mismatch');
    }


    #[test]
    #[available_gas(200000000)]
    fn test_read_balance_from_storage() {
        // Transfer native tokens to sender
        let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
        let evm_address: EthAddress = test_utils::evm_address();
        let eoa_account = EOATrait::deploy(evm_address).expect('sender deploy failed');
        // Transfer native tokens to sender - we need to set the contract address for this
        set_contract_address(contract_utils::constants::ETH_BANK());
        IERC20CamelDispatcher { contract_address: native_token.contract_address }
            .transfer(eoa_account.starknet, 10000);
        // Revert back to contract_address = kakarot for the test
        set_contract_address(kakarot_core.contract_address);
        let mut state: State = Default::default();
        let read_balance = state.read_balance(evm_address).unwrap();

        assert(read_balance == 10000, 'Balance mismatch');
    }

    #[test]
    #[available_gas(200000000)]
    fn test_commit_and_clear_context() {
        let mut state: State = Default::default();
        let evm_address: EthAddress = test_utils::evm_address();
        let key = 100;
        let value = 1000;

        state.write_state(evm_address, key, value);
        state.commit_context();

        assert(
            state.accounts_storage.contextual_keyset.len() == 0, 'Contextual keyset not cleared'
        );
        assert(state.accounts_storage.transactional_keyset.len() == 1, 'tx keyset not updated');

        state.clear_context();

        assert(
            state.accounts_storage.contextual_keyset.len() == 0, 'Contextual keyset not cleared'
        );
        assert(state.accounts_storage.transactional_keyset.len() == 1, 'tx keyset should remain');
    }
}
