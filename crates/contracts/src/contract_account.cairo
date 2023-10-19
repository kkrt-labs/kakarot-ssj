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

#[derive(Copy, Drop)]
struct ContractAccount {
    evm_address: EthAddress,
//TODO: add valid jumps as a field for ContractAccount
// valid_jumps: LegacyMap<usize, bool>
}

#[generate_trait]
impl ContractAccountImpl of ContractAccountTrait {
    /// Creates a new ContractAccount instance from the given `evm_address`.
    fn new(evm_address: EthAddress) -> ContractAccount {
        ContractAccount { evm_address: evm_address, }
    }

    /// Returns the nonce of a contract account.
    /// # Arguments
    /// * `self` - The contract account instance
    fn nonce(self: @ContractAccount) -> u64 {
        let storage_address = compute_storage_base_address(
            selector!("contract_account_nonce"), array![(*self.evm_address).into()].span()
        );
        Store::<u64>::read(0, storage_address).unwrap()
    }

    /// Increments the nonce of a contract account.
    /// The new nonce is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_nonce"), evm_address), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The contract account instance
    fn increment_nonce(ref self: ContractAccount) {
        let storage_address = compute_storage_base_address(
            selector!("contract_account_nonce"), array![self.evm_address.into()].span()
        );
        let nonce = Store::<u64>::read(0, storage_address).unwrap();
        Store::<u64>::write(0, storage_address, nonce + 1);
    }

    /// Returns the balance of a contract account.
    /// * `self` - The contract account instance
    fn balance(self: @ContractAccount) -> u256 {
        let storage_address = compute_storage_base_address(
            selector!("contract_account_balance"), array![(*self.evm_address).into()].span()
        );
        Store::<u256>::read(0, storage_address).unwrap()
    }

    /// Sets the balance of a contract account.
    /// The new balance is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_balance"), evm_address), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The contract account instance
    /// * `balance` - The new balance
    fn set_balance(ref self: ContractAccount, balance: u256) {
        let storage_address = compute_storage_base_address(
            selector!("contract_account_balance"), array![self.evm_address.into()].span()
        );
        Store::<u256>::write(0, storage_address, balance);
    }

    /// Returns the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    fn get_key(self: @ContractAccount, key: u256) -> u256 {
        let storage_address = compute_storage_base_address(
            selector!("contract_account_storage_keys"),
            array![(*self.evm_address).into(), key.low.into(), key.high.into()].span()
        );
        Store::<u256>::read(0, storage_address).unwrap()
    }

    /// Sets the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The contract account instance
    /// * `key` - The key to set
    /// * `value` - The value to set
    fn set_key(ref self: ContractAccount, key: u256, value: u256) {
        let storage_address = compute_storage_base_address(
            selector!("contract_account_storage_keys"),
            array![self.evm_address.into(), key.low.into(), key.high.into()].span()
        );
        Store::<u256>::write(0, storage_address, value);
    }

    /// Stores the EVM bytecode of a contract account in Kakarot Core's contract storage.  The bytecode is first packed
    /// into a ByteArray and then stored in the contract storage.
    /// # Arguments
    /// * `evm_address` - The EVM address of the contract account
    /// * `bytecode` - The bytecode to store
    fn store_bytecode(ref self: ContractAccount, bytecode: Span<u8>) {
        let packed_bytecode: ByteArray = ByteArrayExTrait::from_bytes(bytecode);
        // data_address is h(h(sn_keccak("contract_account_bytecode")), evm_address)
        let data_address = compute_storage_base_address(
            selector!("contract_account_bytecode"), array![self.evm_address.into()].span()
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
        >::write(
            0, storage_base_address_from_felt252(pending_word_addr), packed_bytecode.pending_word
        );
        Store::<
            usize
        >::write(
            0,
            storage_base_address_from_felt252(pending_word_len_addr),
            packed_bytecode.pending_word_len
        );
        stored_list.from_span(packed_bytecode.data.span());
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a ByteArray.
    /// # Arguments
    /// * `self` - The Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    fn load_bytecode(self: @ContractAccount) -> ByteArray {
        let data_address = compute_storage_base_address(
            selector!("contract_account_bytecode"), array![(*self.evm_address).into()].span()
        );
        // We start loading the full 31-byte words of bytecode data at address
        // `data_address`.  The `pending_word` and `pending_word_len` are stored at
        // address `data_address-2` and `data_address-1` respectively.
        //TODO(eni) replace with ListTrait::new() once merged in alexandria
        let list_len = Store::<usize>::read(0, data_address).unwrap();
        let mut stored_list: List<bytes31> = List {
            address_domain: 0,
            base: data_address,
            len: list_len,
            storage_size: Store::<bytes31>::size()
        };
        let pending_word_addr: felt252 = data_address.into() - 2;
        let pending_word_len_addr: felt252 = pending_word_addr + 1;

        // Read the `ByteArray` in the contract storage.
        let bytecode = ByteArray {
            data: stored_list.array(),
            pending_word: Store::<
                felt252
            >::read(0, storage_base_address_from_felt252(pending_word_addr))
                .unwrap(),
            pending_word_len: Store::<
                usize
            >::read(0, storage_base_address_from_felt252(pending_word_len_addr))
                .unwrap()
        };
        bytecode
    }

    /// Returns true if the given `offset` is a valid jump destination in the bytecode.
    /// The valid jump destinations are stored in Kakarot Core's contract storage first.
    /// # Arguments
    /// * `offset` - The offset to check
    /// # Returns
    /// * `true` - If the offset is a valid jump destination
    /// * `false` - Otherwise
    fn is_valid_jump(self: @ContractAccount, offset: usize) -> bool {
        let data_address = compute_storage_base_address(
            selector!("contract_account_valid_jumps"),
            array![(*self.evm_address).into(), offset.into()].span()
        );
        Store::<bool>::read(0, data_address).unwrap()
    }

    /// Sets the given `offset` as a valid jump destination in the bytecode.
    /// The valid jump destinations are stored in Kakarot Core's contract storage.
    /// # Arguments
    /// * `self` - The ContractAccount
    /// * `offset` - The offset to set as a valid jump destination
    fn set_valid_jump(ref self: ContractAccount, offset: usize) {
        let data_address = compute_storage_base_address(
            selector!("contract_account_valid_jumps"),
            array![self.evm_address.into(), offset.into()].span()
        );
        Store::<bool>::write(0, data_address, true);
    }
}

