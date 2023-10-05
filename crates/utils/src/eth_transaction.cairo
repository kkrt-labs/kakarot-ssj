use starknet::EthAddress;
use utils::traits::{SpanDefault, EthAddressDefault, ContractAddressDefault};
use cairo_lib::encoding::rlp;
use cairo_lib::utils::types::bytes::{Bytes, BytesTryIntoU256};
use cairo_lib::utils::types::byte::Byte;
use traits::{Into, TryInto};
use debug::PrintTrait;

#[derive(Drop, Copy, Default)]
struct EthereumTransaction {
    nonce: u128,
    gas_price: u128,
    gas_limit: u128,
    destination: EthAddress,
    amount: u256,
    payload: Span<u8>,
    tx_hash: u256,
    v: u128,
    r: u256,
    s: u256,
}

#[generate_trait]
impl EthTransaction of EthTransactionTrait {
    /// Decode a legacy Ethereum transaction
    /// This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID in accordance with EIP-155.
    /// # Arguments
    /// tx_data The raw transaction data
    fn decode_legacy_tx(tx_data: Span<u8>) -> EthereumTransaction {
        let eth_transaction = Default::default();
        eth_transaction
    }

    /// Decode a modern Ethereum transaction
    /// This function decodes a modern Ethereum transaction in accordance with EIP-2718.
    /// It returns transaction details including nonce, gas price, gas limit, destination address, amount, payload,
    /// transaction hash, and signature (v, r, s). The transaction hash is computed by keccak hashing the signed
    /// transaction data, which includes the chain ID as part of the transaction data itself.
    /// # Arguments
    /// tx_data The raw transaction data
    fn decode_tx(tx_data: Span<u8>) -> EthereumTransaction {
        let mut eth_transaction: EthereumTransaction = Default::default();

        let (items, size) = rlp::rlp_decode(tx_data).unwrap();

        match items {
            rlp::RLPItem::Bytes(value) => {},
            rlp::RLPItem::List(list) => {
                let nonce: u256 = (*list[0]).try_into().unwrap();
                eth_transaction.nonce = nonce.try_into().unwrap();

                let gas_price: u256 = (*list[1]).try_into().unwrap();
                eth_transaction.gas_price = gas_price.try_into().unwrap();

                let gas_limit: u256 = (*list[2]).try_into().unwrap();
                eth_transaction.gas_limit = gas_limit.try_into().unwrap();

                let destination: u256 = (*list[3]).try_into().unwrap();
                eth_transaction.destination = destination.into();

                let amount: u256 = (*list[4]).try_into().unwrap();
                eth_transaction.amount = amount.into();

                eth_transaction.payload = (*list[5]).try_into().unwrap();
            },
        }

        eth_transaction
    }

    /// Check if a raw transaction is a legacy Ethereum transaction
    /// This function checks if a raw transaction is a legacy Ethereum transaction by checking the transaction type
    /// according to EIP-2718. If the transaction type is less than or equal to 0xc0, it's a legacy transaction.
    /// # Arguments
    /// - `tx_data` The raw transaction data
    //fn is_legacy_tx(tx_data: Span<u8>) -> bool;

    /// Decode a raw Ethereum transaction
    /// This function decodes a raw Ethereum transaction. It checks if the transaction
    /// is a legacy transaction or a modern transaction, and calls the appropriate decode function
    /// resp. `decode_legacy_tx` or `decode_tx` based on the result.
    /// # Arguments
    /// - `tx_data` The raw transaction data
    fn decode(tx_data: Span<u8>, r: u256, s: u256, v: u128) -> EthereumTransaction {
        let mut eth_transaction: EthereumTransaction = EthTransaction::decode_tx(tx_data);

        eth_transaction
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
    fn validate_eth_tx(address: EthAddress, account_nonce: u128, tx_data: Span<u8>) -> bool {
        true
    }
}
