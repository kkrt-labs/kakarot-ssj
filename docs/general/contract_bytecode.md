# Bytecode Storage Methods for Kakarot on Starknet

The bytecode is the compiled version of a contract, and it is what the Kakarot
EVM will execute when a contract is called. As Kakarot's state is embedded into
the Starknet chain it is deployed on, contracts are not actually "deployed" on
Kakarot: instead, the EVM bytecode of the deployed contract is first executed,
and the returned data is then stored on-chain at a particular storage address in
the KakarotCore contract storage. The Kakarot EVM will be able to load this
bytecode by querying its own storage when a user interacts with this contract.

```mermaid
flowchart TD
    A[RPC call] --> |"eth_sendTransaction (contract deployment)"| B(KakarotCore)
    B --> C[Execute initialization code]
    C -->|Set account code to return data| D[Store account code in KakarotCore storage]

    X[RPC call] --> |"eth_sendTransaction (contract interaction)"| Y(KakarotCore)
    Y --> Z[Load account code from KakarotCore storage]
    Z --> ZZ[Execute bytecode]
```

There are several different ways to store the bytecode of a contract, and this
document will provide a quick overview of the different options, to choose the
most optimized one for this use case. The three main ways of handling contract
bytecode that were considered are:

- Storing the bytecode inside a storage variable, using Ethereum as an L1 data
  availability layer.
- Storing the bytecode inside a storage variable, using another data
  availability layer.
- Storing the bytecode directly in the contract code, not as a part of the
  contract's storage.

These three solutions all have their respective pros and cons, which will be
discussed in the following sections.

## Foreword: Data availability

In Validity Rollups, verifying the validity proof on L1 is sufficient to
guarantee the validity of a transaction execution on L2, without needing the
detailed transaction information to be sent to Ethereum.

However, to allow independent verification of the L2 chain's state and prevent
malicious operators from censoring or freezing the chain, some amount of data is
still required to be posted on a Data Availability (DA) layer. This makes the
Starknet state available even if the operator suddenly ceases operations. Data
availability ensures that users can always reconstruct the state of the rollup
by deriving its current state from the data posted by the rollup operator.

Without this, users would not be able to query an L2 contract's state if the
operator becomes unavailable. It provides users the security of knowing that if
the Starknet sequencer ever stops functioning, they can prove custody of their
funds using the data posted on the DA Layer. If that DA Layer is Ethereum
itself, then Ethereum's security guarantees are inherited.

## Different approaches to storing contract bytecode

### Using Ethereum as a DA Layer

