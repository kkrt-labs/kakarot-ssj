# Storing Contract Bytecode

The bytecode is the compiled version of your contract, and it is what the
Kakarot EVM will execute when you call the contract. As Kakarot is developped on
top of Starknet, you cannot really "deploy" an EVM contract on Kakarot: what
actually happens is that the EVM bytecode of your contract is stored on the
blockchain, and the Kakarot EVM will be able to load it when you want to execute
it.

There are several different ways to store the bytecode of a contract, and this
document will provide a quick overview of the different options, to choose the
most optimized one for our use case. The three main ways of handling contract
bytecode are:

- Storing the bytecode inside a storage variable, using Ethereum as an L1 data
  availability layer.
- Storing the bytecode inside a storage variable, using another data
  availability layer.
- Storing the bytecode directly in the contract code, not being a part of the
  contract's storage.

These three solutions all have their pros and cons, and we will go over them in
the following sections.

## Foreword: Data availability

In Validity Rollups, verifying the validity proof on L1 is sufficient to
guarantee the validity of a transaction execution on L2, with no need to have
the detailed transaction information sent to Ethereum.

However, in order to allow the independent verification of the L2 chain's state
and prevent malicious operators from censoring or freezing the chain, some
amount of data is still required to be posted on a Data Availability (DA) layer
to make the Starknet state available, even in the case where the operator
suddenly ceases operations. Data availability refers to the fact that a user can
always reconstruct the state of the rollup by deriving its current state from
the data posted by the rollup operator.

Without this, users would not be able to query an L2 contract's state in case
the operator becomes unavailable. It provides users the security of knowing that
if the Starknet sequencer ever stops functioning, they can prove custody of
their funds using the data posted on the DA Layer. If that DA Layer is Ethereum
itself, then they inherit from Ethereum's security guarantees.

## Using Ethereum as a DA Layer

Starknet currently uses Ethereum as its DA Layer. Each state update verified
on-chain is accompanied by the state diff between the previous and new state,
sent as calldata to Ethereum, allowing anyone that observes Ethereum to
reconstruct the current state of Starknet. This security comes with a
significant price, as the publication of state diffs on Ethereum accounted for
[over 93% of the transaction fees paid on Starknet](https://community.starknet.io/t/volition-hybrid-data-availability-solution/97387).

The first choice when it comes to storing contract bytecode is to store it as a
regular storage variable, whose state diff is posted on Ethereum acting as the
DA Layer. Following the design choices made in
[Contract Storage](./contract_storage.md), deploying a new contract on Kakarot
would not result in the deployment of a contract on Starknet, but rather in the
storage of the contract bytecode in a storage variable of the KakarotCore
contract.

In this situation the following data would reach L1:

- The KakarotCore contract address
- The number of updated keys in that contract
- The keys to update
- The new values for these keys

On Starknet, the associated storage update fee for a transaction updating $n$
unique contracts and $m$ unique keys is:

$$ gas\ price \cdot c_w \cdot (2n + 2m) $$

where $c_w$ is the calldata cost (in gas) per 32-byte word.

In our case, we would update one single contract (KakarotCore), and update $m$
keys, where $m = B / 16$ with $B$ the size of the bytecode to store.

<!-- TODO: verify if we can pack bytecode 31bytes by 31bytes instead of 16 by 16, to save 15 bytes per storage variable, and thus reduce the number of keys stored -->

Considering a gas price of 34 gwei (average gas price in 2023, according to
[Etherscan](https://etherscan.io/chart/gasprice)), and a calldata cost of 16 per
byte and the size of a typical ERC20 contract being 2174 bytes, we would have
have $m = 136$. The associated storage update fee would be:

$$ fee = 34 \cdot (16 \cdot 32) \cdot (2 + 272) = 4,769,792 \text{ gwei}$$

## Using Starknet's volition mechanism

Volition is a hybrid data availability solution, providing the ability to choose
the data availability layer used for contracts data. It allows users to choose
between using Ethereum as a DA Layer, or using Starknet itself as a DA Layer.
The security of state transitions, verified by STARK proofs on L1, remains the
same in both L2 and L1 data availability modes - the difference lies in the data
availability guarantees. When a state transition is verified on L1, we are
ensured that the state update is correct - however, we don't know on L1 what the
actual state of the L2 is. By posting state diffs on L1, we can reconstruct the
current state of Starknet from the ground up, but this comes has a significant
cost.

![Volition](volition.png)

Volition will allow developers to choose whether data will be stored in the L1DA
or L2DA mode, making it possible to store data on L2, which is a lot less
expensive than storing it on L1. Depending on the data stored, it can be
interesting if the cost associated to storing the data on L1 is higher than the
intrinsic value of the data itself. For examples, an Volition-ERC20 token
standard would have two different balances stored, one on L1DA for maxmial
security (e.g. you would keep most of your assets in this balance), and one on
L2DA for lower security, which would be used to reduce the fees associated to
small transactions.

In our case, we would store the contract bytecode in a storage variable that is
settled on the L2DA instead of the L1DA. This would make contract deployment
extremely cheap on Kakarot, as we will save the cost of posting the state diff
associated to the update of our stored bytecode on Ethereum.

### Associated Risks

There are some risks that must be considered when using Volition. Consider the
case of an attack by a majority of malicious sequencers colluding who decide to
not share a change in the L2DA with other sequencers and full nodes. Once the
attack is finished, the honest sequencers won't have the data needed to
reconstruct and compute the new root of the L2DA. In a such situation, not only
the L2DA is not accessible anymore, but any execution relying on L2DA will not
be executable and provable anymore, as sequencers won't have access the the L2DA
state.

Even though this event is unlikely to happen, it remains a possibility that must
be taken into account as L2DA is less secure than L1DA. If an event like this
were ever to happen, then the stored bytecode would be lost, and the deployed
contract would not be executable anymore.

> Note: While we could potentially use Volition to store the bytecode on L2DA in
> the future, this is not possible at the moment, as Volition is not yet
> implemented on Starknet.

## Storing the EVM bytecode in the Cairo contract code

The last option is to store the EVM bytecode directly in the Cairo contract
code. This has the advantage of also being cheap, as this data is not posted on
L1.

On Starknet, there is a distinction between classes which is the definition of a
contract containing the Cairo bytecode, and contracts which are instances of
classes. When you declare a contract on Starknet, its information is added to
the
[Classes Tree](https://docs.starknet.io/documentation/architecture_and_concepts/Network_Architecture/starknet-state/#classes_tree),
which encodes informations about the existing classes in the state of Starknet
by mapping class hashes to their. This class tree is itself a part of the
Starknet State Commitment, which is verified on Ethereum during state updates.

Implementing this solution would require us to declare a new class everytime a
contract is deployed using Kakarot. This new class would contain the EVM
bytecode of the contract, exposed inside a view function that would return the
entire bytecode when queried. To achieve that, we would need to have the RPC
craft a custom Starknet contract that would contain this EVM bytecode, and
declare it on Starknet - which is not ideal from security perspectives.
