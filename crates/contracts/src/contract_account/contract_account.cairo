//! The Starknet contract equivalent of an EVM Contract Account
#[starknet::contract]
mod ContractAccount {
    use alexandria_storage::list::{List, ListTrait};
    use contracts::components::upgradeable::IUpgradeable;
    use contracts::components::upgradeable::upgradeable_component;
    use contracts::contract_account::interface::IContractAccount;
    use contracts::errors::{
        BYTECODE_READ_ERROR, BYTECODE_WRITE_ERROR, STORAGE_READ_ERROR, STORAGE_WRITE_ERROR,
        NONCE_READ_ERROR, NONCE_WRITE_ERROR
    };
    use contracts::uninitialized_account::interface::IUninitializedAccount;
    use hash::{HashStateTrait, HashStateExTrait};
    use poseidon::PoseidonTrait;
    use starknet::{
        ContractAddress, EthAddress, ClassHash, get_caller_address, Store,
        storage_base_address_from_felt252, StorageBaseAddress
    };
    use utils::helpers::{ByteArrayExTrait, ResultExTrait};
    use utils::storage::{compute_storage_base_address};
    use utils::traits::{StorageBaseAddressIntoFelt252, StoreBytes31};

    component!(path: upgradeable_component, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableImpl = upgradeable_component::Upgradeable<ContractState>;

    // ⚠️ The storage struct is used for simple storage variables
    // Bytecode and EVM Storage slots (bytes32 key-value pairs) are stored as low-level poseidon mappings
    #[storage]
    struct Storage {
        // evm_address, kakarot_core_address will be set by account/account.cairo::constructor
        evm_address: EthAddress,
        kakarot_core_address: ContractAddress,
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradeableEvent: upgradeable_component::Event,
    }

    #[abi(embed_v0)]
    impl ContractAccount of IContractAccount<ContractState> {
        fn kakarot_core_address(self: @ContractState) -> ContractAddress {
            self.kakarot_core_address.read()
        }

        fn evm_address(self: @ContractState) -> EthAddress {
            self.evm_address.read()
        }

        fn bytecode(self: @ContractState) -> Span<u8> {
            let data_address = storage_base_address_from_felt252(
                selector!("contract_account_bytecode")
            );
            // We start loading the full 31-byte words of bytecode data at address
            // `data_address`.  The `pending_word` and `pending_word_len` are stored at
            // address `data_address-2` and `data_address-1` respectively.
            //TODO(eni) replace with ListTrait::new() once merged in alexandria
            let list_len = Store::<usize>::read(0, data_address).expect(BYTECODE_READ_ERROR);
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
                //TODO(eni) PR alexandria to make List methods return SyscallResult
                data: stored_list.array(),
                pending_word: Store::<
                    felt252
                >::read(0, storage_base_address_from_felt252(pending_word_addr))
                    .expect(BYTECODE_READ_ERROR),
                pending_word_len: Store::<
                    usize
                >::read(0, storage_base_address_from_felt252(pending_word_len_addr))
                    .expect(BYTECODE_READ_ERROR)
            };
            bytecode.into_bytes()
        }

        fn set_bytecode(ref self: ContractState, bytecode: Span<u8>) {
            let packed_bytecode: ByteArray = ByteArrayExTrait::from_bytes(bytecode);
            // data_address is h(h(sn_keccak("contract_account_bytecode")), evm_address)
            let data_address = storage_base_address_from_felt252(
                selector!("contract_account_bytecode")
            );
            // We start storing the full 31-byte words of bytecode data at address
            // `data_address`.  The `pending_word` and `pending_word_len` are stored at
            // address `data_address-2` and `data_address-1` respectively.
            //TODO(eni) replace with ListTrait::new() once merged in alexandria
            let mut stored_list: List<bytes31> = List {
                address_domain: 0,
                base: data_address,
                len: 0,
                storage_size: Store::<bytes31>::size()
            };
            let pending_word_addr: felt252 = data_address.into() - 2;
            let pending_word_len_addr: felt252 = pending_word_addr + 1;

            // Store the `ByteArray` in the contract storage.
            Store::<
                felt252
            >::write(
                0,
                storage_base_address_from_felt252(pending_word_addr),
                packed_bytecode.pending_word
            )
                .expect(BYTECODE_WRITE_ERROR);
            Store::<
                usize
            >::write(
                0,
                storage_base_address_from_felt252(pending_word_len_addr),
                packed_bytecode.pending_word_len
            )
                .expect(BYTECODE_WRITE_ERROR);
            //TODO(eni) PR Alexandria so that from_span returns SyscallResult
            stored_list.from_span(packed_bytecode.data.span());
        }

        fn storage_at(self: @ContractState, key: u256) -> u256 {
            let storage_address = compute_storage_base_address(
                selector!("contract_account_storage_keys"),
                array![key.low.into(), key.high.into()].span()
            );
            Store::<u256>::read(0, storage_address).expect(STORAGE_READ_ERROR)
        }

        fn set_storage_at(ref self: ContractState, key: u256, value: u256) {
            let storage_address = compute_storage_base_address(
                selector!("contract_account_storage_keys"),
                array![key.low.into(), key.high.into()].span()
            );
            Store::<u256>::write(0, storage_address, value).expect(STORAGE_WRITE_ERROR);
        }

        fn nonce(self: @ContractState) -> u64 {
            let storage_address: StorageBaseAddress = storage_base_address_from_felt252(
                selector!("contract_account_nonce")
            );
            Store::<u64>::read(0, storage_address).expect(NONCE_READ_ERROR)
        }


        fn set_nonce(ref self: ContractState, new_nonce: u64) {
            let storage_address: StorageBaseAddress = storage_base_address_from_felt252(
                selector!("contract_account_nonce")
            );
            Store::<u64>::write(0, storage_address, new_nonce).expect(NONCE_WRITE_ERROR)
        }


        fn increment_nonce(ref self: ContractState) {
            let storage_address: StorageBaseAddress = storage_base_address_from_felt252(
                selector!("contract_account_nonce")
            );
            let nonce = Store::<u64>::read(0, storage_address).expect(NONCE_READ_ERROR);
            Store::<u64>::write(0, storage_address, nonce + 1).expect(NONCE_WRITE_ERROR)
        }

        fn is_false_jumpdest(self: @ContractState, offset: usize) -> bool {
            panic_with_felt252('unimplemented')
        }


        fn set_false_positive_jumpdest(ref self: ContractState, offset: usize) {
            panic_with_felt252('unimplemented')
        }


        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(
                get_caller_address() == self.kakarot_core_address.read(),
                'Caller not Kakarot Core address'
            );
            self.upgradeable.upgrade_contract(new_class_hash);
        }
    }
}
