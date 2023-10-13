use alexandria_storage::list::{List, ListTrait};
use core_contracts::contract_account::{store_bytecode};
use core_contracts::tests::utils::constants::EVM_ADDRESS;
use starknet::{storage_base_address_from_felt252, Store};
use utils::storage::{compute_storage_base_address};
use utils::traits::{StoreBytes31, StorageBaseAddressIntoFelt252};

#[test]
#[available_gas(20000000)]
fn test_store_bytecode_word_not_full() {
    let byte_array: Array<u8> = array![0x01, 0x02, 0x03, // 3 elements
    ];
    let evm_address = EVM_ADDRESS();
    store_bytecode(evm_address, byte_array.span());

    // Address at which the bytecode should be stored
    let data_addr = compute_storage_base_address(
        selector!("contract_account_bytecode"), array![evm_address.into()].span()
    );
    let pending_word_addr = storage_base_address_from_felt252(data_addr.into() - 2_felt252);
    let pending_word_len_addr = storage_base_address_from_felt252(data_addr.into() - 1_felt252);

    let pending_word = Store::<felt252>::read(0, pending_word_addr).unwrap();
    let pending_word_len = Store::<u32>::read(0, pending_word_len_addr).unwrap();
    let list: List<bytes31> = Store::<List<bytes31>>::read(0, data_addr).unwrap();
    let bytecode: ByteArray = ByteArray {
        data: list.array(), pending_word: pending_word, pending_word_len: pending_word_len
    };

    assert(bytecode.pending_word_len == 3, 'pending word not 3');
    assert(bytecode.pending_word == 0x010203, 'pending word not restituted');
    assert(bytecode.data.len() == 0, 'data not empty');
}


#[test]
#[available_gas(20000000)]
fn test_store_bytecode_one_word() {
    let byte_array: Array<u8> = array![
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0x10,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x1A,
        0x1B,
        0x1C,
        0x1D,
        0x1E,
        0x1F, // 31 elements
    ];
    let evm_address = EVM_ADDRESS();
    store_bytecode(evm_address, byte_array.span());

    // Address at which the bytecode should be stored
    let data_addr = compute_storage_base_address(
        selector!("contract_account_bytecode"), array![evm_address.into()].span()
    );
    let pending_word_addr = storage_base_address_from_felt252(data_addr.into() - 2_felt252);
    let pending_word_len_addr = storage_base_address_from_felt252(data_addr.into() - 1_felt252);

    let pending_word = Store::<felt252>::read(0, pending_word_addr).unwrap();
    let pending_word_len = Store::<u32>::read(0, pending_word_len_addr).unwrap();
    let list: List<bytes31> = Store::<List<bytes31>>::read(0, data_addr).unwrap();
    let bytecode: ByteArray = ByteArray {
        data: list.array(), pending_word: pending_word, pending_word_len: pending_word_len
    };

    assert(bytecode.pending_word_len == 0, 'pending word len not empty');
    assert(bytecode.pending_word == 0, 'pending word not empty');
    let mut i: u32 = 0;
    loop {
        if i == byte_array.len() {
            break;
        }
        assert(bytecode[i] == *byte_array[i], 'stored bytecode error');
        i += 1;
    }
}

#[test]
#[available_gas(20000000)]
fn test_store_bytecode_one_word_pending() {
    let byte_array: Array<u8> = array![
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0x10,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x1A,
        0x1B,
        0x1C,
        0x1D,
        0x1E,
        0x1F,
        0x20,
        0x21 // 33 elements
    ];
    let evm_address = EVM_ADDRESS();
    store_bytecode(evm_address, byte_array.span());

    // Address at which the bytecode should be stored
    let data_addr = compute_storage_base_address(
        selector!("contract_account_bytecode"), array![evm_address.into()].span()
    );
    let pending_word_addr = storage_base_address_from_felt252(data_addr.into() - 2_felt252);
    let pending_word_len_addr = storage_base_address_from_felt252(data_addr.into() - 1_felt252);

    let pending_word = Store::<felt252>::read(0, pending_word_addr).unwrap();
    let pending_word_len = Store::<u32>::read(0, pending_word_len_addr).unwrap();
    let list: List<bytes31> = Store::<List<bytes31>>::read(0, data_addr).unwrap();
    let bytecode: ByteArray = ByteArray {
        data: list.array(), pending_word: pending_word, pending_word_len: pending_word_len
    };

    assert(bytecode.pending_word_len == 2, 'pending word len not two');
    assert(bytecode.pending_word == 0x2021, 'pending word not restituted');
    let mut i: u32 = 0;
    loop {
        if i == byte_array.len() {
            break;
        }
        assert(bytecode[i] == *byte_array[i], 'stored bytecode error');
        i += 1;
    }
}
//TODO add a test with huge amount of bytecode - using SNFoundry and loading data from txt


