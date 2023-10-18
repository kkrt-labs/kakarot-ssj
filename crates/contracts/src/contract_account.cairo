//! Contract Account related functions, including bytecode storage

use alexandria_storage::list::{List, ListTrait};
use hash::{HashStateTrait, HashStateExTrait};
use poseidon::PoseidonTrait;
use starknet::{
    StorageBaseAddress, storage_base_address_from_felt252, Store, EthAddress, SyscallResult,
    storage_write_syscall, storage_address_from_base, storage_read_syscall,
    storage_address_from_base_and_offset
};
use utils::helpers::{ByteArrayExTrait};
use utils::storage::{compute_storage_base_address};
use utils::traits::{StorageBaseAddressIntoFelt252, StoreBytes31};

/// Stores the EVM bytecode of a contract account in Kakarot Core's contract storage.  The bytecode is first packed
/// into a ByteArray and then stored in the contract storage.
/// # Arguments
/// * `evm_address` - The EVM address of the contract account
/// * `bytecode` - The bytecode to store
fn store_bytecode(evm_address: EthAddress, bytecode: Span<u8>) {
    let packed_bytecode: ByteArray = ByteArrayExTrait::from_bytes(bytecode);
    // data_address is h(h(sn_keccak("contract_account_bytecode")), evm_address)
    let data_address = compute_storage_base_address(
        selector!("contract_account_bytecode"), array![evm_address.into()].span()
    );
    // We start storing the full 31-byte words of bytecode data at address
    // `data_address`.  The `pending_word` and `pending_word_len` are stored at
    // address `data_address-2` and `data_address-1` respectively.
    //TODO(eni) replace with ListTrait::new() once merged in alexandria
    let mut stored_list: List<bytes31> = List {
        address_domain: 0, base: data_address, len: 0, storage_size: Store::<bytes31>::size()
    };
    let pending_word_addr: felt252 = data_address.into() - 2;
    let pending_word_len_addr: felt252 = pending_word_addr + 1;

    // Store the `ByteArray` in the contract storage.
    Store::<
        felt252
    >::write(0, storage_base_address_from_felt252(pending_word_addr), packed_bytecode.pending_word);
    Store::<
        usize
    >::write(
        0,
        storage_base_address_from_felt252(pending_word_len_addr),
        packed_bytecode.pending_word_len
    );
    stored_list.from_span(packed_bytecode.data.span());
}
