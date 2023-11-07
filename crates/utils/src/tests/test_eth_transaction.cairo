use utils::eth_transaction::{EthTransactionImpl};
use utils::helpers::{U32Trait, bytes_to_felt252_array};

#[test]
#[available_gas(200000000)]
fn test_decode_legacy_tx() {
    // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    // expected rlp decoding:  [ '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', '0x01', '0x', '0x' ]
    // message_hash: 0x89d3071d2bcc98141b16317ec8d912a76271ec052c2884674ddcd752b5ea91fe
    // chain id used: 0x1
    let data = array![
        239,
        128,
        132,
        59,
        154,
        202,
        0,
        131,
        30,
        132,
        128,
        148,
        31,
        152,
        64,
        168,
        93,
        90,
        245,
        191,
        29,
        23,
        98,
        249,
        37,
        189,
        173,
        220,
        66,
        1,
        249,
        132,
        136,
        1,
        99,
        69,
        120,
        93,
        138,
        0,
        0,
        131,
        171,
        205,
        239,
        1,
        128,
        128
    ]
        .span();

    let tx = EthTransactionImpl::decode_legacy_tx(data).unwrap();

    assert(tx.nonce == 0, 'nonce is not 0');
    assert(tx.gas_price == 0x3b9aca00, 'gas_price is not 0x3b9aca00');
    assert(tx.gas_limit == 0x1e8480, 'gas_limit is not 0x1e8480');
    assert(
        tx.destination.address == 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,
        'destination is not 0x1f9840...'
    );
    assert(tx.amount == 0x016345785d8a0000, 'amount is not 0x016345785d8...');

    let expected_payload = bytes_to_felt252_array(0xabcdef_u32.to_bytes());
    assert(tx.payload == expected_payload, 'payload is not 0xabcdef');

    assert(tx.chain_id == 0x1, 'chain id is not 0x1');

    assert(
        tx.msg_hash == 0x89d3071d2bcc98141b16317ec8d912a76271ec052c2884674ddcd752b5ea91fe,
        'message hash it not 0x89d3...'
    );
}
