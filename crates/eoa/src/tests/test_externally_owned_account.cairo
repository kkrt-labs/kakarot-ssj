// tests go here

#[cfg(test)]
mod test_external_owned_account {
    use eoa::externally_owned_account::{
        IExternallyOwnedAccount, ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
        IExternallyOwnedAccountDispatcherTrait
    };
    use openzeppelin::token::erc20::{ERC20};
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::{deploy_syscall, ContractAddress, get_contract_address, contract_address_const};
    // Use debug print trait to be able to print result if needed.
    use debug::PrintTrait;
    use array::{ArrayTrait};
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use starknet::EthAddress;
    use serde::Serde;


    // Use starknet test utils to fake the transaction context.
    use starknet::testing::{set_caller_address, set_contract_address};

    fn deploy_erc20() -> (IERC20Dispatcher, ContractAddress) {
        let mut calldata: Array<felt252> = array!['name', 'symbol', 100, 0, 10];

        let (erc20_address, _) = deploy_syscall(
            ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        return (IERC20Dispatcher { contract_address: erc20_address }, erc20_address);
    }

    fn deploy_external_owned_account(
        kakarot_address: ContractAddress, evm_address: EthAddress
    ) -> IExternallyOwnedAccountDispatcher {
        let mut calldata = ArrayTrait::<felt252>::new();
        calldata.append(kakarot_address.into());
        calldata.append(evm_address.into());

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
        let evm_address: EthAddress = 3.try_into().unwrap();
        let (_, kakarot_address) = deploy_erc20();

        let external_owner_account_contract = deploy_external_owned_account(
            kakarot_address, evm_address
        );

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
        let evm_address: EthAddress = 3.try_into().unwrap();
        let (_, kakarot_address) = deploy_erc20();

        let external_owner_account_contract = deploy_external_owned_account(
            kakarot_address, evm_address
        );
        let value: u32 = 0;

        assert(external_owner_account_contract.bytecode_len() == value, 'wrong bytecode');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_get_evm_address() {
        let owner = contract_address_const::<1>();
        set_contract_address(owner);
        let evm_address: EthAddress = 3.try_into().unwrap();
        let (_, kakarot_address) = deploy_erc20();

        let external_owner_account_contract = deploy_external_owned_account(
            kakarot_address, evm_address
        );

        assert(
            external_owner_account_contract.get_evm_address() == evm_address, 'wrong evm address'
        );
    }
}
