use core::starknet::EthAddress;
use core::starknet::secp256_trait::Signature;
use crate::errors::{RLPError, EthTransactionError, RLPErrorTrait, RLPHelpersErrorTrait};
use crate::eth_transaction::common::{TxKind, TxKindTrait};
use crate::eth_transaction::eip1559::{TxEip1559, TxEip1559Trait};
use crate::eth_transaction::eip2930::{AccessListItem, TxEip2930, TxEip2930Trait};
use crate::eth_transaction::legacy::TxLegacy;
use crate::eth_transaction::tx_type::{TxType};
use crate::helpers::{ByteArrayExTrait, U8SpanExTrait};
use crate::rlp::{RLPItem, RLPTrait, RLPHelpersTrait};
use crate::traits::{DefaultSignature};


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


#[derive(Copy, Drop, Debug, PartialEq)]
pub struct TransactionUnsigned {
    /// Transaction hash
    pub hash: u256,
    /// Raw transaction info
    pub transaction: Transaction,
}

#[generate_trait]
pub impl _TransactionUnsigned of TransactionUnsignedTrait {
    /// Decodes the "raw" format of transaction (similar to `eth_sendRawTransaction`).
    ///
    /// This should be used for any method that accepts a raw transaction.
    /// * `eth_send_raw_transaction`.
    ///
    /// A raw transaction is either a legacy transaction or EIP-2718 typed transaction.
    ///
    /// For legacy transactions, the format is encoded as: `rlp(tx-data)`. This format will start
    /// with a RLP list header.
    ///
    /// For EIP-2718 typed transactions, the format is encoded as the type of the transaction
    /// followed by the rlp of the transaction: `type || rlp(tx-data)`.
    ///
    /// Both for legacy and EIP-2718 transactions, an error will be returned if there is an excess
    /// of bytes in input data.
    fn decode_enveloped(
        mut tx_data: Span<u8>,
    ) -> Result<TransactionUnsigned, EthTransactionError> {
        if tx_data.is_empty() {
            return Result::Err(EthTransactionError::RLPError(RLPError::InputTooShort));
        }

        // Check if it's a list
        let transaction_signed = if Self::is_legacy_tx(tx_data) {
            // Decode as a legacy transaction
            Self::decode_legacy_tx(ref tx_data)?
        } else {
            Self::decode_enveloped_typed_transaction(ref tx_data)?
        };

        //TODO: check that the entire input was consumed and that there are no extra bytes at the
        //end.

        Result::Ok(transaction_signed)
    }

    /// Decode a legacy Ethereum transaction
    /// This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    /// It returns transaction details including nonce, gas price, gas limit, destination address,
    /// amount, payload, message hash, chain id. The transaction hash is computed by keccak hashing
    /// the signed transaction data, which includes the chain ID in accordance with EIP-155.
    /// # Arguments
    /// * encoded_tx_data - The raw rlp encoded transaction data
    /// * encoded_tx_data - is of the format: rlp![nonce, gasPrice, gasLimit, to , value, data,
    /// chainId, 0, 0]
    /// Note: this function assumes that tx_type has been checked to make sure it is a legacy
    /// transaction
    fn decode_legacy_tx(
        ref encoded_tx_data: Span<u8>
    ) -> Result<TransactionUnsigned, EthTransactionError> {
        let decoded_data = RLPTrait::decode(encoded_tx_data);
        let decoded_data = decoded_data.map_err()?;

        if (decoded_data.len() != 1) {
            return Result::Err(EthTransactionError::TopLevelRlpListWrongLength(decoded_data.len()));
        }

        let decoded_data = *decoded_data.at(0);
        let legacy_tx: TxLegacy = match decoded_data {
            RLPItem::String => { Result::Err(EthTransactionError::ExpectedRLPItemToBeList)? },
            RLPItem::List(mut val) => {
                if (val.len() != 9) {
                    return Result::Err(EthTransactionError::LegacyTxWrongPayloadLength(val.len()));
                }

                let boxed_fields = val
                    .multi_pop_front::<7>()
                    .ok_or(EthTransactionError::RLPError(RLPError::InputTooShort))?;
                let [
                    nonce_encoded,
                    gas_price_encoded,
                    gas_limit_encoded,
                    to_encoded,
                    value_encoded,
                    input_encoded,
                    chain_id_encoded
                ] =
                    (*boxed_fields)
                    .unbox();

                let nonce = nonce_encoded.parse_u64_from_string().map_err()?;
                let gas_price = gas_price_encoded.parse_u128_from_string().map_err()?;
                let gas_limit = gas_limit_encoded.parse_u64_from_string().map_err()?;
                let to = to_encoded.try_parse_address_from_string().map_err()?;
                let value = value_encoded.parse_u256_from_string().map_err()?;
                let input = input_encoded.parse_bytes_from_string().map_err()?;
                let chain_id = chain_id_encoded.parse_u64_from_string().map_err()?;

                let transact_to = match to {
                    Option::Some(to) => { TxKind::Call(to) },
                    Option::None => { TxKind::Create }
                };

                TxLegacy {
                    nonce,
                    gas_price,
                    gas_limit,
                    to: transact_to,
                    value,
                    input,
                    chain_id: Option::Some(chain_id),
                }
            }
        };

        //TODO: keccak hash
        let tx_hash = encoded_tx_data.compute_keccak256_hash();

        Result::Ok(
            TransactionUnsigned { transaction: Transaction::Legacy(legacy_tx), hash: tx_hash, }
        )
    }

