use contracts::tests::test_utils::chain_id;
use core::starknet::eth_signature::{EthAddress, Signature};

use utils::eth_transaction::{
    EthTransactionTrait, EncodedTransactionTrait, EncodedTransaction, TransactionMetadata,
    EthTransactionError, EthereumTransaction
};
use utils::helpers::U256Trait;
use utils::helpers::{U32Trait};
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

    assert_eq!(tx.chain_id, chain_id());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x3b9aca00);
    assert_eq!(tx.gas_limit, 0x1e8480);
    assert_eq!(tx.destination.unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,);
    assert_eq!(tx.amount, 0x016345785d8a0000);

    let expected_calldata = 0xabcdef_u32.to_bytes();
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

    let tx = encoded_tx.decode().expect('decode failed');

    assert_eq!(tx.chain_id, 'KKRT'.try_into().unwrap());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x0a);
    assert_eq!(tx.gas_limit, 0x061a80);
    assert!(tx.destination.is_none());
    assert_eq!(tx.amount, 0x0186a0);

    let expected_calldata = 0x600160010a5060006000f3_u256.to_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');
}

#[test]
fn test_decode_eip_2930_tx() {
    // tx_format (EIP-2930, unsigned): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
    // expected rlp decoding:   [ "0x434841494e5f4944", "0x", "0x3b9aca00", "0x1e8480", "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef", [] ]
    // message_hash: 0xc0227f45fccb86cd5befdffc546c193361174fdf0a08443a874c854e62f60981
    // chain id used: 0x434841494e5f4944
    let data = eip_2930_encoded_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx = encoded_tx.unwrap();
    assert(encoded_tx == EncodedTransaction::EIP2930(data), 'encoded_tx is not Eip2930');

    let tx = encoded_tx.decode().expect('decode failed');

    assert_eq!(tx.chain_id, chain_id());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x3b9aca00);
    assert_eq!(tx.gas_limit, 0x1e8480);
    assert_eq!(tx.destination.unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984);
    assert_eq!(tx.amount, 0x016345785d8a0000);

    let expected_calldata = 0xabcdef_u32.to_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');
}


#[test]
fn test_decode_eip_1559_tx() {
    // tx_format (EIP-1559, unsigned):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list])
    // expected rlp decoding: [ "0x434841494e5f4944", "0x", "0x", "0x3b9aca00", "0x1e8480", "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef", [] ]
    // message_hash: 0xe14268e90788a8e63d8db7f6996dc71dbd9b8ce1314bc9e657735c66137615cc
    // chain id used: 0x434841494e5f4944
    let data = eip_1559_encoded_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx = encoded_tx.unwrap();
    assert(encoded_tx == EncodedTransaction::EIP1559(data), 'encoded_tx is not EIP1559');

    let tx = encoded_tx.decode().expect('decode failed');

    assert_eq!(tx.chain_id, chain_id());
    assert_eq!(tx.nonce, 0);
    assert_eq!(tx.gas_price, 0x3b9aca00);
    assert_eq!(tx.gas_limit, 0x1e8480);
    assert_eq!(tx.destination.unwrap().into(), 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984);
    assert_eq!(tx.amount, 0x016345785d8a0000);

    let expected_calldata = 0xabcdef_u32.to_bytes();
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
        r: 0x96a5512ce388874338c3825959674c130a7cde2317ab0c2312e9e687d15fc373,
        s: 0x12d0b91acc6c7683186f746b8d0a39991911cca2ab99fc84b2a1652792a15249,
        y_parity: true
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
        r: 0x3e1d21af857363cb69f565cf5a791b6e326186250815570c80bd2b7f465802f8,
        s: 0x37a9cec24f7d5c8916ded76f702fcf2b93a20b28a7db8f27d7f4e6e11288bda4,
        y_parity: true
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
        r: 0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a,
        s: 0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95,
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
        r: 0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a,
        s: 0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95,
        y_parity: false
    };

    let validate_tx_param = TransactionMetadata {
        address, account_nonce, chain_id: wrong_chain_id, signature
    };

    let result = EthTransactionTrait::validate_eth_tx(validate_tx_param, encoded_tx_data)
        .expect_err('expected to fail');
    assert(result == EthTransactionError::IncorrectChainId, 'result is not true');
}
