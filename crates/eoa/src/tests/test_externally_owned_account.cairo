#[cfg(test)]
mod test_external_owned_account {
    use eoa::externally_owned_account::{
        IExternallyOwnedAccount, ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
        IExternallyOwnedAccountDispatcherTrait
    };
    use evm::tests::test_utils::{kakarot_address, eoa_address};
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::{
        deploy_syscall, ContractAddress, get_contract_address, contract_address_const, EthAddress
    };

    fn deploy_eoa() -> IExternallyOwnedAccountDispatcher {
        let calldata: Span<felt252> = array![kakarot_address().into(), eoa_address().into()].span();

        let maybe_address = deploy_syscall(
            ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata, false
        );
        match maybe_address {
            Result::Ok((
                contract_address, _
            )) => { IExternallyOwnedAccountDispatcher { contract_address } },
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
}
