use core::result::ResultTrait;
use core::starknet::{EthAddress, eth_signature::{Signature}};

use utils::eth_transaction::{EthTransactionImpl, ValidateTxParam, EthTransactionError};
use utils::helpers::{U32Trait};
use utils::tests::test_data::{legacy_rlp_encoded_tx, eip_2930_encoded_tx, eip_1559_encoded_tx};

#[test]
#[available_gas(200000000)]
fn test_decode_legacy_tx() {
    // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    // expected rlp decoding:  [ '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', '0x01', '0x', '0x' ]
    // message_hash: 0x89d3071d2bcc98141b16317ec8d912a76271ec052c2884674ddcd752b5ea91fe
    // chain id used: 0x1
    let data = legacy_rlp_encoded_tx();

    let tx = EthTransactionImpl::decode_legacy_tx(data).unwrap();

    assert(tx.chain_id == 0x1, 'chain id is not 0x1');
    assert(tx.nonce == 0, 'nonce is not 0');
    assert(tx.gas_price == 0x3b9aca00, 'gas_price is not 0x3b9aca00');
    assert(tx.gas_limit == 0x1e8480, 'gas_limit is not 0x1e8480');
    assert(
        tx.destination.address == 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,
        'destination is not 0x1f9840...'
    );
    assert(tx.amount == 0x016345785d8a0000, 'amount is not 0x016345785d8...');

    let expected_calldata = 0xabcdef_u32.to_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');

    assert(
        tx.msg_hash == 0x89d3071d2bcc98141b16317ec8d912a76271ec052c2884674ddcd752b5ea91fe,
        'message hash it not 0x89d3...'
    );
}


#[test]
#[available_gas(200000000)]
fn test_decode_eip_2930_tx() {
    // tx_format (EIP-2930, unsiged): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
    // expected rlp decoding:  [ '0x01', '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', [], '0x', '0x14a38ea5e92fe6831b2137226418d03db2ab8cefd6f62bdfc0078787afa63f83', '0x6c89b2928b518445bef8d479167bb9aef73bab1871d1275fd8dcba3c1628a619']
    // message_hash: 0xacc506973edb7b4024d1698a4e7b066728f9ebcee1af4d8ec93d4382e79a62f0
    // chain id used: 0x1
    let data = eip_2930_encoded_tx();

    let tx = EthTransactionImpl::decode_tx(data).unwrap();

    assert(tx.chain_id == 0x1, 'chain id is not 0x1');
    assert(tx.nonce == 0, 'nonce is not 0');
    assert(tx.gas_price == 0x3b9aca00, 'gas_price is not 0x3b9aca00');
    assert(tx.gas_limit == 0x1e8480, 'gas_limit is not 0x1e8480');
    assert(
        tx.destination.address == 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,
        'destination is not 0x1f9840...'
    );
    assert(tx.amount == 0x016345785d8a0000, 'amount is not 0x016345785d8...');

    let expected_calldata = 0xabcdef_u32.to_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');

    assert(
        tx.msg_hash == 0xacc506973edb7b4024d1698a4e7b066728f9ebcee1af4d8ec93d4382e79a62f0,
        'message hash it not 0xacc...'
    );
}


#[test]
#[available_gas(200000000)]
fn test_decode_eip_1559_tx() {
    // tx_format (EIP-1559, unsiged):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list)
    // expected rlp decoding:   [ '0x01', '0x', '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', []]
    // message_hash: 0x598035333ab961ee2ff00db3f21703926c911a42f53222a1fc1757bd1e3c15f5
    // chain id used: 0x1
    let data = eip_1559_encoded_tx();

    let tx = EthTransactionImpl::decode_tx(data).unwrap();

    assert(tx.chain_id == 0x1, 'chain id is not 0x1');
    assert(tx.nonce == 0, 'nonce is not 0');
    assert(tx.gas_price == 0x3b9aca00, 'gas_price is not 0x3b9aca00');
    assert(tx.gas_limit == 0x1e8480, 'gas_limit is not 0x1e8480');
    assert(
        tx.destination.address == 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,
        'destination is not 0x1f9840...'
    );
    assert(tx.amount == 0x016345785d8a0000, 'amount is not 0x016345785d8...');

    let expected_calldata = 0xabcdef_u32.to_bytes();
    assert(tx.calldata == expected_calldata, 'calldata is not 0xabcdef');

    assert(
        tx.msg_hash == 0x598035333ab961ee2ff00db3f21703926c911a42f53222a1fc1757bd1e3c15f5,
        'message hash it not 0x59...'
    );
}

