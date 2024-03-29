fn legacy_rlp_encoded_tx() -> Span<u8> {
    // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    // expected rlp decoding:  [ '0x', '0x3b9aca00', '0x1e8480', '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', '0x016345785d8a0000', '0xabcdef', '0x434841494e5f4944', '0x', '0x' ]
    // message_hash: 0x1026be08dc5113457dc5550128d53b1d2b2b6418ffe098468f805ecdcf34efd1
    // chain id used: 0x434841494e5f4944
    array![
        247,
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
        136,
        67,
        72,
        65,
        73,
        78,
        95,
        73,
        68,
        128,
        128
    ]
        .span()
}

fn legacy_rlp_encoded_deploy_tx() -> Span<u8> {
    // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    // expected rlp decoding:  ["0x","0x0a","0x061a80","0x","0x0186a0","0x600160010a5060006000f3","0x4b4b5254","0x","0x"]
    array![
        0xde,
        0x80,
        0x0a,
        0x83,
        0x06,
        0x1a,
        0x80,
        0x80,
        0x83,
        0x01,
        0x86,
        0xa0,
        0x8b,
        0x60,
        0x01,
        0x60,
        0x01,
        0x0a,
        0x50,
        0x60,
        0x00,
        0x60,
        0x00,
        0xf3,
        0x84,
        0x4b,
        0x4b,
        0x52,
        0x54,
        0x80,
        0x80
    ]
        .span()
}


fn eip_2930_encoded_tx() -> Span<u8> {
    // tx_format (EIP-2930, unsigned): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
    // expected rlp decoding:   [ "0x434841494e5f4944", "0x", "0x3b9aca00", "0x1e8480", "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef", [["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65", "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ]
    // message_hash: 0xc00f61dcc99a78934275c404267b9d035cad7f71cf3ae2ed2c5a55b601a5c107
    // chain id used: 0x434841494e5f4944
    array![
        1,
        248,
        146,
        136,
        67,
        72,
        65,
        73,
        78,
        95,
        73,
        68,
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
        248,
        91,
        248,
        89,
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
        248,
        66,
        160,
        222,
        159,
        190,
        53,
        121,
        11,
        133,
        194,
        63,
        66,
        183,
        67,
        12,
        120,
        241,
        34,
        99,
        103,
        80,
        204,
        33,
        122,
        83,
        76,
        128,
        169,
        160,
        82,
        9,
        105,
        250,
        101,
        160,
        213,
        54,
        46,
        148,
        19,
        111,
        118,
        191,
        200,
        218,
        208,
        181,
        16,
        185,
        69,
        97,
        175,
        122,
        56,
        127,
        26,
        157,
        13,
        69,
        231,
        119,
        193,
        25,
        98,
        229,
        189,
        148
    ]
        .span()
}

fn eip_1559_encoded_tx() -> Span<u8> {
    // tx_format (EIP-1559, unsigned):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list])
    // expected rlp decoding: [ "0x434841494e5f4944", "0x", "0x", "0x3b9aca00", "0x1e8480", "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef", [[["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65", "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ] ]
    // message_hash: 0xa2de478d0c94b4be637523b818d03b6a1841fca63fd044976fcdbef3c57a87b0
    // chain id used: 0x434841494e5f4944
    array![
        2,
        248,
        147,
        136,
        67,
        72,
        65,
        73,
        78,
        95,
        73,
        68,
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
        248,
        91,
        248,
        89,
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
        248,
        66,
        160,
        222,
        159,
        190,
        53,
        121,
        11,
        133,
        194,
        63,
        66,
        183,
        67,
        12,
        120,
        241,
        34,
        99,
        103,
        80,
        204,
        33,
        122,
        83,
        76,
        128,
        169,
        160,
        82,
        9,
        105,
        250,
        101,
        160,
        213,
        54,
        46,
        148,
        19,
        111,
        118,
        191,
        200,
        218,
        208,
        181,
        16,
        185,
        69,
        97,
        175,
        122,
        56,
        127,
        26,
        157,
        13,
        69,
        231,
        119,
        193,
        25,
        98,
        229,
        189,
        148
    ]
        .span()
}
