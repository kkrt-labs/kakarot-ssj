mod eth_signature_test {
    use starknet::eth_signature::Signature;
    use utils::constants::CHAIN_ID;
    use utils::eth_transaction::TransactionType;
    use utils::serialization::{deserialize_signature, serialize_transaction_signature};

    #[test]
    fn test_serialize_transaction_signature() {
        // generated via ./scripts/compute_rlp_encoding.ts
        // inputs:
        //          to: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
        //          value: 1
        //          gasLimit: 1
        //          gasPrice: 1
        //          nonce: 1
        //          chainId: 1263227476
        //          data: 0xabcdef
        //          tx_type: 0 for signature_0, 1 for signature_1, 2 for signature_2

        // tx_type = 0, v: 0x9696a4cb
        let signature_0 = Signature {
            r: 0x306c3f638450a95f1f669481bf8ede9b056ef8d94259a3104f3a28673e02823d,
            s: 0x41ea07e6d3d02773e380e752e5b3f9d28aca3882ee165e56b402cca0189967c9,
            y_parity: false
        };

        // tx_type = 1
        let signature_1 = Signature {
            r: 0x615c33039b7b09e3d5aa3cf1851c35abe7032f92111cc95ef45f83d032ccff5d,
            s: 0x30b5f1a58abce1c7d45309b7a3b0befeddd1aee203021172779dd693a1e59505,
            y_parity: false
        };

        // tx_type = 2
        let signature_2 = Signature {
            r: 0xbc485ed0b43483ebe5fbff90962791c015755cc03060a33360b1b3e823bb71a4,
            s: 0x4c47017509e1609db6c2e8e2b02327caeb709c986d8b63099695105432afa533,
            y_parity: false
        };

        let expected_signature_0: Span<felt252> = array![
            signature_0.r.low.into(),
            signature_0.r.high.into(),
            signature_0.s.low.into(),
            signature_0.s.high.into(),
            0x9696a4cb
        ]
            .span();

        let expected_signature_1: Span<felt252> = array![
            signature_1.r.low.into(),
            signature_1.r.high.into(),
            signature_1.s.low.into(),
            signature_1.s.high.into(),
            0x0_felt252,
        ]
            .span();

        let expected_signature_2: Span<felt252> = array![
            signature_2.r.low.into(),
            signature_2.r.high.into(),
            signature_2.s.low.into(),
            signature_2.s.high.into(),
            0x0_felt252,
        ]
            .span();

        let result = serialize_transaction_signature(signature_0, TransactionType::Legacy, CHAIN_ID)
            .span();
        assert_eq!(result, expected_signature_0);

        let result = serialize_transaction_signature(
            signature_1, TransactionType::EIP2930, CHAIN_ID
        )
            .span();
        assert_eq!(result, expected_signature_1);

        let result = serialize_transaction_signature(
            signature_2, TransactionType::EIP1559, CHAIN_ID
        )
            .span();
        assert_eq!(result, expected_signature_2);
    }

    #[test]
    fn test_deserialize_transaction_signature() {
        // generated via ./scripts/compute_rlp_encoding.ts
        // inputs:
        //          to: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
        //          value: 1
        //          gasLimit: 1
        //          gasPrice: 1
        //          nonce: 1
        //          chainId: 1263227476
        //          data: 0xabcdef
        //          tx_type: 0 for signature_0, 1 for signature_1, 2 for signature_2

        // tx_type = 0, v: 0x9696a4cb
        let signature_0 = Signature {
            r: 0x306c3f638450a95f1f669481bf8ede9b056ef8d94259a3104f3a28673e02823d,
            s: 0x41ea07e6d3d02773e380e752e5b3f9d28aca3882ee165e56b402cca0189967c9,
            y_parity: false
        };

        // tx_type = 1
        let signature_1 = Signature {
            r: 0x615c33039b7b09e3d5aa3cf1851c35abe7032f92111cc95ef45f83d032ccff5d,
            s: 0x30b5f1a58abce1c7d45309b7a3b0befeddd1aee203021172779dd693a1e59505,
            y_parity: false
        };

        // tx_type = 2
        let signature_2 = Signature {
            r: 0xbc485ed0b43483ebe5fbff90962791c015755cc03060a33360b1b3e823bb71a4,
            s: 0x4c47017509e1609db6c2e8e2b02327caeb709c986d8b63099695105432afa533,
            y_parity: false
        };

        let signature_0_felt252_arr: Array<felt252> = array![
            signature_0.r.low.into(),
            signature_0.r.high.into(),
            signature_0.s.low.into(),
            signature_0.s.high.into(),
            0x9696a4cb
        ];

        let signature_1_felt252_arr: Array<felt252> = array![
            signature_1.r.low.into(),
            signature_1.r.high.into(),
            signature_1.s.low.into(),
            signature_1.s.high.into(),
            0x0
        ];

        let signature_2_felt252_arr: Array<felt252> = array![
            signature_2.r.low.into(),
            signature_2.r.high.into(),
            signature_2.s.low.into(),
            signature_2.s.high.into(),
            0x0
        ];

        let result: Signature = deserialize_signature(signature_0_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_0);

        let result: Signature = deserialize_signature(signature_1_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_1);

        let result: Signature = deserialize_signature(signature_2_felt252_arr.span(), CHAIN_ID)
            .unwrap();
        assert_eq!(result, signature_2);
    }
}
