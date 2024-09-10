pub mod common;
pub mod eip1559;
pub mod eip2930;
pub mod legacy;
pub mod transaction;
pub mod tx_type;
pub mod validation;

use core::array::SpanTrait;
use core::cmp::min;
use core::num::traits::{CheckedAdd, Zero};
use core::option::OptionTrait;
use core::starknet::{EthAddress, secp256_trait::Signature,};
use core::traits::TryInto;
use crate::eth_transaction::common::TxKind;
use eip1559::{TxEip1559, TxEip1559Trait};
use eip2930::{TxEip2930, TxEip2930Trait};
use legacy::TxLegacy;
use transaction::{Transaction, TransactionSigned, TransactionTrait};
use tx_type::TxType;
use utils::errors::{
    RLPErrorTrait, EthTransactionError, RLPError, RLPErrorImpl, RLPHelpersErrorImpl,
    RLPHelpersErrorTrait
};

use utils::helpers::{ByteArrayExt, U8SpanExTrait};

use utils::rlp::RLPItem;
use utils::rlp::{RLPTrait, RLPHelpersTrait};

#[derive(Drop)]
pub struct TransactionMetadata {
    pub address: EthAddress,
    pub account_nonce: u64,
    pub chain_id: u64,
    pub signature: Signature,
}

#[derive(Copy, Drop, Debug, PartialEq)]
pub enum TransactTo {
    /// Simple call to an address.
    Call: EthAddress,
    /// Contract creation.
    Create,
}

