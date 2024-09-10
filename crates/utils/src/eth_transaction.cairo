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
use eip1559::TxEip1559Trait;
use eip2930::TxEip2930Trait;
use legacy::TxLegacy;
use transaction::{Transaction, TransactionUnsignedTrait, TransactionUnsigned};
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
    fn decode(encoded_tx_data: Span<u8>) -> Result<TransactionUnsigned, EthTransactionError> {
        TransactionUnsignedTrait::decode_enveloped(encoded_tx_data)
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
    use crate::eth_transaction::eip2930::AccessListItem;
    use crate::eth_transaction::tx_type::TxType;
    use crate::traits::DefaultSignature;
    use evm::test_utils::chain_id;
    use utils::eth_transaction::transaction::TransactionTrait;

    use utils::eth_transaction::{EthTransactionTrait, TransactionUnsignedTrait};
    use utils::helpers::ToBytes;
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

        let maybe_signed_tx = EthTransactionTrait::decode(data);
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

        let maybe_signed_tx = EthTransactionTrait::decode(data);
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

        let maybe_signed_tx = EthTransactionTrait::decode(data);
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

        let maybe_signed_tx = EthTransactionTrait::decode(data);
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
        let result = TransactionUnsignedTrait::is_legacy_tx(encoded_tx_data);

        assert(result, 'is_legacy_tx expected true');
    }

    #[test]
    fn test_is_legacy_tx_eip_1559_tx() {
        let encoded_tx_data = eip_1559_encoded_tx();
        let result = TransactionUnsignedTrait::is_legacy_tx(encoded_tx_data);

        assert(!result, 'is_legacy_tx expected false');
    }

    #[test]
    fn test_is_legacy_tx_eip_2930_tx() {
        let encoded_tx_data = eip_2930_encoded_tx();
        let result = TransactionUnsignedTrait::is_legacy_tx(encoded_tx_data);

        assert(!result, 'is_legacy_tx expected false');
    }
}
