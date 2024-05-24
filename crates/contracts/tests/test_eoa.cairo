#[cfg(test)]
mod test_external_owned_account {
    use contracts::account_contract::AccountContract::TransactionExecuted;
    use contracts::account_contract::{AccountContract, IAccountDispatcher, IAccountDispatcherTrait};
    use contracts::kakarot_core::{
        IKakarotCore, KakarotCore, KakarotCore::KakarotCoreInternal,
        interface::IExtendedKakarotCoreDispatcherTrait
    };
    use contracts::test_data::{counter_evm_bytecode, eip_2930_rlp_encoded_counter_inc_tx,};
    use contracts_test::test_utils::evm_utils::{
        kakarot_address, evm_address, other_evm_address, other_starknet_address, eoa_address,
        chain_id, tx_gas_limit, gas_price, VMBuilderTrait
    };
    use contracts_test::test_utils::evm_utils::{
        setup_contracts_for_testing, deploy_eoa, deploy_contract_account, pop_log, pop_log_debug,
        fund_account_with_native_token, call_transaction
    };
    use contracts_tests::test_upgradeable::{
        IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait,
        MockContractUpgradeableV1
    };
    use core::array::SpanTrait;
    use core::box::BoxTrait;
    use core::starknet::account::{Call};

    use evm::model::{Address, AddressTrait};
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::{set_caller_address, set_contract_address, set_signature, set_chain_id};
    use starknet::{
        deploy_syscall, ContractAddress, ClassHash, VALIDATED, get_contract_address,
        contract_address_const, EthAddress, eth_signature::{Signature}, get_tx_info
    };
    use utils::eth_transaction::{
        TransactionType, EthereumTransaction, EthereumTransactionTrait, LegacyTransaction
    };
    use utils::helpers::{U8SpanExTrait, u256_to_bytes_array};
    use utils::serialization::{serialize_bytes, serialize_transaction_signature};
    use utils::test_data::{legacy_rlp_encoded_tx, eip_2930_encoded_tx, eip_1559_encoded_tx};


    #[test]
    fn test_get_evm_address() {
        let expected_address: EthAddress = eoa_address();
        setup_contracts_for_testing();

        let eoa_contract = deploy_eoa(eoa_address());

        assert(eoa_contract.get_evm_address() == expected_address, 'wrong evm_address');
    }

