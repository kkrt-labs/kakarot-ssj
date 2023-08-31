#[cfg(test)]
mod test_external_owned_account {
    use eoa::externally_owned_account::{
        IExternallyOwnedAccount, ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
        IExternallyOwnedAccountDispatcherTrait
    };
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::{deploy_syscall, ContractAddress, get_contract_address, contract_address_const};
    use array::{ArrayTrait};
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;

    use starknet::testing::{set_caller_address, set_contract_address};

    fn deploy_eoa() -> IExternallyOwnedAccountDispatcher {
        let mut calldata = ArrayTrait::new();

        let (contract_address, _) = deploy_syscall(
            ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        IExternallyOwnedAccountDispatcher { contract_address }
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_bytecode() {
        let owner = contract_address_const::<1>();

        let eoa_contract = deploy_eoa();

        assert(eoa_contract.bytecode() == Default::default().span(), 'wrong bytecode');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_bytecode_len() {
        let owner = contract_address_const::<1>();

        let eoa_contract = deploy_eoa();

        assert(eoa_contract.bytecode_len() == 0, 'wrong bytecode');
    }
}
