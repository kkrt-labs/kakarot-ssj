use core::option::OptionTrait;
use core::traits::TryInto;

use keccak::cairo_keccak;
use starknet::{EthAddress};
use utils::errors::RLPErrorTrait;

use utils::errors::{EthTransactionError, RLPErrorImpl, RLPHelpersErrorImpl, RLPHelpersErrorTrait};
use utils::helpers::ByteArrayExTrait;
use utils::helpers::U256Trait;

use utils::helpers::{U256Impl, ByteArrayExt};

use utils::rlp::RLPItem;
use utils::rlp::{RLPTrait, RLPHelpersTrait};

#[derive(Drop)]
struct EthereumTransaction {
    nonce: u128,
    gas_price: u128,
    gas_limit: u128,
    destination: EthAddress,
    amount: u256,
    calldata: Span<u8>,
    chain_id: u128,
    msg_hash: u256,
}

#[generate_trait]
impl EthTransactionImpl of EthTransaction {
    /// Decode a legacy Ethereum transaction
    /// This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// message hash, chain id. The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID in accordance with EIP-155.
    /// # Arguments
    /// tx_data The raw transaction data
    /// tx_data is of the format: rlp![nonce, gasPrice, gasLimit, to , value, data, chainId, 0, 0]
    fn decode_legacy_tx(tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        let decoded_data = RLPTrait::decode(tx_data);
        let decoded_data = decoded_data.map_err()?;

        if (decoded_data.len() != 1) {
            return Result::Err(EthTransactionError::Other('Length is not 1'));
        }

        let decoded_data = *decoded_data.at(0);

        let result: Result<EthereumTransaction, EthTransactionError> = match decoded_data {
            RLPItem::String => { Result::Err(EthTransactionError::ExpectedRLPItemToBeList) },
            RLPItem::List(val) => {
                if (val.len() != 9) {
                    return Result::Err(EthTransactionError::Other('Length is not 9'));
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
                let to = (*val.at(to_idx)).parse_u256_from_string().map_err()?;
                let amount = (*val.at(value_idx)).parse_u256_from_string().map_err()?;
                let calldata = (*val.at(calldata_idx)).parse_bytes_from_string().map_err()?;
                let chain_id = (*val.at(chain_id_idx)).parse_u128_from_string().map_err()?;

                let mut transaction_data_byte_array = ByteArrayExt::from_bytes(tx_data);
                let (mut keccak_input, last_input_word, last_input_num_bytes) =
                    transaction_data_byte_array
                    .to_u64_words();
                let msg_hash = cairo_keccak(
                    ref keccak_input, :last_input_word, :last_input_num_bytes
                )
                    .reverse_endianness();

                let destination: EthAddress = to.into();

                Result::Ok(
                    EthereumTransaction {
                        nonce,
                        gas_price,
                        gas_limit,
                        destination,
                        amount,
                        calldata,
                        msg_hash,
                        chain_id
                    }
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
    /// tx_data The raw transaction data
    fn decode_tx(tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        let tx_type: u32 = (*tx_data.at(0)).into();
        let rlp_encoded_data = tx_data.slice(1, tx_data.len() - 1);

        // EIP 2718:
        // TransactionType is a positive unsigned 8-bit number between 0 and 0x7f
        if (tx_type == 0 || tx_type >= 0x7f) {
            return Result::Err(EthTransactionError::Other('Not EIP-2718 transaction'));
        }
        // Only EIP-1559 and EIP 2930 are supported
        if (tx_type != 1 && tx_type != 2) {
            return Result::Err(EthTransactionError::Other('transaction type not supported'));
        }

        // tx_format (EIP-2930, unsiged):  0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
        // tx_format (EIP-1559, unsiged):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list])
        let chain_idx = 0;
        let nonce_idx = 1;
        let gas_price_idx = tx_type + nonce_idx;
        let gas_limit_idx = gas_price_idx + 1;
        let to_idx = gas_limit_idx + 1;
        let value_idx = to_idx + 1;
        let calldata_idx = value_idx + 1;

        let decoded_data = RLPTrait::decode(rlp_encoded_data).map_err()?;
        if (decoded_data.len() != 1) {
            return Result::Err(EthTransactionError::Other('Length is not 1'));
        }

        let decoded_data = *decoded_data.at(0);

        let result: Result<EthereumTransaction, EthTransactionError> = match decoded_data {
            RLPItem::String => { Result::Err(EthTransactionError::ExpectedRLPItemToBeList) },
            RLPItem::List(val) => {
                // total items in EIP 2930 (unsgined): 8
                // total items in EIP 1559 (unsigned): 9
                if (val.len() != 8 && val.len() != 9) {
                    return Result::Err(EthTransactionError::Other('Length is not 8 or 9'));
                }

                let chain_id = (*val.at(chain_idx)).parse_u128_from_string().map_err()?;
                let nonce = (*val.at(nonce_idx)).parse_u128_from_string().map_err()?;
                let gas_price = (*val.at(gas_price_idx)).parse_u128_from_string().map_err()?;
                let gas_limit = (*val.at(gas_limit_idx)).parse_u128_from_string().map_err()?;
                let to = (*val.at(to_idx)).parse_u256_from_string().map_err()?;
                let amount = (*val.at(value_idx)).parse_u256_from_string().map_err()?;
                let calldata = (*val.at(calldata_idx)).parse_bytes_from_string().map_err()?;

                let mut transaction_data_byte_array = ByteArrayExt::from_bytes(tx_data);
                let (mut keccak_input, last_input_word, last_input_num_bytes) =
                    transaction_data_byte_array
                    .to_u64_words();
                let msg_hash = cairo_keccak(
                    ref keccak_input, :last_input_word, :last_input_num_bytes
                )
                    .reverse_endianness();

                let destination: EthAddress = to.into();

                Result::Ok(
                    EthereumTransaction {
                        chain_id,
                        nonce: nonce,
                        gas_price: gas_price,
                        gas_limit: gas_limit,
                        destination,
                        amount,
                        calldata,
                        msg_hash
                    }
                )
            }
        };

        result
    }

    /// Check if a raw transaction is a legacy Ethereum transaction
    /// This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    /// according to EIP-2718. If the transaction type is less than or equal to 0xc0, it's a legacy transaction.
    /// # Arguments
    /// - `tx_data` The raw transaction data
    fn is_legacy_tx(tx_data: Span<u8>) -> Result<bool, EthTransactionError> {
        // todo
        panic_with_felt252('is_legacy_tx unimplemented')
    }

    /// Decode a raw Ethereum transaction
    /// This function decodes a raw Ethereum transaction. It checks if the transaction
    /// is a legacy transaction or a modern transaction, and calls the appropriate decode function
    /// resp. `decode_legacy_tx` or `decode_tx` based on the result.
    /// # Arguments
    /// - `tx_data` The raw transaction data
    fn decode(tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        // todo
        panic_with_felt252('decode unimplemented')
    }

    /// Validate an Ethereum transaction
    /// This function validates an Ethereum transaction by checking if the transaction
    /// is correctly signed by the given address, and if the nonce in the transaction
    /// matches the nonce of the account.
    /// It decodes the transaction using the decode function,
    /// and then verifies the Ethereum signature on the transaction hash.
    /// # Arguments
    /// - `address` The ethereum address that is supposed to have signed the transaction
    /// - `account_nonce` The nonce of the account
    /// - `param tx_data` The raw transaction data
    fn validate_eth_tx(
        address: EthAddress, account_nonce: u128, tx_data: Span<u8>
    ) -> Result<bool, EthTransactionError> {
        // todo
        panic_with_felt252('validate_eth_tx unimplemented')
    }
}
