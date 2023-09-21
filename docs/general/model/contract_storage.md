# Kakarot Storage

## Storage in Ethereum

The top-level data structure that holds information about the state of the
Ethereum blockchain is called the _world state_, and is a mapping of Ethereum
addresses (160-bit values) to accounts. Each Ethereum address represents an
account composed by a _nonce_, an _ether balance_, a _storage_, and a _code_. We
make the distinction between EOA (Externally Owned Accounts) that have no code
and an empty storage, and contracts that can have code and storage.

In traditional EVM clients, like Geth, the _world state_ is stored as a _trie_,
and informations about account are stored in the world state trie and can be
retrieved through queries. Each account in the world state trie is associated
with an account storage trie, which stores all of the information related to the
account. When Geth updates the storage of a contract by executing the SSTORE
opcodes, it does the following:

- It updates the `value` associated to a `key` of the storage of a contract
  deployed at a specific `address`. However, it updates a `dirtyStorage`, which
  refers to storage entries that have been modified in the current transaction
  execution.
- It tracks the storage modifications in a `journal` so that it can be reverted
  in case of a revert opcode or an exception in the transaction execution.
- At the end of the execution of a transaction, all dirty storage slots are
  copied across to `pendingStorage`, which in turn is copied across to
  `originStorage` when the trie is finally updated. This effectively updates the
  storage root of the account state.

The behavior for the SLOAD opcode is very complementary to the SSTORE opcode.
When Geth executes the SLOAD opcode, it does the following:

- It starts by doing a check on `dirtyStorage` to see if it contains a value for
  the queried key, and returns it if so.
- Otherwise, it retrieves the value from the committed account storage trie.

Since one transaction can access a storage slot multiple times, we must ensure
that the result returned is the most recent value. This is why Geth first checks
`dirtyStorage`, which is the most up-to-date state of the storage.

## Storage in Kakarot

As Kakarot is a contract that is deployed on Starknet and is not a client that
can directly manipulate a storage database, our approach differs from one of a
traditional client. We do not have a world state trie, and we do not have a
storage trie. Instead, we have access to Kakarot's contract storage on the
Starknet blockchain, that we can query using syscalls to read and update the
value of a of a storage slot.

There are two different ways of handling Storage in Kakarot.

### One storage space per Kakarot Contract

The first approach is to have one storage space per Kakarot contract. This means
that for every contract that is deployed on Kakarot, we will deploy an
underlying Starknet contract, which has its own state which can only be queried
by itself.

The current contract storage design in Kakarot Zero is organized as such:

- The two different kinds of EVM accounts - Externally Owned Accounts (EOA) and
  Contract Accounts (CA) - are both represented by Starknet smart contracts.
  Each account is mapped to a unique Starknet contract. Each contract has its
  own storage.
- Each contract is deployed by Kakarot, and contains its own bytecode in storage
  in the case of a smart contract (no bytecode for an EOA).
- Each contract account has external functions that can be called by Kakarot to
  read the bytecode it stores and to read / write to its storage. This makes
  Kakarot an effective "admin" to all contracts with rights to modify their
  storage.
- SLOAD/SSTORE opcodes are used to read/write to storage and perform a
  `contract_call_syscall` to modify the storage of the remote contract.

However, this design has some limitations:

- We perform a `call_contract_syscall` for each SLOAD/SSTORE, which is
  expensive. Given that only KakarotCore can modify the storage of a Kakarot
  contract, we could directly store the whole world state in the main Kakarot
  contract storage.
- It adds external entrypoints with admin rights to read and write from storage
  in each Kakarot contract. This is not ideal from a security perspective.
- It moves away from the traditional EVM design, in which execution clients
  store account states in a common database backend.

Therefore, we will not use this design in SSJ. We will instead use the second
design presented thereafter.

### A shared storage space for all Kakarot Contracts

The second approach is to have a single storage space for all Kakarot contracts.
While Kakarot is not a traditional Ethereum Client, we can still use a design
that is similar. Traditional clients hold a state database in which the account
states are stored. We can do the same, but instead of storing the account states
in a database, we store them in the KakarotCore contract storage. Therefore, we
do not need to deploy a Starknet contract for each Kakarot account contract,
which saves users costs related to deploying contracts.

