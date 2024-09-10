use core::starknet::eth_signature::verify_eth_signature;
use crate::eth_transaction::transaction::TransactionTrait;
use crate::eth_transaction::{TransactionMetadata, EthTransactionError, EthTransactionTrait};

/// Validate an Ethereum transaction
/// This function validates an Ethereum transaction by checking if the transaction
/// is correctly signed by the given address, and if the nonce in the transaction
/// matches the nonce of the account.
/// It decodes the transaction using the decode function,
/// and then verifies the Ethereum signature on the transaction hash.
/// # Arguments
/// * `tx_metadata` - The ethereum transaction metadata
/// * `encoded_tx_data` - The raw rlp encoded transaction data
pub fn validate_eth_tx(
    tx_metadata: TransactionMetadata, encoded_tx_data: Span<u8>
) -> Result<bool, EthTransactionError> {
    let TransactionMetadata { address, account_nonce, chain_id, signature } = tx_metadata;

    let signed_transaction = EthTransactionTrait::decode(encoded_tx_data, signature)?;

    if (signed_transaction.transaction.nonce() != account_nonce) {
        return Result::Err(EthTransactionError::IncorrectAccountNonce);
    }
    //TODO(eip-155): support pre-eip155 transactions
    let chain_id_from_tx = signed_transaction
        .transaction
        .chain_id()
        .expect('Chain id should be set');
    if (chain_id_from_tx != chain_id) {
        return Result::Err(EthTransactionError::IncorrectChainId);
    }
    //TODO: add check for max_fee = gas_price * gas_limit
    // max_fee should be later provided by the RPC, and hence this check is necessary

    // this will panic if verification fails
    verify_eth_signature(signed_transaction.hash, signature, address);

    Result::Ok(true)
}


#[cfg(test)]
mod tests {
    use core::starknet::EthAddress;
    use core::starknet::secp256_trait::{Signature};
    use crate::errors::EthTransactionError;
    use crate::eth_transaction::validation::validate_eth_tx;
    use crate::eth_transaction::{TransactionMetadata};
    use crate::test_data::{legacy_rlp_encoded_tx, eip_2930_encoded_tx, eip_1559_encoded_tx};
    use evm::test_utils::chain_id;

    #[test]
    fn test_validate_legacy_tx() {
        let encoded_tx_data = legacy_rlp_encoded_tx();
        let address: EthAddress = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf_u256.into();
        let account_nonce = 0x0;
        let chain_id = chain_id();

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x5e5202c7e9d6d0964a1f48eaecf12eef1c3cafb2379dfeca7cbd413cedd4f2c7,
            s: 0x66da52d0b666fc2a35895e0c91bc47385fe3aa347c7c2a129ae2b7b06cb5498b,
            y_parity: false
        };

        let validate_tx_param = TransactionMetadata { address, account_nonce, chain_id, signature };

        let result = validate_eth_tx(validate_tx_param, encoded_tx_data)
            .expect('signature verification failed');
        assert(result, 'result is not true');
    }


    #[test]
    fn test_validate_eip_2930_tx() {
        let encoded_tx_data = eip_2930_encoded_tx();
        let address: EthAddress = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf_u256.into();
        let account_nonce = 0x0;
        let chain_id = chain_id();

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0xbced8d81c36fe13c95b883b67898b47b4b70cae79e89fa27856ddf8c533886d1,
            s: 0x3de0109f00bc3ed95ffec98edd55b6f750cb77be8e755935dbd6cfec59da7ad0,
            y_parity: true
        };

        let validate_tx_param = TransactionMetadata { address, account_nonce, chain_id, signature };

        let maybe_result = validate_eth_tx(validate_tx_param, encoded_tx_data);
        let result = match maybe_result {
            Result::Ok(result) => result,
            Result::Err(err) => panic!("decode failed: {:?}", err.into()),
        };
        assert(result, 'result is not true');
    }


    #[test]
    fn test_validate_eip_1559_tx() {
        let encoded_tx_data = eip_1559_encoded_tx();
        let address: EthAddress = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf_u256.into();
        let account_nonce = 0x0;
        let chain_id = chain_id();

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x0f9a716653c19fefc240d1da2c5759c50f844fc8835c82834ea3ab7755f789a0,
            s: 0x71506d904c05c6e5ce729b5dd88bcf29db9461c8d72413b864923e8d8f6650c0,
            y_parity: true
        };

        let validate_tx_param = TransactionMetadata { address, account_nonce, chain_id, signature };

        let maybe_result = validate_eth_tx(validate_tx_param, encoded_tx_data);
        let result = match maybe_result {
            Result::Ok(result) => result,
            Result::Err(err) => panic!("decode failed: {:?}", err.into()),
        };
        assert(result, 'result is not true');
    }


    #[test]
    fn test_validate_should_fail_for_wrong_account_id() {
        let encoded_tx_data = eip_1559_encoded_tx();
        let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        // the tx was signed for nonce 0x0
        let wrong_account_nonce = 0x1;
        let chain_id = 0x1;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x141615694556f9078d9da3249e8aa1987524f57153121599cf36d7681b809858,
            s: 0x052052478f912dbe80339e3f198be8c9e1cd44eaabb295d912087d975ef38192,
            y_parity: false
        };

        let validate_tx_param = TransactionMetadata {
            address, account_nonce: wrong_account_nonce, chain_id, signature
        };

        let error = validate_eth_tx(validate_tx_param, encoded_tx_data).unwrap_err();
        assert_eq!(error, EthTransactionError::IncorrectAccountNonce);
    }


    #[test]
    fn test_validate_should_fail_for_wrong_chain_id() {
        let encoded_tx_data = eip_1559_encoded_tx();
        let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let account_nonce = 0x0;
        // the tx was signed for chain_id 0x1
        let wrong_chain_id = 0x2;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x141615694556f9078d9da3249e8aa1987524f57153121599cf36d7681b809858,
            s: 0x052052478f912dbe80339e3f198be8c9e1cd44eaabb295d912087d975ef38192,
            y_parity: false
        };

        let validate_tx_param = TransactionMetadata {
            address, account_nonce, chain_id: wrong_chain_id, signature
        };

        let error = validate_eth_tx(validate_tx_param, encoded_tx_data).unwrap_err();
        assert_eq!(error, EthTransactionError::IncorrectChainId);
    }
}
