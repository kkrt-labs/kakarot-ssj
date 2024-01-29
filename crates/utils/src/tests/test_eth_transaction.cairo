use contracts::tests::test_utils::chain_id;
use core::option::OptionTrait;
use core::starknet::eth_signature::{EthAddress, Signature};

use utils::eth_transaction::{
    EthTransactionTrait, EncodedTransactionTrait, EncodedTransaction, TransactionMetadata,
    EthTransactionError, EthereumTransaction, EthereumTransactionTrait, AccessListItem
};
use utils::helpers::{U256Trait, ToBytes};
use utils::rlp::{RLPTrait, RLPItem, RLPHelpersTrait};
use utils::tests::test_data::{
    legacy_rlp_encoded_tx, legacy_rlp_encoded_deploy_tx, eip_2930_encoded_tx, eip_1559_encoded_tx
};


#[test]
fn test_decode_legacy_tx() {
    // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    // expected rlp decoding:  [ '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', '0x434841494e5f4944', '0x', '0x' ]
    // message_hash: 0x1026be08dc5113457dc5550128d53b1d2b2b6418ffe098468f805ecdcf34efd1
    // chain id used: 0x434841494e5f4944
    let data = legacy_rlp_encoded_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx = encoded_tx.unwrap();
    assert(encoded_tx == EncodedTransaction::Legacy(data), 'encoded_tx is not Legacy');

    let tx = encoded_tx.decode().expect('decode failed');
    let tx = match (tx) {
        EthereumTransaction::LegacyTransaction(tx) => { tx },
        EthereumTransaction::AccessListTransaction(_) => {
            return panic!("Not Legacy Transaction");
        },
        EthereumTransaction::FeeMarketTransaction(_) => { return panic!("Not Legacy Transaction"); }
    };

    assert_eq!(tx.chain_id, chain_id());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x3b9aca00);
    assert_eq!(tx.gas_limit, 0x1e8480);
    assert_eq!(tx.destination.unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,);
    assert_eq!(tx.amount, 0x016345785d8a0000);

    let expected_calldata = 0xabcdef_u32.to_be_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');
}

#[test]
fn test_decode_legacy_deploy_tx() {
    // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    // expected rlp decoding:  ["0x","0x0a","0x061a80","0x","0x0186a0","0x600160010a5060006000f3","0x4b4b5254","0x","0x"]
    let data = legacy_rlp_encoded_deploy_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx = encoded_tx.unwrap();
    assert(encoded_tx == EncodedTransaction::Legacy(data), 'encoded_tx is not Legacy');

    let tx = encoded_tx.decode().expect('decode failed').try_into_legacy_transaction().unwrap();

    assert_eq!(tx.chain_id, 'KKRT'.try_into().unwrap());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x0a);
    assert_eq!(tx.gas_limit, 0x061a80);
    assert!(tx.destination.is_none());
    assert_eq!(tx.amount, 0x0186a0);

    let expected_calldata = 0x600160010a5060006000f3_u256.to_be_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');
}

#[test]
fn test_decode_eip_2930_tx() {
    // tx_format (EIP-2930, unsigned): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
    // expected rlp decoding:   [ "0x434841494e5f4944", "0x", "0x3b9aca00", "0x1e8480", "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef", [["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65", "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ]
    // message_hash: 0xc00f61dcc99a78934275c404267b9d035cad7f71cf3ae2ed2c5a55b601a5c107
    // chain id used: 0x434841494e5f4944
    let data = eip_2930_encoded_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx = encoded_tx.unwrap();
    assert(encoded_tx == EncodedTransaction::EIP2930(data), 'encoded_tx is not Eip2930');

    let tx = encoded_tx
        .decode()
        .expect('decode failed')
        .try_into_access_list_transaction()
        .unwrap();

    assert_eq!(tx.chain_id, chain_id());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x3b9aca00);
    assert_eq!(tx.gas_limit, 0x1e8480);
    assert_eq!(tx.destination.unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984);
    assert_eq!(tx.amount, 0x016345785d8a0000);

    let expected_access_list = array![
        AccessListItem {
            ethereum_address: EthAddress { address: 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984 },
            storage_keys: array![
                0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65,
                0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94
            ]
                .span()
        }
    ]
        .span();
    assert!(tx.access_list == expected_access_list, "access lists are not equal");

    let expected_calldata = 0xabcdef_u32.to_be_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');
}


