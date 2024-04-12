#[cfg(test)]
mod test_external_owned_account {
    use contracts::eoa::ExternallyOwnedAccount::TransactionExecuted;
    use contracts::eoa::{
        IExternallyOwnedAccount, ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
        IExternallyOwnedAccountDispatcherTrait
    };
    use contracts::kakarot_core::kakarot::StoredAccountType;
    use contracts::kakarot_core::{
        IKakarotCore, KakarotCore, KakarotCore::KakarotCoreInternal,
        interface::IExtendedKakarotCoreDispatcherTrait
    };
    use contracts::tests::test_data::{counter_evm_bytecode, eip_2930_rlp_encoded_counter_inc_tx,};
    use contracts::tests::test_upgradeable::{
        IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait,
        MockContractUpgradeableV1
    };
    use contracts::tests::test_utils::{
        setup_contracts_for_testing, deploy_eoa, deploy_contract_account, pop_log, pop_log_debug,
        fund_account_with_native_token, call_transaction
    };
    use contracts::uninitialized_account::{
        IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait, UninitializedAccount,
        IUninitializedAccount, UninitializedAccount::upgradeable_component
    };
    use core::array::SpanTrait;
    use core::box::BoxTrait;
    use core::starknet::account::{Call, AccountContractDispatcher, AccountContractDispatcherTrait};

    use evm::model::{Address, AddressTrait};
    use evm::tests::test_utils::{
        kakarot_address, evm_address, other_evm_address, other_starknet_address, eoa_address,
        chain_id, tx_gas_limit, gas_price, VMBuilderTrait
    };
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
    use utils::helpers::EthAddressSignatureTrait;
    use utils::helpers::{U8SpanExTrait, u256_to_bytes_array};
    use utils::tests::test_data::{legacy_rlp_encoded_tx, eip_2930_encoded_tx, eip_1559_encoded_tx};


    #[test]
    fn test_kakarot_address() {
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;

        let eoa_contract = deploy_eoa(eoa_address());

        assert(eoa_contract.kakarot_core_address() == kakarot_address, 'wrong kakarot_address');
    }

    #[test]
    fn test_evm_address() {
        let expected_address: EthAddress = eoa_address();
        setup_contracts_for_testing();

        let eoa_contract = deploy_eoa(eoa_address());

        assert(eoa_contract.evm_address() == expected_address, 'wrong evm_address');
    }

    #[test]
    fn test_eoa_upgrade() {
        setup_contracts_for_testing();
        let eoa_contract = deploy_eoa(eoa_address());

        let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH
            .try_into()
            .unwrap();

        set_contract_address(eoa_contract.contract_address);

        eoa_contract.upgrade(new_class_hash);

        let version = IMockContractUpgradeableDispatcher {
            contract_address: eoa_contract.contract_address
        }
            .version();
        assert(version == 1, 'version is not 1');
    }

    #[test]
    #[should_panic(expected: ('Caller not self', 'ENTRYPOINT_FAILED'))]
    fn test_eoa_upgrade_from_noncontractaddress() {
        setup_contracts_for_testing();
        let eoa_contract = deploy_eoa(eoa_address());
        let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH
            .try_into()
            .unwrap();

        eoa_contract.upgrade(new_class_hash);
    }

    #[test]
    #[available_gas(200000000000000)]
    fn test___execute__() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        fund_account_with_native_token(eoa, native_token, 0xfffffffffffffffffffffffffff);

        pop_log::<upgradeable_component::ContractUpgraded>(eoa)
            .unwrap(); // pop ContractUpgraded event from event log

        let kakarot_address = kakarot_core.contract_address;

        deploy_contract_account(other_evm_address(), counter_evm_bytecode());

        set_contract_address(eoa);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        // Then
        // selector: function get()
        let data_get_tx = array![0x6d, 0x4c, 0xe6, 0x3c].span();

        // check counter value is 0 before doing inc
        let tx = call_transaction(
            kakarot_core.chain_id(), Option::Some(other_evm_address()), data_get_tx
        );

