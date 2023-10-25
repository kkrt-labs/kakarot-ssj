use starknet::{StorageBaseAddress, storage_base_address_from_felt252, storage_address_from_base};
use utils::storage::compute_storage_base_address;

#[test]
#[available_gas(20000000)]
fn test_compute_storage_base_address() {
    let selector = selector!("my_storage_var");
    let keys = array![0x01, 0x02].span();

    let base = compute_storage_base_address(selector, keys);
    let addr = storage_address_from_base(base);
    assert(
        addr.into() == 0x07f99861f217719795b0dfa211100a10fc3c1cefaff03426ebedfc922e81bb15,
        'wrong address'
    ); // hash calculated with starknet_crypto rs crate
}