    #[test]
    #[available_gas(200000000000000)]
    fn test___execute__a() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        // pop ownership transfer event
        core::starknet::testing::pop_log_raw(eoa);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);

        let kakarot_address = kakarot_core.contract_address;

        deploy_contract_account(other_evm_address(), counter_evm_bytecode());

        set_contract_address(eoa);
        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        // Then
        // selector: function get()
        let data_get_tx = array![0x6d, 0x4c, 0xe6, 0x3c].span();

        // check counter value is 0 before doing inc
        let tx = call_transaction(chain_id(), Option::Some(other_evm_address()), data_get_tx);

        let (_, return_data) = kakarot_core
            .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx),);

        assert_eq!(return_data, u256_to_bytes_array(0).span());

        // perform inc on the counter
        let encoded_tx = eip_2930_rlp_encoded_counter_inc_tx();

        let call = Call {
            to: kakarot_address,
            selector: selector!("eth_send_transaction"),
            calldata: serialize_bytes(encoded_tx).span()
        };

        starknet::testing::set_transaction_hash(selector!("transaction_hash"));
        set_contract_address(contract_address_const::<0>());
        let result = eoa_contract.__execute__(array![call]);
        assert_eq!(result.len(), 1);

        let event = pop_log_debug::<TransactionExecuted>(eoa).unwrap();

        assert_eq!(event.response, *result.span()[0]);
        assert_eq!(event.success, true);
        assert_ne!(event.gas_used, 0);

        // check counter value has increased
        let tx = call_transaction(chain_id(), Option::Some(other_evm_address()), data_get_tx);
        let (_, return_data) = kakarot_core
            .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx),);
        assert_eq!(return_data, u256_to_bytes_array(1).span());
    }

    #[test]
    #[should_panic(expected: ('EOA: multicall not supported', 'ENTRYPOINT_FAILED'))]
    fn test___execute___should_fail_with_zero_calls() {
        setup_contracts_for_testing();

        let eoa_contract = deploy_eoa(eoa_address());
        let eoa_contract = IAccountDispatcher { contract_address: eoa_contract.contract_address };

        set_contract_address(contract_address_const::<0>());
        eoa_contract.__execute__(array![]);
    }

    #[test]
    #[should_panic(expected: ('EOA: reentrant call', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__caller_not_0() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);
        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        set_contract_address(other_starknet_address());

        let calls = array![];
        eoa_contract.__validate__(calls);
    }

    #[test]
    #[should_panic(expected: ('EOA: multicall not supported', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__call_data_len_not_1() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);
        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        set_contract_address(contract_address_const::<0>());

        let calls = array![];
        eoa_contract.__validate__(calls);
    }

    #[test]
    #[should_panic(expected: ('to is not kakarot core', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__to_address_not_kakarot_core() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);
        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0xaae7c4f6e4caa03257e37a6879ed5b51a6f7db491d559d10a0594f804aa8d797,
            s: 0x2f3d9634f8cb9b9a43b048ee3310be91c2d3dc3b51a3313b473ef2260bbf6bc7,
            y_parity: true
        };
        set_signature(
            serialize_transaction_signature(signature, TransactionType::Legacy, 1).span()
        );
        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: other_starknet_address(),
            selector: selector!("eth_send_transaction"),
            calldata: array![].span()
        };

        eoa_contract.__validate__(array![call]);
    }

    #[test]
    #[should_panic(
        expected: ("Validate: selector must be eth_send_transaction", 'ENTRYPOINT_FAILED')
    )]
    fn test___validate__fail__selector_not_eth_send_transaction() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);
        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;
        set_contract_address(contract_address_const::<0>());

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0xaae7c4f6e4caa03257e37a6879ed5b51a6f7db491d559d10a0594f804aa8d797,
            s: 0x2f3d9634f8cb9b9a43b048ee3310be91c2d3dc3b51a3313b473ef2260bbf6bc7,
            y_parity: true
        };
        set_signature(
            serialize_transaction_signature(signature, TransactionType::Legacy, chain_id).span()
        );

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_call"),
            calldata: array![].span()
        };

        eoa_contract.__validate__(array![call]);
    }

    #[test]
    fn test___validate__legacy_transaction() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf_u256.into();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);

        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x5e5202c7e9d6d0964a1f48eaecf12eef1c3cafb2379dfeca7cbd413cedd4f2c7,
            s: 0x66da52d0b666fc2a35895e0c91bc47385fe3aa347c7c2a129ae2b7b06cb5498b,
            y_parity: false
        };
        set_signature(
            serialize_transaction_signature(signature, TransactionType::Legacy, chain_id).span()
        );

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: serialize_bytes(legacy_rlp_encoded_tx()).span()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }

    #[test]
    fn test___validate__eip_2930_transaction() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf_u256.into();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);

        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0xbced8d81c36fe13c95b883b67898b47b4b70cae79e89fa27856ddf8c533886d1,
            s: 0x3de0109f00bc3ed95ffec98edd55b6f750cb77be8e755935dbd6cfec59da7ad0,
            y_parity: true
        };

        set_signature(
            serialize_transaction_signature(signature, TransactionType::EIP2930, chain_id).span()
        );

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: serialize_bytes(eip_2930_encoded_tx()).span()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }

    #[test]
    fn test___validate__eip_1559_transaction() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf_u256.into();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);

        let eoa_contract = IAccountDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x0f9a716653c19fefc240d1da2c5759c50f844fc8835c82834ea3ab7755f789a0,
            s: 0x71506d904c05c6e5ce729b5dd88bcf29db9461c8d72413b864923e8d8f6650c0,
            y_parity: true
        };

        set_signature(
            serialize_transaction_signature(signature, TransactionType::EIP1559, chain_id).span()
        );

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: serialize_bytes(eip_1559_encoded_tx()).span()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }
}