    /// Decodes an enveloped EIP-2718 typed transaction.
    ///
    /// This should _only_ be used internally in general transaction decoding methods,
    /// which have already ensured that the input is a typed transaction with the following format:
    /// `tx-type || rlp(tx-data)`
    ///
    /// Note that this format does not start with any RLP header, and instead starts with a single
    /// byte indicating the transaction type.
    ///
    /// CAUTION: this expects that `data` is `tx-type || rlp(tx-data)`
    fn decode_enveloped_typed_transaction(
        ref data: Span<u8>
    ) -> Result<TransactionUnsigned, EthTransactionError> {
        // keep this around so we can use it to calculate the hash
        let original_encoding_without_header = data;

        let tx_type = data
            .pop_front()
            .ok_or(EthTransactionError::RLPError(RLPError::InputTooShort))?;
        let tx_type: TxType = (*tx_type)
            .try_into()
            .ok_or(EthTransactionError::RLPError(RLPError::Custom('unsupported tx type')))?;

        let decoded_data = RLPTrait::decode(data).map_err()?;
        if (decoded_data.len() != 1) {
            return Result::Err(
                EthTransactionError::RLPError(RLPError::Custom('not encoded as list'))
            );
        }

        let decoded_data = match *decoded_data.at(0) {
            RLPItem::String => {
                return Result::Err(
                    EthTransactionError::RLPError(RLPError::Custom('not encoded as list'))
                );
            },
            RLPItem::List(v) => { v }
        };

        let transaction = match tx_type {
            TxType::Eip2930 => Transaction::Eip2930(TxEip2930Trait::decode_fields(decoded_data)?),
            TxType::Eip1559 => Transaction::Eip1559(TxEip1559Trait::decode_fields(decoded_data)?),
            TxType::Legacy => {
                return Result::Err(
                    EthTransactionError::RLPError(RLPError::Custom('unexpected legacy tx type'))
                );
            }
        };

        let tx_hash = original_encoding_without_header.compute_keccak256_hash();
        Result::Ok(TransactionUnsigned { transaction, hash: tx_hash })
    }

    /// Check if a raw transaction is a legacy Ethereum transaction
    /// This function checks if a raw transaction is a legacy Ethereum transaction by checking the
    /// transaction type according to EIP-2718.
    /// # Arguments
    /// * `encoded_tx_data` - The raw rlp encoded transaction data
    #[inline(always)]
    fn is_legacy_tx(encoded_tx_data: Span<u8>) -> bool {
        // From EIP2718: if it starts with a value in the range [0xc0, 0xfe] then it is a legacy
        // transaction type
        if (*encoded_tx_data[0] > 0xbf && *encoded_tx_data[0] < 0xff) {
            return true;
        }

        return false;
    }
}

#[cfg(test)]
mod tests {
    use crate::errors::{EthTransactionError, RLPError};
    use crate::helpers::ByteArrayExTrait;
    use super::{TransactionUnsignedTrait};


    //TODO: tests
    // #[test]
// fn test_decode_recover_mainnet_tx() {
//     // random mainnet tx
//     <https://etherscan.io/tx/0x86718885c4b4218c6af87d3d0b0d83e3cc465df2a05c048aa4db9f1a6f9de91f>
//     let signed_tx:ByteArray = ""
//     let signed_tx_bytes = signed_tx.into_bytes();

    //     let decoded = TransactionUnsignedTrait::decode_enveloped(tx_bytes).unwrap();
//     assert_eq!(
//         decoded.recover_signer(),
//         Some(Address::from_str("0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5").unwrap())
//     );
// }

}
