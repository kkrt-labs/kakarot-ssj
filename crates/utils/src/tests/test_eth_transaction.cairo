use core::debug::PrintTrait;
use utils::eth_transaction::{EthTransactionImpl};

#[test]
#[available_gas(200000000)]
fn test_decode_legacy_tx() {
    // tx_format (EIP-155): [nonce, gasPrice, gasLimit, to, value, data, v, r, s]
    // expected rlp decoding: [ '0x', '0x3b9aca00', '0x', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0x', '0x1c', '0x91e283d61077eb36340a1109a03bdbd6c0c4ea4c3d74537bc42f672095bcf5a1', '0x6b93acdc99dea855d15c75f7f6bdf4250784ef01ebc70642f45cdf044e0e2623']
    // transaction_hash: 0x567fd100cfbb0f781df1c98e84ae57de817684536abe34deb8957eaafd9f417a
    // chain id used: 0x1
    let data = array![
        248,
        105,
        128,
        132,
        59,
        154,
        202,
        0,
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
        128,
        28,
        160,
        145,
        226,
        131,
        214,
        16,
        119,
        235,
        54,
        52,
        10,
        17,
        9,
        160,
        59,
        219,
        214,
        192,
        196,
        234,
        76,
        61,
        116,
        83,
        123,
        196,
        47,
        103,
        32,
        149,
        188,
        245,
        161,
        160,
        107,
        147,
        172,
        220,
        153,
        222,
        168,
        85,
        209,
        92,
        117,
        247,
        246,
        189,
        244,
        37,
        7,
        132,
        239,
        1,
        235,
        199,
        6,
        66,
        244,
        92,
        223,
        4,
        78,
        14,
        38,
        35
    ]
        .span();

    let tx = EthTransactionImpl::decode_legacy_tx(data);

    assert(tx.nonce == 0, 'nonce is not 0');
    assert(tx.gas_price == 0x3b9aca00, 'gas_price is not 0x3b9aca00');
    assert(tx.gas_limit == 0, 'gas_limit is not 0');
    assert(
        tx.destination.address == 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984,
        'destination is not 0x1f9840...'
    );
    assert(tx.amount == 0x016345785d8a0000, 'amount is not 0x016345785d8...');
    assert(tx.v == 0x1c, 'v is not 0x1c');
    assert(
        tx.r == 0x91e283d61077eb36340a1109a03bdbd6c0c4ea4c3d74537bc42f672095bcf5a1,
        'r is not 0x91e283d610...'
    );
    assert(
        tx.s == 0x6b93acdc99dea855d15c75f7f6bdf4250784ef01ebc70642f45cdf044e0e2623,
        's is not 0x6b93acdc99...'
    );

    assert(
        tx.tx_hash == 0x567fd100cfbb0f781df1c98e84ae57de817684536abe34deb8957eaafd9f417a,
        'transaction hash it not 0x56...'
    );
}