        let (return_data, _) = kakarot_core
            .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx),);

        assert_eq!(return_data, u256_to_bytes_array(0).span());

        // perform inc on the counter
        let encoded_tx = eip_2930_rlp_encoded_counter_inc_tx();

        let call = Call {
            to: kakarot_address,
            selector: selector!("eth_send_transaction"),
            calldata: encoded_tx.to_felt252_array().span()
        };

        starknet::testing::set_transaction_hash(selector!("transaction_hash"));
        let result = eoa_contract.__execute__(array![call]);
        assert_eq!(result.len(), 1);

        let tx_info = get_tx_info().unbox();

        let event = pop_log_debug::<TransactionExecuted>(eoa).unwrap();

        assert_eq!(event.hash, tx_info.transaction_hash.into());

        assert_eq!(event.response, *result.span()[0]);

        assert_eq!(event.success, true);

        // check counter value has increased
        let tx = call_transaction(
            kakarot_core.chain_id(), Option::Some(other_evm_address()), data_get_tx
        );
        let (return_data, _) = kakarot_core
            .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx),);
        assert_eq!(return_data, u256_to_bytes_array(1).span());
    }

    #[test]
    #[should_panic(expected: ('calls length is not 1', 'ENTRYPOINT_FAILED'))]
    fn test___execute___should_fail_with_zero_calls() {
        setup_contracts_for_testing();

        let eoa_contract = deploy_eoa(eoa_address());
        let eoa_contract = AccountContractDispatcher {
            contract_address: eoa_contract.contract_address
        };

        eoa_contract.__execute__(array![]);
    }

    #[test]
    #[should_panic(expected: ('Caller not 0', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__caller_not_0() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_contract_address(other_starknet_address());

        let calls = array![];
        eoa_contract.__validate__(calls);
    }

    #[test]
    #[should_panic(expected: ('call len is not 1', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__call_data_len_not_1() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_contract_address(contract_address_const::<0>());

        let calls = array![];
        eoa_contract.__validate__(calls);
    }

    #[test]
    #[should_panic(expected: ('to is not kakarot core', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__to_address_not_kakarot_core() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

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
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_call"),
            calldata: array![].span()
        };

        eoa_contract.__validate__(array![call]);
    }

    #[test]
    fn test___validate__legacy_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0xaae7c4f6e4caa03257e37a6879ed5b51a6f7db491d559d10a0594f804aa8d797,
            s: 0x2f3d9634f8cb9b9a43b048ee3310be91c2d3dc3b51a3313b473ef2260bbf6bc7,
            y_parity: true
        };
        set_signature(
            signature.try_into_felt252_array(TransactionType::Legacy, chain_id).unwrap().span()
        );

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: legacy_rlp_encoded_tx().to_felt252_array().span()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }

    #[test]
    fn test___validate__eip_2930_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0xae2dbf7b1e1bdee326066be5afcfb673fe3d1287ef5d5973d4a83025b72bad1e,
            s: 0x48ecf8bc7153513fce782a1f369a8cd3ee9132fc062eb0558cf7102973624774,
            y_parity: false
        };

        set_signature(
            signature.try_into_felt252_array(TransactionType::EIP2930, chain_id).unwrap().span()
        );

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: eip_2930_encoded_tx().to_felt252_array().span()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }

    #[test]
    fn test___validate__eip_1559_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_chain_id(chain_id().into());
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let chain_id = vm.env.chain_id;

        // to reproduce locally:
        // run: cp .env.example .env
        // bun install & bun run scripts/compute_rlp_encoding.ts
        let signature = Signature {
            r: 0x141615694556f9078d9da3249e8aa1987524f57153121599cf36d7681b809858,
            s: 0x052052478f912dbe80339e3f198be8c9e1cd44eaabb295d912087d975ef38192,
            y_parity: false
        };

        set_signature(
            signature.try_into_felt252_array(TransactionType::EIP1559, chain_id).unwrap().span()
        );

        set_contract_address(contract_address_const::<0>());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: eip_1559_encoded_tx().to_felt252_array().span()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }
}
