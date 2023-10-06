use utils::traits::{StorageBaseAddressPartialEq, Felt252TryIntoStorageBaseAddress};
use starknet::{
    StorageBaseAddress, StorageAddress, storage_address_from_base, storage_address_try_from_felt252,
    storage_base_address_from_felt252
};
use test::test_utils::{assert_eq, assert_ne};

#[test]
fn test_storage_base_address_try_into_felt252() {
    let MAX_STORAGE_BASE_ADDRESS: felt252 =
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeff; // 2**251 - 257
    let res: StorageBaseAddress = MAX_STORAGE_BASE_ADDRESS.try_into().unwrap();
    let res_felt: felt252 = Into::<StorageAddress, felt252>::into(storage_address_from_base(res));
    assert(res_felt == MAX_STORAGE_BASE_ADDRESS, 'expected successfull conversion');

    let ABOVE_MAX: felt252 =
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00; // 2**251 - 257
    let res: Option<StorageBaseAddress> = ABOVE_MAX.try_into();
    assert(res.is_none(), 'expected conversion failure');
}

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
