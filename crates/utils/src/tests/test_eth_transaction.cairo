use utils::eth_transaction::{EthTransactionImpl};
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
    // transaction_hash: 0x4503d070b579775a52f1c9cf80a2814bb2de6129bcfe6150b3197397146d199f
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
        tx.msg_hash == 0x4503d070b579775a52f1c9cf80a2814bb2de6129bcfe6150b3197397146d199f,
        'message hash it not 0x45...'
    );
}


#[test]
#[available_gas(200000000)]
fn test_decode_eip_1559_tx() {
    // tx_format (EIP-1559, unsiged):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list)
    // expected rlp decoding:   [ '0x01', '0x', '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', []]
    // transaction_hash: 0xe98fe6e52ed72dc79a35bd2410031157ba7eaa609c9ee4384f029e6fc809f86f
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
        tx.msg_hash == 0xe98fe6e52ed72dc79a35bd2410031157ba7eaa609c9ee4384f029e6fc809f86f,
        'message hash it not 0xe9...'
    );
}