#[test]
fn test_decode_eip_1559_tx() {
    // tx_format (EIP-1559, unsigned):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list])
    // expected rlp decoding: [ "0x434841494e5f4944", "0x", "0x", "0x3b9aca00", "0x1e8480", "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef", [[["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65", "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ] ]
    // message_hash: 0xa2de478d0c94b4be637523b818d03b6a1841fca63fd044976fcdbef3c57a87b0
    // chain id used: 0x434841494e5f4944
    let data = eip_1559_encoded_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx = encoded_tx.unwrap();
    assert(encoded_tx == EncodedTransaction::EIP1559(data), 'encoded_tx is not EIP1559');

    let tx = encoded_tx.decode().expect('decode failed').try_into_fee_market_transaction().unwrap();

    assert_eq!(tx.chain_id, chain_id());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.max_priority_fee_per_gas, 0);
    assert_eq!(tx.max_fee_per_gas, 0x3b9aca00);
    assert_eq!(tx.gas_limit, 0x1e8480);
    assert_eq!(tx.destination.unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984);
    assert_eq!(tx.amount, 0x016345785d8a0000);

    let expected_access_list = array![
        AccessListItem {
            ethereum_address: EthAddress { address: 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984 },
            storage_keys: array![
                0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65,
                0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94
            ]
                .span()
        }
    ]
        .span();
    assert!(tx.access_list == expected_access_list, "access lists are not equal");

    let expected_calldata = 0xabcdef_u32.to_be_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');
}


#[test]
fn test_is_legacy_tx_eip_155_tx() {
    let encoded_tx_data = legacy_rlp_encoded_tx();
    let result = EncodedTransactionTrait::is_legacy_tx(encoded_tx_data);

    assert(result == true, 'is_legacy_tx expected true');
}

#[test]
fn test_is_legacy_tx_eip_1559_tx() {
    let encoded_tx_data = eip_1559_encoded_tx();
    let result = EncodedTransactionTrait::is_legacy_tx(encoded_tx_data);

    assert(result == false, 'is_legacy_tx expected false');
}

#[test]
fn test_is_legacy_tx_eip_2930_tx() {
    let encoded_tx_data = eip_2930_encoded_tx();
    let result = EncodedTransactionTrait::is_legacy_tx(encoded_tx_data);

    assert(result == false, 'is_legacy_tx expected false');
}


#[test]
fn test_validate_legacy_tx() {
    let encoded_tx_data = legacy_rlp_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    let chain_id = chain_id();

    // to reproduce locally:
    // run: cp .env.example .env
    // bun install & bun run scripts/compute_rlp_encoding.ts
    let signature = Signature {
        r: 0xaae7c4f6e4caa03257e37a6879ed5b51a6f7db491d559d10a0594f804aa8d797,
        s: 0x2f3d9634f8cb9b9a43b048ee3310be91c2d3dc3b51a3313b473ef2260bbf6bc7,
        y_parity: true
    };

    let validate_tx_param = TransactionMetadata { address, account_nonce, chain_id, signature };

    let result = EthTransactionTrait::validate_eth_tx(validate_tx_param, encoded_tx_data)
        .expect('signature verification failed');
    assert(result == true, 'result is not true');
}


#[test]
fn test_validate_eip_2930_tx() {
    let encoded_tx_data = eip_2930_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    let chain_id = chain_id();

    // to reproduce locally:
    // run: cp .env.example .env
    // bun install & bun run scripts/compute_rlp_encoding.ts
    let signature = Signature {
        r: 0xae2dbf7b1e1bdee326066be5afcfb673fe3d1287ef5d5973d4a83025b72bad1e,
        s: 0x48ecf8bc7153513fce782a1f369a8cd3ee9132fc062eb0558cf7102973624774,
        y_parity: false
    };

    let validate_tx_param = TransactionMetadata { address, account_nonce, chain_id, signature };

    let result = EthTransactionTrait::validate_eth_tx(validate_tx_param, encoded_tx_data)
        .expect('signature verification failed');
    assert(result == true, 'result is not true');
}


#[test]
fn test_validate_eip_1559_tx() {
    let encoded_tx_data = eip_1559_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    let chain_id = chain_id();

    // to reproduce locally:
    // run: cp .env.example .env
    // bun install & bun run scripts/compute_rlp_encoding.ts
    let signature = Signature {
        r: 0x141615694556f9078d9da3249e8aa1987524f57153121599cf36d7681b809858,
        s: 0x052052478f912dbe80339e3f198be8c9e1cd44eaabb295d912087d975ef38192,
        y_parity: false
    };

    let validate_tx_param = TransactionMetadata { address, account_nonce, chain_id, signature };

    let result = EthTransactionTrait::validate_eth_tx(validate_tx_param, encoded_tx_data)
        .expect('signature verification failed');
    assert(result == true, 'result is not true');
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

    let result = EthTransactionTrait::validate_eth_tx(validate_tx_param, encoded_tx_data)
        .expect_err('expected to fail');
    assert(result == EthTransactionError::IncorrectAccountNonce, 'result is not true');
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

    let result = EthTransactionTrait::validate_eth_tx(validate_tx_param, encoded_tx_data)
        .expect_err('expected to fail');
    assert(result == EthTransactionError::IncorrectChainId, 'result is not true');
}
