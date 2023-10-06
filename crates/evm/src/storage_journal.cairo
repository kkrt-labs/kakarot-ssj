use nullable::{match_nullable, FromNullableResult};
use starknet::{StorageBaseAddress, Store, storage_base_address_from_felt252};
use utils::helpers::ArrayExtensionTrait;
use utils::traits::{StorageBaseAddressPartialEq, StorageBaseAddressIntoFelt252};
/// The Journal tracks the changes applied to storage during the execution of a transaction.
/// Local changes tracks the changes applied inside a single execution context.
/// Global changes tracks the changes applied in the entire transaction.
/// Upon exiting an execution context, local changes must be finalized into global changes
/// Upon exiting the transaction, global changes must be finalized into storage updates.
#[derive(Destruct, Default)]
struct Journal {
    local_changes: Felt252Dict<Nullable<u256>>,
    local_keys: Array<StorageBaseAddress>,
    global_changes: Felt252Dict<Nullable<u256>>,
    global_keys: Array<StorageBaseAddress>
}

#[generate_trait]
impl JournalImpl of JournalTrait {
    /// Reads a value from the journal. Starts by looking for the value in the local changes. If the value is not found, looks for it in the global changes.
    #[inline(always)]
    fn read(ref self: Journal, storage_address: StorageBaseAddress) -> Option<u256> {
        match match_nullable(self.local_changes.get(storage_address.into())) {
            FromNullableResult::Null => {
                match match_nullable(self.global_changes.get(storage_address.into())) {
                    FromNullableResult::Null => { Option::None },
                    FromNullableResult::NotNull(value) => { Option::Some(value.unbox()) }
                }
            },
            FromNullableResult::NotNull(value) => Option::Some(value.unbox()),
        }
    }

    /// Writes a value to the journal.
    /// Values written to the journal are not written to storage until the journal is totally finalized at the end of the transaction.
    #[inline(always)]
    fn write(ref self: Journal, storage_address: StorageBaseAddress, value: u256) {
        self.local_changes.insert(storage_address.into(), NullableTrait::new(value));
        self.local_keys.append_unique(storage_address);
    }

    /// Finalizes the local changes in the journal by copying them to the global changes and keys.
    /// Local changes are relative to a specific execution context. `finalize_local` must be called upon returning from an execution context.
    /// Dropping the tracking of local keys effectively "resets" the journal,
    /// without modifying the underlying dict. Reading from the journal will still
    /// return the local changes first, but they will never be out of sync with global
    /// changes, unless there was a modification more recently.
    fn finalize_local(ref self: Journal) {
        let mut local_keys = self.local_keys.span();
        loop {
            match local_keys.pop_front() {
                Option::Some(key) => {
                    let key = *key;
                    let value = self.local_changes.get(key.into());
                    self.global_changes.insert(key.into(), value);
                    self.global_keys.append_unique(key);
                },
                Option::None => { break; }
            }
        };
        self.local_keys = Default::default();
    }

    /// Finalizes the global changes in the journal by writing them to the storage to be stored permanently onchain.
    /// Global changes are relative the the execution of an entire transaction. `finalize_global` must be called upon finishing the transaction.
    fn finalize_global(ref self: Journal) {
        let mut global_keys = self.global_keys.span();
        loop {
            match global_keys.pop_front() {
                Option::Some(key) => {
                    let key = *key;
                    let value = self.global_changes.get(key.into());
                    match match_nullable(value) {
                        FromNullableResult::Null => {},
                        FromNullableResult::NotNull(value) => {
                            let value = value.unbox();
                            Store::write(0, key, value);
                        }
                    };
                },
                Option::None => { break; }
            }
        };
        self.global_keys = Default::default();
    }
}
