use core::array::SpanTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use keccak::cairo_keccak;
use starknet::{EthAddress, eth_signature::{Signature, verify_eth_signature}};
use utils::errors::RLPErrorTrait;

use utils::errors::{EthTransactionError, RLPErrorImpl, RLPHelpersErrorImpl, RLPHelpersErrorTrait};
use utils::helpers::{U256Trait, U256Impl, ByteArrayExt, U8SpanExTrait};

use utils::rlp::RLPItem;
use utils::rlp::{RLPTrait, RLPHelpersTrait};

type AccessList = Span<(EthAddress, Span<u256>)>;

#[derive(Drop)]
struct TransactionMetadata {
    address: EthAddress,
    account_nonce: u128,
    chain_id: u128,
    signature: Signature,
}

#[derive(Drop)]
struct LegacyTransaction {
    chain_id: u128,
    nonce: u128,
    gas_price: u128,
    gas_limit: u128,
    destination: Option<EthAddress>,
    amount: u256,
    calldata: Span<u8>
}

#[derive(Drop)]
struct AccessListTransaction {
    chain_id: u128,
    nonce: u128,
    gas_price: u128,
    gas_limit: u128,
    destination: Option<EthAddress>,
    amount: u256,
    calldata: Span<u8>,
    access_list: AccessList
}

#[derive(Drop)]
struct FeeMarketTransaction {
    chain_id: u128,
    nonce: u128,
    max_priority_fee_per_gas: u128,
    max_fee_per_gas: u128,
    gas_limit: u128,
    destination: Option<EthAddress>,
    amount: u256,
    calldata: Span<u8>,
    access_list: AccessList
}

#[derive(Drop)]
enum EthereumTransaction {
    LegacyTransaction: LegacyTransaction,
    AccessListTransaction: AccessListTransaction,
    FeeMarketTransaction: FeeMarketTransaction
}

#[generate_trait]
impl EthereumTransactionImpl of EthereumTransactionTrait {
    fn chain_id(self: @EthereumTransaction) -> u128 {
        match self {
            EthereumTransaction::LegacyTransaction(v) => { *v.chain_id },
            EthereumTransaction::AccessListTransaction(v) => { *v.chain_id },
            EthereumTransaction::FeeMarketTransaction(v) => { *v.chain_id }
        }
    }

    fn nonce(self: @EthereumTransaction) -> u128 {
        match self {
            EthereumTransaction::LegacyTransaction(v) => { *v.nonce },
            EthereumTransaction::AccessListTransaction(v) => { *v.nonce },
            EthereumTransaction::FeeMarketTransaction(v) => { *v.nonce }
        }
    }
}

#[derive(Drop, PartialEq)]
enum EncodedTransaction {
    Legacy: Span<u8>,
    EIP1559: Span<u8>,
    EIP2930: Span<u8>,
}

impl IntoEncodedTransaction of TryInto<Span<u8>, EncodedTransaction> {
    fn try_into(self: Span<u8>) -> Option<EncodedTransaction> {
        if self.is_empty() {
            return Option::None;
        }
        if (EncodedTransactionTrait::is_legacy_tx(self)) {
            Option::Some(EncodedTransaction::Legacy(self))
        } else {
            let tx_type: u32 = (*self.at(0)).into();
            if (tx_type == 1) {
                Option::Some(EncodedTransaction::EIP2930(self))
            } else if (tx_type == 2) {
                Option::Some(EncodedTransaction::EIP1559(self))
            } else {
                Option::None
            }
        }
    }
}

#[generate_trait]
impl EncodedTransactionImpl of EncodedTransactionTrait {
    #[inline(always)]
    fn decode(self: EncodedTransaction) -> Result<EthereumTransaction, EthTransactionError> {
        match self {
            EncodedTransaction::Legacy(encoded_tx_data) => {
                EncodedTransactionTrait::decode_legacy_tx(encoded_tx_data)
            },
            EncodedTransaction::EIP1559(encoded_tx_data) => {
                EncodedTransactionTrait::decode_typed_tx(encoded_tx_data)
            },
            EncodedTransaction::EIP2930(encoded_tx_data) => {
                EncodedTransactionTrait::decode_typed_tx(encoded_tx_data)
            },
        }
    }

