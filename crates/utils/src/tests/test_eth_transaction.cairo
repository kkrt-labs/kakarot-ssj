use core::debug::PrintTrait;
use core::to_byte_array::FormatAsByteArray;
use core::traits::Destruct;
use utils::eth_transaction::{EthTransactionImpl};
use utils::helpers::{U32Trait, bytes_to_felt252_array};

#[test]
#[available_gas(200000000)]
fn test_decode_legacy_tx() {
    // tx_format (EIP-155): rlp([nonce, gasPrice, gasLimit, to, value, data, v, r, s])
    // expected rlp decoding:  [ '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', '0x25', '0x9f0140cbb368e853402d4a06ff1f9d1c40f90055fcda4ad357c750685042e342', '0x30da91d1bc8c89719bc4f22110f18ee9e79e60ab1bdfe8a3997a354670fb47bd']
    // transaction_hash: 0x63ff39fd8f15bcd883a9e11a8a823f110f54911b2666ac67016b15fd244415b9
    // chain id used: 0x1
    let data = array![
        248,
        111,
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
        37,
        160,
        159,
        1,
        64,
        203,
        179,
        104,
        232,
        83,
        64,
        45,
        74,
        6,
        255,
        31,
        157,
        28,
        64,
        249,
        0,
        85,
        252,
        218,
        74,
        211,
        87,
        199,
        80,
        104,
        80,
        66,
        227,
        66,
        160,
        48,
        218,
        145,
        209,
        188,
        140,
        137,
        113,
        155,
        196,
        242,
        33,
        16,
        241,
        142,
        233,
        231,
        158,
        96,
        171,
        27,
        223,
        232,
        163,
        153,
        122,
        53,
        70,
        112,
        251,
        71,
        189
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

    assert(tx.v == 0x25, 'v is not 0x25');
    assert(
        tx.r == 0x9f0140cbb368e853402d4a06ff1f9d1c40f90055fcda4ad357c750685042e342,
        'r is not 0x9f0140c...'
    );
    assert(
        tx.s == 0x30da91d1bc8c89719bc4f22110f18ee9e79e60ab1bdfe8a3997a354670fb47bd,
        's is not 0x30da91d1...'
    );

    assert(
        tx.tx_hash == 0x63ff39fd8f15bcd883a9e11a8a823f110f54911b2666ac67016b15fd244415b9,
        'transaction hash it not 0x63...'
    );
}


#[test]
#[available_gas(200000000)]
fn test_decode_eip_2930_tx() {
    // tx_format (EIP-2930): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList, signatureYParity, signatureR, signatureS])
    // expected rlp decoding:  [ '0x01', '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', [], '0x', '0x14a38ea5e92fe6831b2137226418d03db2ab8cefd6f62bdfc0078787afa63f83', '0x6c89b2928b518445bef8d479167bb9aef73bab1871d1275fd8dcba3c1628a619']
    // transaction_hash: 0xfa4e6c015d94c219c4105cb2a8f4d2bfc9bad127ebbafbfcceab1b9a744ebcdb
    // chain id used: 0x1
    let data = array![
        1,
        248,
        113,
        1,
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
        192,
        128,
        160,
        20,
        163,
        142,
        165,
        233,
        47,
        230,
        131,
        27,
        33,
        55,
        34,
        100,
        24,
        208,
        61,
        178,
        171,
        140,
        239,
        214,
        246,
        43,
        223,
        192,
        7,
        135,
        135,
        175,
        166,
        63,
        131,
        160,
        108,
        137,
        178,
        146,
        139,
        81,
        132,
        69,
        190,
        248,
        212,
        121,
        22,
        123,
        185,
        174,
        247,
        59,
        171,
        24,
        113,
        209,
        39,
        95,
        216,
        220,
        186,
        60,
        22,
        40,
        166,
        25
    ]
        .span();

    let tx = EthTransactionImpl::decode_tx(data).unwrap();

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

    assert(tx.v == 0x0, 'v is not 0x0');
    assert(
        tx.r == 0x14a38ea5e92fe6831b2137226418d03db2ab8cefd6f62bdfc0078787afa63f83,
        'r is not 0x14a38ea...'
    );
    assert(
        tx.s == 0x6c89b2928b518445bef8d479167bb9aef73bab1871d1275fd8dcba3c1628a619,
        's is not 0x6c89b2...'
    );

    assert(
        tx.tx_hash == 0xfa4e6c015d94c219c4105cb2a8f4d2bfc9bad127ebbafbfcceab1b9a744ebcdb,
        'transaction hash it not 0xfa...'
    );
}


#[test]
#[available_gas(200000000)]
fn test_decode_eip_1559_tx() {
    // tx_format (EIP-1559): 0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list, signature_y_parity, signature_r, signature_s])
    // expected rlp decoding:    [ '0x01', '0x', '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', [], '0x', '0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a', '0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95']
    // transaction_hash: 0x7aabed1aa625aca3e573189906dc22c1993be09236167057fe78e6d8b13269d1
    // chain id used: 0x1
    let data = array![
        2,
        248,
        114,
        1,
        128,
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
        192,
        128,
        160,
        129,
        247,
        236,
        168,
        176,
        219,
        104,
        141,
        105,
        239,
        164,
        40,
        49,
        73,
        183,
        21,
        184,
        119,
        20,
        23,
        13,
        126,
        103,
        27,
        61,
        94,
        196,
        73,
        153,
        143,
        227,
        10,
        160,
        50,
        12,
        21,
        157,
        129,
        237,
        131,
        194,
        106,
        187,
        207,
        228,
        40,
        180,
        3,
        109,
        214,
        225,
        175,
        119,
        128,
        105,
        67,
        122,
        149,
        18,
        189,
        162,
        35,
        16,
        75,
        149
    ]
        .span();

    let tx = EthTransactionImpl::decode_tx(data).unwrap();

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

    assert(tx.v == 0x0, 'v is not 0x0');
    assert(
        tx.r == 0x81f7eca8b0db688d69efa4283149b715b87714170d7e671b3d5ec449998fe30a,
        'r is not 0x81f7eca8b0...'
    );
    assert(
        tx.s == 0x320c159d81ed83c26abbcfe428b4036dd6e1af778069437a9512bda223104b95,
        's is not 0x320c159d81ed...'
    );

    assert(
        tx.tx_hash == 0x7aabed1aa625aca3e573189906dc22c1993be09236167057fe78e6d8b13269d1,
        'transaction hash it not 0x7a...'
    );
}