#[generate_trait]
pub impl EncodedTransactionImpl of EncodedTransactionTrait {
    //TODO: make normal decode function
    fn decode_raw(
        mut tx_data: Span<u8>, signature: Signature
    ) -> Result<TransactionSigned, EthTransactionError> {
        if tx_data.is_empty() {
            return Result::Err(EthTransactionError::RLPError(RLPError::InputTooShort));
        }
        let is_legacy_tx = Self::is_legacy_tx(tx_data);
        let transaction_signed = if is_legacy_tx {
            Self::decode_legacy_tx(ref tx_data, signature)?
        } else {
            Self::decode_enveloped_typed_transaction(ref tx_data, signature)?
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
        ref encoded_tx_data: Span<u8>, signature: Signature
    ) -> Result<TransactionSigned, EthTransactionError> {
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
            TransactionSigned {
                transaction: Transaction::Legacy(legacy_tx), hash: tx_hash, signature: signature,
            }
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
        ref data: Span<u8>, signature: Signature
    ) -> Result<TransactionSigned, EthTransactionError> {
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
        Result::Ok(TransactionSigned { transaction, hash: tx_hash, signature })
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

#[derive(Drop, PartialEq)]
pub enum TransactionType {
    Legacy,
    EIP2930,
    EIP1559
}

pub impl TranscationTypeIntoU8Impl of Into<TransactionType, u8> {
    fn into(self: TransactionType) -> u8 {
        match self {
            TransactionType::Legacy => { 0 },
            TransactionType::EIP2930 => { 1 },
            TransactionType::EIP1559 => { 2 }
        }
    }
}

pub impl TryIntoTransactionTypeImpl of TryInto<u8, TransactionType> {
    fn try_into(self: u8) -> Option<TransactionType> {
        if (self == 0) {
            return Option::Some(TransactionType::Legacy);
        }
        if (self == 1) {
            return Option::Some(TransactionType::EIP2930);
        }
        if (self == 2) {
            return Option::Some(TransactionType::EIP1559);
        }

        Option::None
    }
}

#[generate_trait]
pub impl EthTransactionImpl of EthTransactionTrait {
    /// Decode a raw Ethereum transaction
    /// This function decodes a raw Ethereum transaction. It checks if the transaction
    /// is a legacy transaction or a modern transaction, and calls the appropriate decode function
    /// resp. `decode_legacy_tx` or `decode_tx` based on the result.
    /// # Arguments
    /// * `encoded_tx_data` - The raw transaction rlp encoded data
    #[inline(always)]
    fn decode(
        encoded_tx_data: Span<u8>, signature: Signature
    ) -> Result<TransactionSigned, EthTransactionError> {
        EncodedTransactionTrait::decode_raw(encoded_tx_data, signature)
    }
}

/// Get the effective gas price of a transaction as specfified in EIP-1559 with relevant
/// checks.
fn get_effective_gas_price(
    max_fee_per_gas: Option<u256>, max_priority_fee_per_gas: Option<u256>, block_base_fee: u256,
) -> Result<u256, EthTransactionError> {
    match max_fee_per_gas {
        Option::Some(max_fee) => {
            let max_priority_fee_per_gas = max_priority_fee_per_gas.unwrap_or(0);

            // only enforce the fee cap if provided input is not zero
            if !(max_fee.is_zero() && max_priority_fee_per_gas.is_zero())
                && max_fee < block_base_fee {
                // `base_fee_per_gas` is greater than the `max_fee_per_gas`
                return Result::Err(EthTransactionError::FeeCapTooLow);
            }
            if max_fee < max_priority_fee_per_gas {
                // `max_priority_fee_per_gas` is greater than the `max_fee_per_gas`
                return Result::Err(EthTransactionError::TipAboveFeeCap);
            }
            Result::Ok(
                min(
                    max_fee,
                    block_base_fee
                        .checked_add(max_priority_fee_per_gas)
                        .ok_or(EthTransactionError::TipVeryHigh)?,
                )
            )
        },
        Option::None => Result::Ok(
            block_base_fee
                .checked_add(max_priority_fee_per_gas.unwrap_or(0))
                .ok_or(EthTransactionError::TipVeryHigh)?
        ),
    }
}

#[cfg(test)]
mod tests {
    use core::option::OptionTrait;
    use core::starknet::EthAddress;
    use core::starknet::secp256_trait::{Signature};
    use crate::eth_transaction::eip2930::AccessListItem;
    use crate::eth_transaction::tx_type::TxType;
    use crate::traits::DefaultSignature;
    use evm::test_utils::chain_id;
    use utils::eth_transaction::transaction::{Transaction, TransactionSigned, TransactionTrait};

    use utils::eth_transaction::{
        EthTransactionTrait, EncodedTransactionTrait, TransactionMetadata, EthTransactionError
    };
    use utils::helpers::{U256Trait, ToBytes};
    use utils::rlp::{RLPTrait, RLPItem, RLPHelpersTrait};
    use utils::test_data::{
        legacy_rlp_encoded_tx, legacy_rlp_encoded_deploy_tx, eip_2930_encoded_tx,
        eip_1559_encoded_tx
    };


    #[test]
    fn test_decode_legacy_tx() {
        // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0,
        // 0]
        // expected rlp decoding:  [ '0x', '0x3b9aca00', '0x1e8480',
        // '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef',
        // '0x434841494e5f4944', '0x', '0x' ]
        // message_hash: 0x1026be08dc5113457dc5550128d53b1d2b2b6418ffe098468f805ecdcf34efd1
        // chain id used: 0x434841494e5f4944

        let data = legacy_rlp_encoded_tx();

        let maybe_signed_tx = EthTransactionTrait::decode(data, Default::default());
        let signed_tx = match maybe_signed_tx {
            Result::Ok(signed_tx) => signed_tx,
            Result::Err(err) => panic!("decode failed: {:?}", err.into()),
        };
        let transaction = signed_tx.transaction;
        let tx_type = transaction.transaction_type();
        assert_eq!(tx_type, TxType::Legacy);

        assert_eq!(transaction.chain_id().unwrap(), chain_id());
        assert_eq!(transaction.nonce(), 0);
        assert_eq!(transaction.max_fee_per_gas(), 0x3b9aca00);
        assert_eq!(transaction.gas_limit(), 0x1e8480);
        assert_eq!(transaction.to().unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,);
        assert_eq!(transaction.value(), 0x016345785d8a0000);

        let expected_calldata = 0xabcdef_u32.to_be_bytes();
        assert_eq!(transaction.input(), expected_calldata);
    }

    #[test]
    fn test_decode_legacy_deploy_tx() {
        // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0,
        // 0]
        // expected rlp decoding:
        //
        // ["0x","0x0a","0x061a80","0x","0x0186a0","0x600160010a5060006000f3","0x4b4b5254","0x","0x"]
        let data = legacy_rlp_encoded_deploy_tx();

        let maybe_signed_tx = EthTransactionTrait::decode(data, Default::default());
        let signed_tx = match maybe_signed_tx {
            Result::Ok(signed_tx) => signed_tx,
            Result::Err(err) => panic!("decode failed: {:?}", err.into()),
        };
        let transaction = signed_tx.transaction;
        let tx_type = transaction.transaction_type();
        assert_eq!(tx_type, TxType::Legacy);

        assert_eq!(transaction.chain_id().unwrap(), chain_id());
        assert_eq!(transaction.nonce(), 0);
        assert_eq!(transaction.max_fee_per_gas(), 0x0a);
        assert_eq!(transaction.gas_limit(), 0x061a80);
        assert!(transaction.to().is_none());
        assert_eq!(transaction.value(), 0x0186a0);

        let expected_calldata = 0x600160010a5060006000f3_u256.to_be_bytes();
        assert_eq!(transaction.input(), expected_calldata);
    }

    #[test]
    fn test_decode_eip_2930_tx() {
        // tx_format (EIP-2930, unsigned): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to,
        // value, data, accessList])
        // expected rlp decoding:   [ "0x434841494e5f4944", "0x", "0x3b9aca00", "0x1e8480",
        // "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef",
        // [["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        // ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65",
        // "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ]
        // message_hash: 0xc00f61dcc99a78934275c404267b9d035cad7f71cf3ae2ed2c5a55b601a5c107
        // chain id used: 0x434841494e5f4944
        let data = eip_2930_encoded_tx();

        let maybe_signed_tx = EthTransactionTrait::decode(data, Default::default());
        let signed_tx = match maybe_signed_tx {
            Result::Ok(signed_tx) => signed_tx,
            Result::Err(err) => panic!("decode failed: {:?}", err.into()),
        };
        let transaction = signed_tx.transaction;
        let tx_type = transaction.transaction_type();
        assert_eq!(tx_type, TxType::Eip2930);

        assert_eq!(transaction.chain_id().unwrap(), chain_id());
        assert_eq!(transaction.nonce(), 0);
        assert_eq!(transaction.max_fee_per_gas(), 0x3b9aca00);
        assert_eq!(transaction.gas_limit(), 0x1e8480);
        assert_eq!(transaction.to().unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984);
        assert_eq!(transaction.value(), 0x016345785d8a0000);

        let expected_access_list = [
            AccessListItem {
                ethereum_address: 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap(),
                storage_keys: [
                    0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65,
                    0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94
                ].span()
            }
        ].span();
        assert_eq!(transaction.access_list().unwrap(), expected_access_list);

        let expected_calldata = 0xabcdef_u32.to_be_bytes();
        assert(transaction.input() == expected_calldata, 'calldata is not 0xabcdef');
    }


    #[test]
    fn test_decode_eip_1559_tx() {
        // tx_format (EIP-1559, unsigned):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas,
        // max_fee_per_gas, gas_limit, destination, amount, data, access_list])
        // expected rlp decoding: [ "0x434841494e5f4944", "0x", "0x", "0x3b9aca00", "0x1e8480",
        // "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef",
        // [[["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        // ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65",
        // "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ] ]
        // message_hash: 0xa2de478d0c94b4be637523b818d03b6a1841fca63fd044976fcdbef3c57a87b0
        // chain id used: 0x434841494e5f4944
        let data = eip_1559_encoded_tx();

        let maybe_signed_tx = EthTransactionTrait::decode(data, Default::default());
        let signed_tx = match maybe_signed_tx {
            Result::Ok(signed_tx) => signed_tx,
            Result::Err(err) => panic!("decode failed: {:?}", err.into()),
        };
        let transaction = signed_tx.transaction;
        let tx_type = transaction.transaction_type();
        assert_eq!(tx_type, TxType::Eip1559);

        assert_eq!(transaction.chain_id().expect('chain_id is none'), chain_id());
        assert_eq!(transaction.nonce(), 0);
        assert_eq!(
            transaction.max_priority_fee_per_gas().expect('max_priority_fee_per_gas none'), 0
        );
        assert_eq!(transaction.max_fee_per_gas(), 0x3b9aca00);
        assert_eq!(transaction.gas_limit(), 0x1e8480);
        assert_eq!(
            transaction.to().expect('to is none').into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984
        );
        assert_eq!(transaction.value(), 0x016345785d8a0000);

        let expected_access_list = [
            AccessListItem {
                ethereum_address: 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap(),
                storage_keys: [
                    0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65,
                    0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94
                ].span()
            }
        ].span();
        assert_eq!(transaction.access_list().expect('access_list is none'), expected_access_list);

        let expected_calldata = 0xabcdef_u32.to_be_bytes();
        assert_eq!(transaction.input(), expected_calldata);
    }


    #[test]
    fn test_is_legacy_tx_eip_155_tx() {
        let encoded_tx_data = legacy_rlp_encoded_tx();
        let result = EncodedTransactionTrait::is_legacy_tx(encoded_tx_data);

        assert(result, 'is_legacy_tx expected true');
    }

    #[test]
    fn test_is_legacy_tx_eip_1559_tx() {
        let encoded_tx_data = eip_1559_encoded_tx();
        let result = EncodedTransactionTrait::is_legacy_tx(encoded_tx_data);

        assert(!result, 'is_legacy_tx expected false');
    }

    #[test]
    fn test_is_legacy_tx_eip_2930_tx() {
        let encoded_tx_data = eip_2930_encoded_tx();
        let result = EncodedTransactionTrait::is_legacy_tx(encoded_tx_data);

        assert(!result, 'is_legacy_tx expected false');
    }
}
