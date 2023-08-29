// tests go here

#[cfg(test)]
mod test_external_owned_account {
    use eoa::externally_owned_account::{
        IExternallyOwnedAccount, ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
        IExternallyOwnedAccountDispatcherTrait
    };
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::{deploy_syscall, ContractAddress, get_contract_address, contract_address_const};
    // Use debug print trait to be able to print result if needed.
    use debug::PrintTrait;
    use array::{ArrayTrait};
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use starknet::EthAddress;

    // Use starknet test utils to fake the transaction context.
    use starknet::testing::{set_caller_address, set_contract_address};

    fn deploy_external_owned_account() -> IExternallyOwnedAccountDispatcher {
        let mut calldata = ArrayTrait::new();
        // Declare and deploy
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
        set_contract_address(owner);

        let external_owner_account_contract = deploy_external_owned_account();

        assert(
            external_owner_account_contract.bytecode() == ArrayTrait::<u8>::new().span(),
            'wrong bytecode'
        );
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_bytecode_len() {
        let owner = contract_address_const::<1>();
        set_contract_address(owner);

        let external_owner_account_contract = deploy_external_owned_account();
        let value: u32 = 0;

        assert(external_owner_account_contract.bytecode_len() == value, 'wrong bytecode');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_get_evm_address(){
        let owner = contract_address_const::<1>();
        set_contract_address(owner);

        let external_owner_account_contract = deploy_external_owned_account();
        let address: EthAddress = 0.try_into().unwrap();

        assert(
            external_owner_account_contract.get_evm_address() == address,
            'wrong evm address'
        );
    }
}
