use evm::storage::compute_storage_address;
use evm::tests::test_utils;
#[test]
#[available_gas(200000)]
fn test_compute_storage_address() {
    let key = 100;
    let evm_address = test_utils::evm_address();

    let address = compute_storage_address(evm_address, key);
// TODO: compute values externally and assert equality
// assert(address==expected, 'hash not expected value')
}
