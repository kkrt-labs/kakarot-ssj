use starknet::{
    StorageBaseAddress, StorageAddress, storage_address_from_base, storage_address_try_from_felt252,
    storage_base_address_from_felt252
};
use test::test_utils::{assert_eq, assert_ne};
use utils::traits::{StorageBaseAddressPartialEq};

#[test]
fn test_eq_storage_base_address() {
    let val_1 = storage_base_address_from_felt252(0x01);

    assert_eq(@val_1, @val_1, 'expected equality')
}

#[test]
fn test_ne_storage_base_address() {
    let val_1 = storage_base_address_from_felt252(0x01);
    let val_2 = storage_base_address_from_felt252(0x02);

    assert_ne(@val_1, @val_2, 'expected inequality')
}
