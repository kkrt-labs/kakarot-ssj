use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use core::starknet::{
    StorageBaseAddress, storage_base_address_from_felt252, Store, EthAddress, SyscallResult,
    storage_write_syscall, storage_address_from_base, storage_read_syscall,
    storage_address_from_base_and_offset
};


/// Computes the StorageBaseAddress of a storage variable.  The address is
/// computed by applying hashing the variable selector and the keys with
/// Poseidon.
///  # Arguments
///  * `selector` - The selector of the storage variable.
///  * `keys` - The keys of the storage variable.
///  # Returns
///  * The StorageBaseAddress of the storage variable, calculated as
///    the sequential hashes of the selector and the keys.
pub fn compute_storage_base_address(
    selector: felt252, mut keys: Span<felt252>
) -> StorageBaseAddress {
    //TODO: if we want compatibility with LegacyMaps, we should use pedersen
    // it might not be required.
    let mut state = PoseidonTrait::new().update(selector);
    let hash = loop {
        match keys.pop_front() {
            Option::Some(val) => { state = state.update(*val); },
            Option::None => { break state.finalize(); }
        };
    };

    storage_base_address_from_felt252(hash)
}

#[cfg(test)]
mod tests {
    use core::starknet::{
        StorageBaseAddress, storage_base_address_from_felt252, storage_address_from_base
    };
    use utils::storage::compute_storage_base_address;

    #[test]
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
}