    /// Decode a legacy Ethereum transaction
    /// This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// message hash, chain id. The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID in accordance with EIP-155.
    /// # Arguments
    /// * encoded_tx_data - The raw rlp encoded transaction data
    /// * encoded_tx_data - is of the format: rlp![nonce, gasPrice, gasLimit, to , value, data, chainId, 0, 0]
    /// Note: this function assumes that tx_type has been checked to make sure it is a legacy transaction
    fn decode_legacy_tx(
        encoded_tx_data: Span<u8>
    ) -> Result<EthereumTransaction, EthTransactionError> {
        let decoded_data = RLPTrait::decode(encoded_tx_data);
        let decoded_data = decoded_data.map_err()?;

        if (decoded_data.len() != 1) {
            return Result::Err(EthTransactionError::TopLevelRlpListWrongLength(decoded_data.len()));
        }

        let decoded_data = *decoded_data.at(0);

        let result: Result<EthereumTransaction, EthTransactionError> = match decoded_data {
            RLPItem::String => { Result::Err(EthTransactionError::ExpectedRLPItemToBeList) },
            RLPItem::List(val) => {
                if (val.len() != 9) {
                    return Result::Err(EthTransactionError::LegacyTxWrongPayloadLength(val.len()));
                }

                let (
                    nonce_idx,
                    gas_price_idx,
                    gas_limit_idx,
                    to_idx,
                    value_idx,
                    calldata_idx,
                    chain_id_idx
                ) =
                    (
                    0, 1, 2, 3, 4, 5, 6
                );

                let nonce = (*val.at(nonce_idx)).parse_u128_from_string().map_err()?;
                let gas_price = (*val.at(gas_price_idx)).parse_u128_from_string().map_err()?;
                let gas_limit = (*val.at(gas_limit_idx)).parse_u128_from_string().map_err()?;
                let to = (*val.at(to_idx)).parse_address_from_string().map_err()?;
                let amount = (*val.at(value_idx)).parse_u256_from_string().map_err()?;
                let calldata = (*val.at(calldata_idx)).parse_bytes_from_string().map_err()?;
                let chain_id = (*val.at(chain_id_idx)).parse_u128_from_string().map_err()?;

                Result::Ok(
                    EthereumTransaction::LegacyTransaction(
                        LegacyTransaction {
                            nonce, gas_price, gas_limit, destination: to, amount, calldata, chain_id
                        }
                    )
                )
            }
        };

        result
    }

    /// Decode a modern Ethereum transaction
    /// This function decodes a modern Ethereum transaction in accordance with EIP-2718.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// message hash, and chain id. The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID as part of the transaction data itself.
    /// # Arguments
    /// * `encoded_tx_data` - The raw rlp encoded transaction data
    /// Note: this function assumes that tx_type has been checked to make sure it is either EIP-2930 or EIP-1559 transaction
    fn decode_typed_tx(
        encoded_tx_data: Span<u8>
    ) -> Result<EthereumTransaction, EthTransactionError> {
        let tx_type: u8 = (*encoded_tx_data.at(0)).into();
        let tx_type: TransactionType = match tx_type.try_into() {
            Option::Some(v) => { v },
            Option::None => { return Result::Err(EthTransactionError::TransactionTypeError); }
        };

        let rlp_encoded_data = encoded_tx_data.slice(1, encoded_tx_data.len() - 1);

        let decoded_data = RLPTrait::decode(rlp_encoded_data).map_err()?;
        if (decoded_data.len() != 1) {
            return Result::Err(EthTransactionError::TopLevelRlpListWrongLength(decoded_data.len()));
        }

        let decoded_data = *decoded_data.at(0);
        let decoded_data = match decoded_data {
            RLPItem::String => {
                return Result::Err(EthTransactionError::ExpectedRLPItemToBeList);
            },
            RLPItem::List(v) => { v }
        };

        match tx_type {
            TransactionType::Legacy => {
                return Result::Err(EthTransactionError::TransactionTypeError);
            },
            // tx_format (EIP-2930, unsigned):  0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
            TransactionType::EIP2930 => {
                let chain_id = (*decoded_data.at(0)).parse_u128_from_string().map_err()?;
                let nonce = (*decoded_data.at(1)).parse_u128_from_string().map_err()?;
                let gas_price = (*decoded_data.at(2)).parse_u128_from_string().map_err()?;
                let gas_limit = (*decoded_data.at(3)).parse_u128_from_string().map_err()?;
                let to = (*decoded_data.at(4)).parse_address_from_string().map_err()?;
                let amount = (*decoded_data.at(5)).parse_u256_from_string().map_err()?;
                let calldata = (*decoded_data.at(6)).parse_bytes_from_string().map_err()?;

                let access_list = (*decoded_data.at(6)).parse_access_list().map_err()?;

                Result::Ok(
                    EthereumTransaction::AccessListTransaction(
                        AccessListTransaction {
                            chain_id,
                            nonce,
                            gas_price,
                            gas_limit,
                            destination: to,
                            amount,
                            calldata,
                            access_list
                        }
                    )
                )
            },
            // tx_format (EIP-1559, unsigned):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list])
            TransactionType::EIP1559 => {
                let chain_id = (*decoded_data.at(0)).parse_u128_from_string().map_err()?;
                let nonce = (*decoded_data.at(1)).parse_u128_from_string().map_err()?;
                let max_priority_fee_per_gas = (*decoded_data.at(2))
                    .parse_u128_from_string()
                    .map_err()?;
                let max_fee_per_gas = (*decoded_data.at(3)).parse_u128_from_string().map_err()?;
                let gas_limit = (*decoded_data.at(4)).parse_u128_from_string().map_err()?;
                let to = (*decoded_data.at(5)).parse_address_from_string().map_err()?;
                let amount = (*decoded_data.at(6)).parse_u256_from_string().map_err()?;
                let calldata = (*decoded_data.at(7)).parse_bytes_from_string().map_err()?;

                let access_list = (*decoded_data.at(8)).parse_access_list().map_err()?;

                Result::Ok(
                    EthereumTransaction::FeeMarketTransaction(
                        FeeMarketTransaction {
                            chain_id,
                            nonce,
                            max_priority_fee_per_gas,
                            max_fee_per_gas,
                            gas_limit,
                            destination: to,
                            amount,
                            calldata,
                            access_list
                        }
                    )
                )
            }
        }
    }

