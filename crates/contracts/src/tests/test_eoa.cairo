#[cfg(test)]
mod test_external_owned_account {
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
        setup_contracts_for_testing, deploy_eoa, deploy_contract_account
    };
    use contracts::uninitialized_account::{
        IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait, UninitializedAccount,
        IUninitializedAccount
    };
    use core::array::SpanTrait;
    use core::starknet::account::{Call, AccountContractDispatcher, AccountContractDispatcherTrait};

    use evm::model::{Address, AddressTrait, ContractAccountTrait};
    use evm::tests::test_utils::{
        kakarot_address, evm_address, other_evm_address, other_starknet_address, eoa_address,
        chain_id, gas_limit, gas_price
    };
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::{set_caller_address, set_contract_address, set_signature};
    use starknet::{
        deploy_syscall, ContractAddress, ClassHash, VALIDATED, get_contract_address,
        contract_address_const, EthAddress, eth_signature::{Signature}
    };
    use utils::helpers::EthAddressSignatureTrait;
    use utils::helpers::{U8SpanExTrait, u256_to_bytes_array};
    use utils::tests::test_data::{legacy_rlp_encoded_tx, eip_2930_encoded_tx, eip_1559_encoded_tx};


    #[test]
    #[available_gas(2000000000)]
    fn test_kakarot_address() {
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;

        let eoa_contract = deploy_eoa(eoa_address());

        assert(eoa_contract.kakarot_core_address() == kakarot_address, 'wrong kakarot_address');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_evm_address() {
        let owner = contract_address_const::<1>();
        let expected_address: EthAddress = eoa_address();
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;

        let eoa_contract = deploy_eoa(eoa_address());

        assert(eoa_contract.evm_address() == expected_address, 'wrong evm_address');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_eoa_upgrade() {
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;
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
    #[available_gas(2000000000)]
    #[should_panic(expected: ('Caller not self', 'ENTRYPOINT_FAILED'))]
    fn test_eoa_upgrade_from_noncontractaddress() {
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;
        let eoa_contract = deploy_eoa(eoa_address());
        let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH
            .try_into()
            .unwrap();

        eoa_contract.upgrade(new_class_hash);
    }

    #[test]
    #[available_gas(2000000000)]
    fn test___execute__() {
        let (_, kakarot_core) = setup_contracts_for_testing();

        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);

        let kakarot_address = kakarot_core.contract_address;

        let account = deploy_contract_account(other_evm_address(), counter_evm_bytecode());

        set_contract_address(eoa);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        // Then
        // selector: function get()
        let data_get_tx = array![0x6d, 0x4c, 0xe6, 0x3c].span();

        // check counter value is 0 before doing inc
        let return_data = kakarot_core
            .eth_call(
                origin: evm_address,
                to: Option::Some(other_evm_address()),
                gas_limit: gas_limit(),
                gas_price: gas_price(),
                value: 0,
                calldata: data_get_tx
            );

        assert(return_data == u256_to_bytes_array(0).span(), 'counter value not 0');

        // perform inc on the counter
        let encoded_tx = eip_2930_rlp_encoded_counter_inc_tx();

        let call = Call {
            to: kakarot_address,
            selector: selector!("eth_send_transaction"),
            calldata: encoded_tx.to_felt252_array()
        };

        let result = eoa_contract.__execute__(array![call]);

        // check counter value has increased
        let return_data = kakarot_core
            .eth_call(
                origin: evm_address,
                to: Option::Some(other_evm_address()),
                gas_limit: gas_limit(),
                gas_price: gas_price(),
                value: 0,
                calldata: data_get_tx
            );

        assert(return_data == u256_to_bytes_array(1).span(), 'counter value not 1');
    }

    #[test]
    #[available_gas(2000000000)]
    #[should_panic(expected: ('calls length is not 1', 'ENTRYPOINT_FAILED'))]
    fn test___execute___should_fail_with_zero_calls() {
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;

        let eoa_contract = deploy_eoa(eoa_address());
        let eoa_contract = AccountContractDispatcher {
            contract_address: eoa_contract.contract_address
        };

        eoa_contract.__execute__(array![]);
    }

    #[test]
    #[available_gas(2000000000)]
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
    #[available_gas(2000000000)]
    #[should_panic(expected: ('call len is not 1', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__call_data_len_not_1() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_contract_address(0_felt252.try_into().unwrap());

        let calls = array![];
        eoa_contract.__validate__(calls);
    }

    #[test]
    #[available_gas(2000000000)]
    #[should_panic(expected: ('to is not kakarot core', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__to_address_not_kakarot_core() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_contract_address(0_felt252.try_into().unwrap());

        let call = Call {
            to: other_starknet_address(),
            selector: selector!("eth_send_transaction"),
            calldata: array![]
        };

        eoa_contract.__validate__(array![call]);
    }

    #[test]
    #[available_gas(2000000000)]
    #[should_panic(expected: ('selector not eth_send_transa...', 'ENTRYPOINT_FAILED'))]
    fn test___validate__fail__selector_not_eth_send_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address = evm_address();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        set_contract_address(0.try_into().unwrap());

        let call = Call {
            to: kakarot_core.contract_address, selector: selector!("eth_call"), calldata: array![]
        };

        eoa_contract.__validate__(array![call]);
    }

    #[test]
    #[available_gas(2000000000)]
    fn test___validate__legacy_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        let signature = Signature {
            r: 0xaae7c4f6e4caa03257e37a6879ed5b51a6f7db491d559d10a0594f804aa8d797,
            s: 0x2f3d9634f8cb9b9a43b048ee3310be91c2d3dc3b51a3313b473ef2260bbf6bc7,
            y_parity: true
        };
        set_signature(signature.to_felt252_array().span());

        set_contract_address(0.try_into().unwrap());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: legacy_rlp_encoded_tx().to_felt252_array()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test___validate__eip_2930_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        let signature = Signature {
            r: 0x96a5512ce388874338c3825959674c130a7cde2317ab0c2312e9e687d15fc373,
            s: 0x12d0b91acc6c7683186f746b8d0a39991911cca2ab99fc84b2a1652792a15249,
            y_parity: true
        };

        set_signature(signature.to_felt252_array().span());

        set_contract_address(0.try_into().unwrap());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: eip_2930_encoded_tx().to_felt252_array()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test___validate__eip_1559_transaction() {
        let (_, kakarot_core) = setup_contracts_for_testing();
        let evm_address: EthAddress = 0x6Bd85F39321B00c6d603474C5B2fddEB9c92A466_u256.into();
        let eoa = kakarot_core.deploy_eoa(evm_address);
        let eoa_contract = AccountContractDispatcher { contract_address: eoa };

        let signature = Signature {
            r: 0x3e1d21af857363cb69f565cf5a791b6e326186250815570c80bd2b7f465802f8,
            s: 0x37a9cec24f7d5c8916ded76f702fcf2b93a20b28a7db8f27d7f4e6e11288bda4,
            y_parity: true
        };

        set_signature(signature.to_felt252_array().span());

        set_contract_address(0.try_into().unwrap());

        let call = Call {
            to: kakarot_core.contract_address,
            selector: selector!("eth_send_transaction"),
            calldata: eip_1559_encoded_tx().to_felt252_array()
        };

        let result = eoa_contract.__validate__(array![call]);
        assert(result == VALIDATED, 'validation failed');
    }
}
