use core::starknet::EthAddress;
use core::starknet::secp256_trait::Signature;
use crate::eth_transaction::common::{TxKind, TxKindTrait};
use crate::eth_transaction::eip1559::{TxEip1559, TxEip1559Trait};
use crate::eth_transaction::eip2930::{AccessListItem, TxEip2930};
use crate::eth_transaction::legacy::TxLegacy;
use crate::eth_transaction::tx_type::{TxType};


#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub enum Transaction {
    /// Legacy transaction (type `0x0`).
    ///
    /// Traditional Ethereum transactions, containing parameters `nonce`, `gasPrice`, `gasLimit`,
    /// `to`, `value`, `data`, `v`, `r`, and `s`.
    ///
    /// These transactions do not utilize access lists nor do they incorporate EIP-1559 fee market
    /// changes.
    #[default]
    Legacy: TxLegacy,
    /// Transaction with an [`AccessList`] ([EIP-2930](https://eips.ethereum.org/EIPS/eip-2930)),
    /// type `0x1`.
    ///
    /// The `accessList` specifies an array of addresses and storage keys that the transaction
    /// plans to access, enabling gas savings on cross-contract calls by pre-declaring the accessed
    /// contract and storage slots.
    Eip2930: TxEip2930,
    /// A transaction with a priority fee ([EIP-1559](https://eips.ethereum.org/EIPS/eip-1559)),
    /// type `0x2`.
    ///
    /// Unlike traditional transactions, EIP-1559 transactions use an in-protocol, dynamically
    /// changing base fee per gas, adjusted at each block to manage network congestion.
    ///
    /// - `maxPriorityFeePerGas`, specifying the maximum fee above the base fee the sender is
    ///   willing to pay
    /// - `maxFeePerGas`, setting the maximum total fee the sender is willing to pay.
    ///
    /// The base fee is burned, while the priority fee is paid to the miner who includes the
    /// transaction, incentivizing miners to include transactions with higher priority fees per
    /// gas.
    Eip1559: TxEip1559,
}

#[generate_trait]
pub impl _Transasction of TransactionTrait {
    /// Get `chain_id`.
    fn chain_id(self: @Transaction) -> Option<u64> {
        match (*self) {
            Transaction::Legacy(tx) => tx.chain_id,
            Transaction::Eip2930(TxEip2930 { chain_id, .. }) |
            Transaction::Eip1559(TxEip1559 { chain_id, .. }) => Option::Some(chain_id),
        }
    }

    /// Gets the transaction's [`TxKind`], which is the address of the recipient or
    /// [`TxKind::Create`] if the transaction is a contract creation.
    fn kind(self: @Transaction) -> TxKind {
        match (*self) {
            Transaction::Legacy(TxLegacy { to, .. }) | Transaction::Eip2930(TxEip2930 { to, .. }) |
            Transaction::Eip1559(TxEip1559 { to, .. }) => to,
        }
    }

    /// Get the transaction's address of the contract that will be called, or the address that will
    /// receive the transfer.
    ///
    /// Returns `None` if this is a `CREATE` transaction.
    fn to(self: @Transaction) -> Option<EthAddress> {
        self.kind().to()
    }

    /// Get the transaction's type
    fn transaction_type(self: @Transaction) -> TxType {
        match (*self) {
            Transaction::Legacy(_) => TxType::Legacy,
            Transaction::Eip2930(_) => TxType::Eip2930,
            Transaction::Eip1559(_) => TxType::Eip1559,
        }
    }

    /// Gets the transaction's value field.
    fn value(self: @Transaction) -> u256 {
        match (*self) {
            Transaction::Legacy(TxLegacy { value, .. }) |
            Transaction::Eip2930(TxEip2930 { value, .. }) |
            Transaction::Eip1559(TxEip1559 { value, .. }) => value,
        }
    }

    /// Get the transaction's nonce.
    fn nonce(self: @Transaction) -> u64 {
        match (*self) {
            Transaction::Legacy(TxLegacy { nonce, .. }) |
            Transaction::Eip2930(TxEip2930 { nonce, .. }) |
            Transaction::Eip1559(TxEip1559 { nonce, .. }) => nonce,
        }
    }

    /// Returns the [`AccessList`] of the transaction.
    ///
    /// Returns `None` for legacy transactions.
    fn access_list(self: @Transaction) -> Option<Span<AccessListItem>> {
        match (*self) {
            Transaction::Eip2930(TxEip2930 { access_list, .. }) |
            Transaction::Eip1559(TxEip1559 { access_list, .. }) => Option::Some(access_list),
            _ => Option::None,
        }
    }

    /// Get the gas limit of the transaction.
    fn gas_limit(self: @Transaction) -> u64 {
        match (*self) {
            Transaction::Legacy(TxLegacy { gas_limit, .. }) |
            Transaction::Eip2930(TxEip2930 { gas_limit, .. }) |
            Transaction::Eip1559(TxEip1559 { gas_limit, .. }) => gas_limit.try_into().unwrap(),
        }
    }

    /// Max fee per gas for eip1559 transaction, for legacy transactions this is `gas_price`.
    fn max_fee_per_gas(self: @Transaction) -> u128 {
        match (*self) {
            Transaction::Eip1559(TxEip1559 { max_fee_per_gas, .. }) => max_fee_per_gas,
            Transaction::Legacy(TxLegacy { gas_price, .. }) |
            Transaction::Eip2930(TxEip2930 { gas_price, .. }) => gas_price,
        }
    }

    /// Max priority fee per gas for eip1559 transaction, for legacy and eip2930 transactions this
    /// is `None`
    fn max_priority_fee_per_gas(self: @Transaction) -> Option<u128> {
        match (*self) {
            Transaction::Eip1559(TxEip1559 { max_priority_fee_per_gas,
            .. }) => Option::Some(max_priority_fee_per_gas),
            _ => Option::None,
        }
    }

    /// Return the max priority fee per gas if the transaction is an EIP-1559 transaction, and
    /// otherwise return the gas price.
    ///
    /// # Warning
    ///
    /// This is different than the `max_priority_fee_per_gas` method, which returns `None` for
    /// non-EIP-1559 transactions.
    fn priority_fee_or_price(self: @Transaction) -> u128 {
        match (*self) {
            Transaction::Eip1559(TxEip1559 { max_priority_fee_per_gas,
            .. }) => max_priority_fee_per_gas,
            Transaction::Legacy(TxLegacy { gas_price, .. }) |
            Transaction::Eip2930(TxEip2930 { gas_price, .. }) => gas_price,
        }
    }

    /// Returns the effective gas price for the given base fee.
    ///
    /// If the transaction is a legacy or EIP2930 transaction, the gas price is returned.
    fn effective_gas_price(self: @Transaction, base_fee: Option<u128>) -> u128 {
        match (*self) {
            Transaction::Legacy(tx) => tx.gas_price,
            Transaction::Eip2930(tx) => tx.gas_price,
            Transaction::Eip1559(tx) => tx.effective_gas_price(base_fee)
        }
    }

    /// Get the transaction's input field.
    fn input(self: @Transaction) -> Span<u8> {
        match (*self) {
            Transaction::Legacy(tx) => tx.input,
            Transaction::Eip2930(tx) => tx.input,
            Transaction::Eip1559(tx) => tx.input,
        }
    }
}

/// Signed transaction.
#[derive(Copy, Drop, Debug, PartialEq)]
pub struct TransactionSigned {
    /// Transaction hash
    pub hash: u256,
    /// The transaction signature values
    pub signature: Signature,
    /// Raw transaction info
    pub transaction: Transaction,
}