Starknet currently uses Ethereum as its DA Layer. Each state update verified
on-chain is accompanied by the state diff between the previous and new state,
sent as calldata to Ethereum. This allows anyone observing Ethereum to
reconstruct the current state of Starknet. This security comes with a
significant price, as the publication of state diffs on Ethereum accounted for
[over 93% of the transaction fees paid on Starknet](https://community.starknet.io/t/volition-hybrid-data-availability-solution/97387).

The first choice when storing contract bytecode is to store it as a regular
storage variable, with its state diff posted on Ethereum acting as the DA Layer.
As outlined in our [Contract Storage](./contract_storage.md) design, deploying a
new contract on Kakarot would not result in the deployment of a contract on
Starknet, but rather in the storage of the contract bytecode in a storage
variable of the KakarotCore contract.

In this case, the following data would reach L1:

- The KakarotCore contract address
- The number of updated keys in that contract
- The keys to update
- The new values for these keys

On Starknet, the associated storage update fee for a transaction updating $n$
unique contracts and $m$ unique keys is:

$$ gas\ price \cdot c_w \cdot (2n + 2m) $$

where $c_w$ is the calldata cost (in gas) per 32-byte word.

In this case, one single contract (KakarotCore) would be updated, with $m$ keys,
where $m = (B / 31) + 2$ and $B$ is the size of the bytecode to store (see
[implementation details](./contract_bytecode.md#implementation-details)).

Considering a gas price of 34 gwei (average gas price in 2023, according to
[Etherscan](https://etherscan.io/chart/gasprice)),a calldata cost of 16 per byte
and the size of a typical ERC20 contract size of 2174 bytes, we would have
$m = 72$. The associated storage update fee would be:

$$ fee = 34 \cdot (16 \cdot 32) \cdot (2 + 144) = 2,541,468 \text{ gwei}$$

This is the solution that was chosen for Kakarot; but there are other options
that could be considered.

### Using Starknet's volition mechanism

Volition is a hybrid data availability solution, providing the ability to choose
the data availability layer used for contract data. It allows users to choose
between using Ethereum as a DA Layer, or using Starknet itself as a DA Layer.
The security of state transitions, verified by STARK proofs on L1, is the same
for both L2 and L1 data availability modes. The difference is in the data
availability guarantees. When a state transition is verified on L1, its
correctness is ensured - however, the actual state of the L2 is not known on L1.
By posting state diffs on L1, the current state of Starknet can be reconstructed
from the beginning, but this has a significant cost.

![Volition](volition.png)

Volition will allow developers to choose whether data will be stored in L1DA or
L2DA mode. This makes it possible to store data on L2, which is much less
expensive than storing it on L1. Depending on the data stored, it can be
advantageous if the cost of storing it on L1 is higher than its intrinsic value.
For example, a Volition-ERC20 token standard could have two balances - one on
L1DA for maximal security (major assets), and one on L2DA for lower
security/fees (small transactions).

In this case, the contract bytecode could be stored in a storage variable
settled on L2DA instead of L1DA. This would make Kakarot contract deployment
extremely cheap, by avoiding the cost of posting bytecode state diffs to
Ethereum.

#### Associated Risks

Some risks must be considered when using Volition. If a majority of malicious
sequencers collude and decide to not share an L2DA change with other
sequencers/full nodes, once the attack ends, the honest sequencers won't have
the data to reconstruct and compute the new L2DA root. In this case, not only is
the L2DA inaccessible, but any execution relying on L2DA will become unprovable,
since sequencers lack the correct L2DA state.

While unlikely, this remains a possibility to consider since L2DA is less secure
than L1DA. If it happened, the stored bytecode would be lost and the deployed
contract unexecutable.

> Note: While Volition could potentially store bytecode on L2DA in the future,
> this is not currently possible as Volition is not yet implemented on Starknet.

### Storing the EVM bytecode in the Cairo contract code

The last option is to store the EVM bytecode directly in the Cairo contract
code. This has the advantage of also being cheap, as this data is not stored on
L1.

On Starknet, there is a distinction between classes which is the definition of a
contract containing the Cairo bytecode, and contracts which are instances of
classes. When you declare a contract on Starknet, its information is added to
the
[Classes Tree](https://docs.starknet.io/documentation/architecture_and_concepts/Network_Architecture/starknet-state/#classes_tree),
which encodes information about the existing classes in the state of Starknet by
mapping class hashes to their compiled class hash. This class tree is itself a
part of the Starknet State Commitment, which is verified on Ethereum during
state updates. The class itself is stored in the nodes (both sequencers and full
nodes) of Starknet.

To implement this, a new class would need to be declared each time a Kakarot
contract is deployed. This class would contain the contract's EVM bytecode,
exposed via a view function returning the bytecode. To do this, the RPC would
need to craft a custom Starknet contract containing the EVM bytecode in its
source code, and declare it on Starknet - not ideal for security.

## Implementation details

Kakarot uses the first solution, storing bytecode in a storage variable
committed to Ethereum. This solution is the most secure one, as it relies on
Ethereum as a DA Layer, and thus inherits from Ethereum's security guarantees,
ensuring that the bytecode of the deployed contract is always available.

A `deploy` transaction is identified by an empty `to` address. The data sent to
the KakarotCore contract when deploying a new contract will be formatted by the
RPC to pack the bytecode into 31-bytes values, and passed as an `Array<felt252>`
to the entrypoint `eth_send_transaction` of the KakarotCore contract. This
allows us to save on computation costs required to pack all byte values into the
31-bytes values that we will store in the contract storage.

The contract storage related to a deployed contract is organized as:

```rust
struct Storage {
    bytecode: LegacyMap<EthAddress, List<bytes31>>,
    pending_word: LegacyMap<EthAddress, felt252>,
    pending_word_len: LegacyMap<EthAddress, usize>,
}
```

Each deployed contract has it's own EVM address used as a key in a `LegacyMap`
type when computing the address of each storage variable. We use the `List` type
from
[Alexandria](https://github.com/keep-starknet-strange/alexandria/blob/main/src/storage/src/list.cairo)
to store the bytecode, allowing us to store up to 255 31-bytes values per
`StorageBaseAddress`. For bytecode containing more than 255 31-bytes values, the
`List` type abstracts the calculations of the next storage address used, which
is calculated by using poseidon hashes applied on `previous_address+1`.

The logic behind this storage design is to make it very easy to load the
bytecode in the EVM when we want to execute a program. We will rely on the
ByteArray type, which is a type from the core library that we can use to access
individual byte indexes in an array of packed bytes31 values. This type is
defined as:

```rust
struct ByteArray {
    // Full "words" of 31 bytes each. The first byte of each word in the byte array
    // is the most significant byte in the word.
    data: Array<bytes31>,
    // This felt252 actually represents a bytes31, with < 31 bytes.
    // It is represented as a felt252 to improve performance of building the byte array.
    // The number of bytes in here is specified in `pending_word_len`.
    // The first byte is the most significant byte among the `pending_word_len` bytes in the word.
    pending_word: felt252,
    // Should be in range [0, 30].
    pending_word_len: usize,
}
```

The rationale behind this structure is detailed in the code snippet above - but
you can notice that our stored variables reflect the fields the ByteArray type.
Once our bytecode is written in storage, we can simply load it by doing so:

```rust
 let bytecode = ByteArray {
    data: self.bytecode.read(address).array(),
    pending_word: self.pending_word.read(address),
    pending_word_len: self.pending_word_len.read(address)
};
```

After which the value of the bytecode at offset `i` can be accessed by simply
doing `bytecode[i]` when executing the bytecode instructions in the EVM.