    /// Check if a raw transaction is a legacy Ethereum transaction
    /// This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    /// according to EIP-2718.
    /// # Arguments
    /// * `encoded_tx_data` - The raw rlp encoded transaction data
    #[inline(always)]
    fn is_legacy_tx(encoded_tx_data: Span<u8>) -> bool {
        // From EIP2718: if it starts with a value in the range [0xc0, 0xfe] then it is a legacy transaction type
        if (*encoded_tx_data[0] > 0xbf && *encoded_tx_data[0] < 0xff) {
            return true;
        }

        return false;
    }
}

#[derive(Drop, PartialEq)]
enum TransactionType {
    Legacy,
    EIP2930,
    EIP1559
}

impl TranscationTypeIntoU8Impl of Into<TransactionType, u8> {
    fn into(self: TransactionType) -> u8 {
        match self {
            TransactionType::Legacy => { 0 },
            TransactionType::EIP2930 => { 1 },
            TransactionType::EIP1559 => { 2 }
        }
    }
}

impl TryIntoTransactionTypeImpl of TryInto<u8, TransactionType> {
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
impl EthTransactionImpl of EthTransactionTrait {
    /// Decode a raw Ethereum transaction
    /// This function decodes a raw Ethereum transaction. It checks if the transaction
    /// is a legacy transaction or a modern transaction, and calls the appropriate decode function
    /// resp. `decode_legacy_tx` or `decode_tx` based on the result.
    /// # Arguments
    /// * `encoded_tx_data` - The raw transaction rlp encoded data
    #[inline(always)]
    fn decode(encoded_tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        let encoded_tx: EncodedTransaction = encoded_tx_data
            .try_into()
            .ok_or(EthTransactionError::TransactionTypeError)?;

        encoded_tx.decode()
    }

    /// Validate an Ethereum transaction
    /// This function validates an Ethereum transaction by checking if the transaction
    /// is correctly signed by the given address, and if the nonce in the transaction
    /// matches the nonce of the account.
    /// It decodes the transaction using the decode function,
    /// and then verifies the Ethereum signature on the transaction hash.
    /// # Arguments
    /// * `tx_metadata` - The ethereum transaction metadata
    /// * `encoded_tx_data` - The raw rlp encoded transaction data
    fn validate_eth_tx(
        tx_metadata: TransactionMetadata, encoded_tx_data: Span<u8>
    ) -> Result<bool, EthTransactionError> {
        let TransactionMetadata{address, account_nonce, chain_id, signature } = tx_metadata;

        let decoded_tx = EthTransactionTrait::decode(encoded_tx_data)?;

        if (decoded_tx.nonce() != account_nonce) {
            return Result::Err(EthTransactionError::IncorrectAccountNonce);
        }
        if (decoded_tx.chain_id() != chain_id) {
            return Result::Err(EthTransactionError::IncorrectChainId);
        }
        //TODO: add check for max_fee = gas_price * gas_limit
        // max_fee should be later provided by the RPC, and hence this check is necessary

        let msg_hash = encoded_tx_data.compute_keccak256_hash();

        // this will panic if verification fails
        verify_eth_signature(msg_hash, signature, address);

        Result::Ok(true)
    }
}