A contract’s storage on Starknet is a persistent storage space where you can
read, write, modify, and persist data. The storage is a map with $2^{251}$
slots, where each slot is a felt which is initialized to 0.

This new model doesn't expose read and write methods on Kakarot contracts.
Instead of having $n$ contracts with `write_storage` and `read_storage`
entrypoints, the only way to update the storage of a Kakarot contract is now
through executing SLOAD / SSTORE internally to KakarotCore.

```mermaid
sequenceDiagram
    participant C as Caller
    participant K as KakarotCore
    participant M as Interpreter
    participant S as ContractState

    C->>K: Executes Kakarot contract
    K->>M: Executes Opcode (Either SSTORE or SLOAD)

    Note over K,M: If it's an SSTORE operation, it writes to Storage.
    Note over K,M: If it's an SLOAD operation, it reads from Storage.

    alt SSTORE
        M->>S: hash(starknet_address, storage_slot)
        S-->>M: Unique storage address
        M->>S: Write value at storage address
    else SLOAD
        M->>S: hash(starknet_address, storage_slot)
        S-->>M: Read value from storage address
    end

    Note over K: Each storage change is stored in accumulator for potential revert.
    Note over K: If revert happens, the accumulator from ExecutionContext is read to revert changes.

```

### Eventual security risks

According to
[an engineer from ElectricCapital](https://twitter.com/n4motto/status/1554853912074522624?s=20),
44M contracts have been deployed on Ethereum so far. If we assume that Kakarot
could reach the same number of contracts, that would leave us with a total of
$2^{251} / 44\cdot10^6 \approx 2^{225}$ slots per contract. Even with a
hypothetical number of 100 billion contracts, we would still have around
$2^{214}$ storage slots available per contract.

Considering the birthday paradox, the probability of a collision occurring,
given $2^{214}$ randomly chosen slots, is roughly $1/2^{107}$. This is a very
low probability, which is considered secure by today's standards. We can
therefore consider that the collision risk is negligible and that this storage
layout doesn't introduce any security risk to Kakarot. For reference, Ethereum
has 80 bits of security on its account addresses, which are 160 bits long.

### Tracking and reverting storage changes

This design allows reverting storage changes by using a concept similar to
Geth's journal. Each storage change will be stored in a `Journal` implemented
using a `Felt252Dict` data structure, that will associate each modified storage
address to its new value. This allows us to perform three things:

- When executing a transaction, instead of using one `storage_write_syscall` per
  SSTORE opcode, we can simply store the storage changes in this journal. At the
  end of the transaction, we can finalize all the storage writes together and
  perform only one `storage_write_syscall` per modified storage address.
- When reading from storage, we can first read from the journal to see if the
  storage slot has been modified. If it's the case, we can read the new value
  from the journal instead of performing a `storage_read_syscall`.
- If the transaction reverts, we won't need to revert the storage changes
  manually. Instead, we can simply not finalize the storage changes present in
  the journal, which can save a lot of gas.

### Implementation

The SSTORE and SLOAD opcodes are implemented to first read and write to the
`Journal` instead of directly writing to the KakarotCore contract's storage.

Using the `storage_read_syscall` and `storage_write_syscall` syscalls, we can
arbitrarily read and write to a contract's storage. Therefore, we will be able
to simply implement the SSTORE and SLOAD opcodes as follows:

```rust
  // SSTORE
  let storage_address = poseidon_hash(evm_address, storage_slot);
  self.journal.insert(storage_address, NullableTrait::new(value));
```

```rust
  // SLOAD
  let storage_address = poseidon_hash(evm_address, storage_slot);
  let value = match_nullable(self.journal.get(storage_address)) {
            FromNullableResult::Null => storage_read_syscall(storage_address),
            FromNullableResult::NotNull(value) => value.unbox(),
  }
```

```rust
  // Finalizing storage updates
  for keys in journal_keys{
    storage_write_syscall(key, journal.get(key));
  }
```

> Note: these codesnippets are pseudocode, not valid Cairo code.