#[test]
#[available_gas(2000000000)]
fn test_is_legacy_tx_eip_155_tx() {
    let tx_data = legacy_rlp_encoded_tx();
    let result = EthTransactionImpl::is_legacy_tx(tx_data);

    assert(result == true, 'is_legacy_tx expected true');
}

#[test]
#[available_gas(2000000000)]
fn test_is_legacy_tx_eip_1559_tx() {
    let tx_data = eip_1559_encoded_tx();
    let result = EthTransactionImpl::is_legacy_tx(tx_data);

    assert(result == false, 'is_legacy_tx expected false');
}

#[test]
#[available_gas(2000000000)]
fn test_is_legacy_tx_eip_2930_tx() {
    let tx_data = eip_2930_encoded_tx();
    let result = EthTransactionImpl::is_legacy_tx(tx_data);

    assert(result == false, 'is_legacy_tx expected false');
}

#[test]
#[available_gas(200000000)]
fn test_validate_legacy_tx() {
    let tx_data = legacy_rlp_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    let chain_id = 0x1;

    let signature = Signature {
        r: 0x9f0140cbb368e853402d4a06ff1f9d1c40f90055fcda4ad357c750685042e342,
        s: 0x30da91d1bc8c89719bc4f22110f18ee9e79e60ab1bdfe8a3997a354670fb47bd,
        y_parity: false
    };

    let validate_tx_param = ValidateTxParam {
        address, account_nonce, chain_id, signature, tx_data
    };

    let result = EthTransactionImpl::validate_eth_tx(validate_tx_param)
        .expect('signature verification failed');
    assert(result == true, 'result is not true');
}


#[test]
#[available_gas(200000000)]
fn test_validate_eip_2930_tx() {
    let tx_data = eip_2930_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    let chain_id = 0x1;

    let signature = Signature {
        r: 0x14a38ea5e92fe6831b2137226418d03db2ab8cefd6f62bdfc0078787afa63f83,
        s: 0x6c89b2928b518445bef8d479167bb9aef73bab1871d1275fd8dcba3c1628a619,
        y_parity: false
    };

    let validate_tx_param = ValidateTxParam {
        address, account_nonce, chain_id, signature, tx_data
    };

    let result = EthTransactionImpl::validate_eth_tx(validate_tx_param)
        .expect('signature verification failed');
    assert(result == true, 'result is not true');
}


#[test]
#[available_gas(200000000)]
fn test_validate_eip_1559_tx() {
    let tx_data = eip_1559_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    let chain_id = 0x1;

    let signature = Signature {
        r: 0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a,
        s: 0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95,
        y_parity: false
    };

    let validate_tx_param = ValidateTxParam {
        address, account_nonce, chain_id, signature, tx_data
    };

    let result = EthTransactionImpl::validate_eth_tx(validate_tx_param)
        .expect('signature verification failed');
    assert(result == true, 'result is not true');
}

#[test]
#[available_gas(200000000)]
fn test_validate_should_fail_for_wrong_account_id() {
    let tx_data = eip_1559_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    // the tx was signed for nonce 0x0
    let wrong_account_nonce = 0x1;
    let chain_id = 0x1;

    let signature = Signature {
        r: 0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a,
        s: 0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95,
        y_parity: false
    };

    let validate_tx_param = ValidateTxParam {
        address, account_nonce: wrong_account_nonce, chain_id, signature, tx_data
    };

    let result = EthTransactionImpl::validate_eth_tx(validate_tx_param)
        .expect_err('expected to fail');
    assert(result == EthTransactionError::AccountNonceIsIncorrect, 'result is not true');
}

#[test]
#[available_gas(200000000)]
fn test_validate_should_fail_for_wrong_chain_id() {
    let tx_data = eip_1559_encoded_tx();
    let address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
    let account_nonce = 0x0;
    // the tx was signed for chain_id 0x1
    let wrong_chain_id = 0x2;

    let signature = Signature {
        r: 0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a,
        s: 0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95,
        y_parity: false
    };

    let validate_tx_param = ValidateTxParam {
        address, account_nonce, chain_id: wrong_chain_id, signature, tx_data
    };

    let result = EthTransactionImpl::validate_eth_tx(validate_tx_param)
        .expect_err('expected to fail');
    assert(result == EthTransactionError::ChainIdIsIncoorect, 'result is not true');
}
