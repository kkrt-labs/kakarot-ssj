# Contract storage design

## Context

The current contract storage design in Kakarot Zero is organized as such:

- The two different kinds of EVM accounts: Externally Owned Accounts (EOA) and
  Contract Accounts (CA) are both represented by Starknet smart contracts. Each
  account is mapped to a unique Starknet contract. Each contract has its own
  storage.
- Each contract is deployed by Kakarot, and contains its own bytecode in the
  case of a smart contract (no bytecode for an EOA).
- Each contract account has external functions that can be called by Kakarot to
  modify the bytecode it stores and to read / write to its storage. This makes
  Kakarot an effective "admin" to all contracts with rights to modify their
  storage.
- SLOAD/SSTORE opcodes are used to read/write to storage and performe a
  `contract_call_syscall` to modify the storage of the "remote" contract.

However, this design has some limitations:

- We perform a syscall for each SLOAD/SSTORE, which is expensive. Given that
  only Kakarot can modify the storage of a contract, we could directly store the
  whole world state in the main Kakarot contract storage. modify the storage of
  the Kakarot main contract.
- It adds external entrypoints with admin rights to read and write from storage
  in each Kakarot contract. This is not ideal from a security perspective.
- It derives from traditional EVM design, in which execution clients store
  account states in a database backend.

## Goal

Propose a new design for contract storage that is less gas-expensive, more
secure, and easier to implement.

## Proposed solution

While Kakarot is not a traditional Ethereum Client, we can still use a design
that is similar. Traditional clients hold a state database in which the account
states are stored. We can do the same, but instead of storing the account states
in a database, we store them in the Kakarot main contract storage.

A contract’s storage on Starknet is a persistent storage space where you can
read, write, modify, and persist data. The storage is a map with $2^{251}$
slots, where each slot is a felt which is initialized to 0.

This new model doesn't expose read and write methods on Kakarot contracts.
Instead of having $n$ contracts with `write_storage` and `read_storage`
entrypoints, the only way storage can be modified is now through executing SLOAD
/ SSTORE internally.

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
$2^{251} / 44\cdot10^6 \approx 2^225$ slots per contract. Even with a
hypothetical number of 100 billion contracts, we would still have around
$2^{214}$ storage slots available per contract.

Considering the birthday paradox, the probability of a collision occurring,
given $2^{214}$ randomly chosen slots, is roughly $1/2^{107}$. This is a very
low probability, which is considered secure by today's standards. We can
therefore consider that the collision risk is negligible and that this storage
layout doesn't introduce any security risk to Kakarot. For reference, Ethereum
has 80 bits of security on its account addresses, which are 160 bits long.

### Implementation

The SSTORE and SLOAD opcodes are modified to read and write from the Kakarot
contract storage instead of the contract storage of the contract being called.
This implementation will require investigating whether we can use the component
system to avoid explicitly passing the Kakarot ContractState down to the
STORE/SLOAD opcodes, and instead have the opcodes access the Kakarot
ContractState from the component system, which would be lighter syntax-wise.

The Kakarot Storage will have a LegacyMap type. When writing to Storage, we will
hash together the address of the contract whose storage is modified, and the
storage slot address to get a unique storage address.

The code snippets below are pseudocode implementations of the proposed design.
in _kakarot.cairo_

```rust
#[storage]
struct Storage{
    account_storage: LegacyMap<ContractAddress, felt252>,
}
```

in _memory_operations.cairo_

```rust
  // SSTORE
  state.account_storage.write(starknet_address, storage_slot, value);
```

```rust
  // SLOAD
  state.account_storage.read(starknet_address, storage_slot);
```

### Reverting storage changes

The current design allows reverting storage changes by using an accumulator.
Each storage change will be stored in the accumulator, and the accumulator will
be a field of the current ExecutionContext. When a context reverts, we can
simply read the accumulator from the ExecutionContext and revert the storage
changes stored in the accumulator.
