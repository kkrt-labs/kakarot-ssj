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
    use contracts::tests::test_upgradeable::{
        IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait,
        MockContractUpgradeableV1
    };
    use contracts::tests::test_utils::deploy_contract_account;
    use contracts::tests::test_utils::{setup_contracts_for_testing};
    use contracts::uninitialized_account::{
        IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait, UninitializedAccount,
        IUninitializedAccount
    };
    use core::array::SpanTrait;
    use core::starknet::account::{Call, AccountContractDispatcher, AccountContractDispatcherTrait};

    use evm::model::{Address, AddressTrait, ContractAccountTrait};
    use evm::tests::test_utils::{
        kakarot_address, evm_address, other_evm_address, eoa_address, chain_id, gas_limit, gas_price
    };
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::{
        deploy_syscall, ContractAddress, ClassHash, get_contract_address, contract_address_const,
        EthAddress
    };
    use utils::helpers::{U8SpanExTrait, u256_to_bytes_array};

    fn deploy_eoa(eoa_address: EthAddress) -> IExternallyOwnedAccountDispatcher {
        let kakarot_address = get_contract_address();
        let calldata: Span<felt252> = array![kakarot_address.into(), eoa_address.into()].span();

        let (starknet_address, _) = deploy_syscall(
            UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(),
            evm_address().into(),
            calldata,
            false
        )
            .expect('failed to deploy EOA');

        let account = IUninitializedAccountDispatcher { contract_address: starknet_address };

        account.initialize(ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap());
        let eoa = IExternallyOwnedAccountDispatcher { contract_address: starknet_address };
        eoa.set_chain_id(chain_id());
        eoa
    }

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
    fn test_execute() {
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
                from: evm_address,
                to: Option::Some(other_evm_address()),
                gas_limit: gas_limit(),
                gas_price: gas_price(),
                value: 0,
                data: data_get_tx
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

        let call = Call {
            to: kakarot_address,
            selector: selector!("eth_send_transaction"),
            calldata: encoded_tx.to_felt252_array()
        };

        // check counter value has increased
        let return_data = kakarot_core
            .eth_call(
                from: evm_address,
                to: Option::Some(other_evm_address()),
                gas_limit: gas_limit(),
                gas_price: gas_price(),
                value: 0,
                data: data_get_tx
            );

        assert(return_data == u256_to_bytes_array(1).span(), 'counter value not 1');
    }

    #[test]
    #[available_gas(2000000000)]
    #[should_panic(expected: ('calls length is not 1', 'ENTRYPOINT_FAILED'))]
    fn test_execute_should_fail_with_zero_calls() {
        let (_, kakarot) = setup_contracts_for_testing();
        let kakarot_address = kakarot.contract_address;

        let eoa_contract = deploy_eoa(eoa_address());
        let eoa_contract = AccountContractDispatcher {
            contract_address: eoa_contract.contract_address
        };

        eoa_contract.__execute__(array![]);
    }
}
