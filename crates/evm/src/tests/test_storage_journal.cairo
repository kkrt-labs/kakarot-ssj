use evm::storage_journal::{Journal, JournalTrait};
use evm::tests::test_utils;
use starknet::{Store, storage_base_address_from_felt252};

#[test]
#[available_gas(200000000)]
fn test_write_read() {
    let mut journal: Journal = Default::default();

    journal.write(test_utils::storage_base_address(), 42);
    assert(
        journal.read(test_utils::storage_base_address()).unwrap() == 42,
        'value not stored correctly'
    );
    assert(journal.local_keys.len() == 1, 'should add a key to tracking');

    journal.write(test_utils::storage_base_address(), 43);
    assert(
        journal.read(test_utils::storage_base_address()).unwrap() == 43,
        'value should have been updated'
    );
    assert(journal.local_keys.len() == 1, 'keys should not be added twice');

    // Write multiple keys
    let second_address = storage_base_address_from_felt252('second_location');
    journal.write(second_address, 1337.into());

    assert(journal.read(second_address).unwrap() == 1337, 'wrong second value');
    assert(journal.local_keys.len() == 2, 'should have two keys');

    // Verify that there was no impact on global changes
    assert(journal.global_keys.len() == 0, 'shouldnt impact global changes');
}

#[test]
#[available_gas(200000000)]
fn test_finalize_local() {
    let mut journal: Journal = Default::default();
    journal.write(test_utils::storage_base_address(), 42.into());
    journal.finalize_local();

    assert(journal.global_keys.len() == 1, 'keys should be finalized');
    assert(journal.local_keys.len() == 0, 'local keys should be reset');
    assert(
        journal.read(test_utils::storage_base_address()).unwrap() == 42, 'read should return 42'
    );

    let second_address = storage_base_address_from_felt252('second_address');
    journal.write(test_utils::storage_base_address(), 44.into());
    journal.write(second_address, 1337.into());

    journal.finalize_local();
    assert(journal.global_keys.len() == 2, 'keys should be finalized');
    assert(journal.local_keys.len() == 0, 'local keys should be reset');
    assert(
        journal.read(test_utils::storage_base_address()).unwrap() == 44, 'read should return 44'
    );
    assert(journal.read(second_address).unwrap() == 1337, 'read should return 1337');
}

#[test]
#[available_gas(200000000)]
fn test_finalize_global() {
    let mut journal: Journal = Default::default();
    let second_address = storage_base_address_from_felt252('second_address');
    // Finalize a first time the local changes
    journal.write(test_utils::storage_base_address(), 44.into());
    journal.write(second_address, 1337.into());
    journal.finalize_local();
    // Update a key and finalize it locally again
    journal.write(test_utils::storage_base_address(), 45.into());
    journal.finalize_local();

    // Finalize global to write to storage
    journal.finalize_global();

    let value1 = Store::<u256>::read(0, test_utils::storage_base_address()).unwrap();
    let value2 = Store::<u256>::read(0, second_address).unwrap();
    assert(journal.global_keys.len() == 0, 'keys should be reset');
    assert(value1 == 45, 'read should return 45');
    assert(value2 == 1337, 'read should return 1337');
}

