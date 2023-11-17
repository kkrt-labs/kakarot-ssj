#[cfg(test)]
mod test_external_owned_account {
    use contracts::eoa::{
        IExternallyOwnedAccount, ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
        IExternallyOwnedAccountDispatcherTrait
    };
    use contracts::tests::test_upgradeable::{
        IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait,
        MockContractUpgradeableV1
    };
    use contracts::uninitialized_account::{
        IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
    };
    use evm::tests::test_utils::{kakarot_address, evm_address, eoa_address, chain_id};
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::{
        deploy_syscall, ContractAddress, ClassHash, get_contract_address, contract_address_const,
        EthAddress
    };
    use evm::model::{Address, AddressTrait};
    use contracts::kakarot_core::{IKakarotCore, KakarotCore, KakarotCore::KakarotCoreInternal};
    use contracts::kakarot_core::kakarot::StoredAccountType;

    fn deploy_eoa() -> IExternallyOwnedAccountDispatcher {
        let calldata: Span<felt252> = array![kakarot_address().into(), eoa_address().into()].span();

        let evm_address = evm_address();
        let mut is_deployed = AddressTrait::is_registered(evm_address);

        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let account_class_hash = kakarot_state.account_class_hash();
        let kakarot_address = get_contract_address();
        let calldata: Span<felt252> = array![kakarot_address.into(), evm_address.into()].span();

        let starknet_address = deploy_syscall(account_class_hash, evm_address.into(), calldata, false).expect('failed to deploy EOA');

        match maybe_address {
            Result::Ok((
                starknet_address, _
            )) => {
                let account = IUninitializedAccountDispatcher {
                    contract_address: starknet_address
                };
                account.initialize(kakarot_state.eoa_class_hash());
                let eoa = IExternallyOwnedAccountDispatcher { contract_address: starknet_address };
                eoa.set_chain_id(kakarot_state.chain_id());
                kakarot_state
                    .set_address_registry(evm_address, StoredAccountType::EOA(starknet_address));
                return eoa;
            },
            Result::Err(err) => panic(err)
        }
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_kakarot_address() {
        let expected_address = kakarot_address();

        let eoa_contract = deploy_eoa();

        assert(eoa_contract.kakarot_core_address() == expected_address, 'wrong kakarot_address');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_evm_address() {
        let owner = contract_address_const::<1>();

        let expected_address: EthAddress = eoa_address();

        let eoa_contract = deploy_eoa();

        assert(eoa_contract.evm_address() == expected_address, 'wrong evm_address');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_eoa_upgrade() {
        let eoa_contract = deploy_eoa();
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
    #[should_panic(expected: ('Caller not contract address', 'ENTRYPOINT_FAILED'))]
    fn test_eoa_upgrade_from_noncontractaddress() {
        let eoa_contract = deploy_eoa();
        let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH
            .try_into()
            .unwrap();

        eoa_contract.upgrade(new_class_hash);
    }
}
