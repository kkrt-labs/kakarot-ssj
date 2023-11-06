use core::traits::TryInto;

use keccak::cairo_keccak;
use starknet::EthAddress;

use utils::errors::{EthTransactionError, RLPErrorImpl, RLPHelpersErrorImpl, RLPHelpersErrorTrait};
use utils::helpers::ByteArrayExTrait;
use utils::helpers::ResultExTrait;
use utils::helpers::U256Trait;

use utils::helpers::{U256Impl, ByteArrayExt};

use utils::rlp::RLPItem;
use utils::rlp::{RLPImpl, RLPHelpersTrait};

#[derive(Drop)]
struct EthereumTransaction {
    nonce: u128,
    gas_price: u128,
    gas_limit: u128,
    destination: EthAddress,
    amount: u256,
    payload: Span<felt252>,
    tx_hash: u256,
    v: u128,
    r: u256,
    s: u256,
}

// todo(harsh): this default implementation can be removed later on
impl DefaultEthereumTransaction of Default<EthereumTransaction> {
    fn default() -> EthereumTransaction {
        EthereumTransaction {
            nonce: 0,
            gas_price: 0,
            gas_limit: 0,
            destination: EthAddress { address: 0 },
            amount: 0,
            payload: array![].span(),
            tx_hash: 0,
            v: 0,
            r: 0,
            s: 0
        }
    }
}

#[generate_trait]
impl EthTransactionImpl of EthTransaction {
    /// Decode a legacy Ethereum transaction
    /// This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID in accordance with EIP-155.
    /// # Arguments
    /// tx_data The raw transaction data
    /// tx_data is of the format: rlp![nonce, gasPrice, gasLimit, to , value, data, v, r, s]
    fn decode_legacy_tx(tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        let decoded_data = RLPImpl::decode(tx_data);
        let decoded_data = RLPErrorImpl::map_err(decoded_data)?;

        let len = decoded_data.len();
        assert(len == 1, 'Length is not 1');

        let decoded_data = *decoded_data.at(0);

        let result: Result<EthereumTransaction, EthTransactionError> = match decoded_data {
            RLPItem::String => { Result::Err(EthTransactionError::ExpectedRLPItemToBeList) },
            RLPItem::List(val) => {
                let len = val.len();
                assert(len == 9, 'Length is not 9');

                let nonce_idx = 0;
                let gas_price_idx = 1;
                let gas_limit_idx = 2;
                let to_idx = 3;
                let value_idx = 4;
                let data_idx = 5;
                let v_idx = 6;
                let r_idx = 7;
                let s_idx = 8;

                let nonce = RLPHelpersErrorImpl::map_err(
                    (*val.at(nonce_idx)).parse_u128_from_string()
                )?;
                let gas_price = RLPHelpersErrorImpl::map_err(
                    (*val.at(gas_price_idx)).parse_u128_from_string()
                )?;
                let gas_limit = RLPHelpersErrorImpl::map_err(
                    (*val.at(gas_limit_idx)).parse_u128_from_string()
                )?;
                let to = RLPHelpersErrorImpl::map_err((*val.at(to_idx)).parse_u256_from_string())?;
                let value = RLPHelpersErrorImpl::map_err(
                    (*val.at(value_idx)).parse_u256_from_string()
                )?;
                let data = RLPHelpersErrorImpl::map_err(
                    (*val.at(data_idx)).parse_bytes_felt252_from_string()
                )?;
                let v = RLPHelpersErrorImpl::map_err((*val.at(v_idx)).parse_u128_from_string())?;
                let r = RLPHelpersErrorImpl::map_err((*val.at(r_idx)).parse_u256_from_string())?;
                let s = RLPHelpersErrorImpl::map_err((*val.at(s_idx)).parse_u256_from_string())?;

                let mut transaction_data_byte_array = ByteArrayExt::from_bytes(tx_data);
                let (mut keccak_input, last_input_word, last_input_num_bytes) =
                    transaction_data_byte_array
                    .to_u64_words();
                let tx_hash = cairo_keccak(
                    ref keccak_input, :last_input_word, :last_input_num_bytes
                )
                    .reverse_endianness();

                Result::Ok(
                    EthereumTransaction {
                        nonce: nonce,
                        gas_price: gas_price,
                        gas_limit: gas_limit,
                        destination: EthAddress {
                            address: {
                                let address: Option<felt252> = to.try_into();
                                match address {
                                    Option::Some(address) => { Result::Ok(address) },
                                    Option::None => {
                                        Result::Err(
                                            EthTransactionError::Other(
                                                'conversion to felt252 failed'
                                            )
                                        )
                                    }
                                }
                            }?
                        },
                        amount: value,
                        payload: data,
                        v: v,
                        r: r,
                        s: s,
                        tx_hash: tx_hash
                    }
                )
            }
        };

        result
    }

    /// Decode a modern Ethereum transaction
    /// This function decodes a modern Ethereum transaction in accordance with EIP-2718.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID as part of the transaction data itself.
    /// # Arguments
    /// tx_data The raw transaction data
    fn decode_tx(tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        // todo
        Result::Ok(Default::default())
    }

    /// Check if a raw transaction is a legacy Ethereum transaction
    /// This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    /// according to EIP-2718. If the transaction type is less than or equal to 0xc0, it's a legacy transaction.
    /// # Arguments
    /// - `tx_data` The raw transaction data
    fn is_legacy_tx(tx_data: Span<u8>) -> Result<bool, EthTransactionError> {
        // todo
        Result::Ok(false)
    }

    /// Decode a raw Ethereum transaction
    /// This function decodes a raw Ethereum transaction. It checks if the transaction
    /// is a legacy transaction or a modern transaction, and calls the appropriate decode function
    /// resp. `decode_legacy_tx` or `decode_tx` based on the result.
    /// # Arguments
    /// - `tx_data` The raw transaction data
    fn decode(tx_data: Span<u8>) -> Result<EthereumTransaction, EthTransactionError> {
        // todo
        Result::Ok(Default::default())
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
        Result::Ok(false)
    }
}
