use core_contracts::kakarot_core::storage_address::NATIVE_TOKEN;
use hash::{HashStateTrait, HashStateExTrait};
use poseidon::PoseidonTrait;
use starknet::{
    ContractAddress, EthAddress, StorageBaseAddress, storage_base_address_from_felt252, Store
};


/// Computes the storage address for a given EVM address and an EVM storage key.
/// The storage address is computed as follows:
/// 1. Compute the hash of the EVM address and the key using Poseidon.
/// 2. Use `storage_base_address_from_felt252` to obtain the starknet storage base address.
/// Note: the storage_base_address_from_felt252 function always works for any felt - and returns the number
/// normalized into the range [0, 2^251 - 256). (x % (2^251 - 256))
/// https://github.com/starkware-libs/cairo/issues/4187
fn compute_storage_address(evm_address: EthAddress, key: u256) -> StorageBaseAddress {
    let hash = PoseidonTrait::new().update_with(evm_address).update_with(key).finalize();
    storage_base_address_from_felt252(hash)
}

fn kakarot_core_native_token() -> ContractAddress {
    // TODO THIS PR: remove unwrap and replace by graceful error handling
    let native_token_address = Store::<
        ContractAddress
    >::read(0, storage_base_address_from_felt252(NATIVE_TOKEN));
    native_token_address.unwrap()
}
