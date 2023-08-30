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
    use integer::BoundedInt;


    // Use starknet test utils to fake the transaction context.
    use starknet::testing::{set_caller_address, set_contract_address};

    fn deploy_erc20() -> IERC20Dispatcher {
        let mut calldata: Array<felt252> = array![
            'erc20_token_address', 'symbol', 100000, 0, 10000
        ];

        let (erc20_address, _) = deploy_syscall(
            ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        return IERC20Dispatcher { contract_address: erc20_address };
    }

    fn deploy_eoa(
        //TODO: Remove native token and fetch from Kakarot Contract, when Kakarot Contract is ready
        erc20_token_address: ContractAddress,
        kakarot_address: ContractAddress,
        evm_address: EthAddress
    ) -> IExternallyOwnedAccountDispatcher {
        let mut calldata = ArrayTrait::<felt252>::new();
        calldata.append(erc20_token_address.into());
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
        let kakarot_address = contract_address_const::<2>();
        let evm_address: EthAddress = 3.try_into().unwrap();
        let erc20_contract = deploy_erc20();
        let erc20_token_address = erc20_contract.contract_address;
        let eoa_contract = deploy_eoa(erc20_token_address, kakarot_address, evm_address);

        assert(eoa_contract.bytecode() == ArrayTrait::<u8>::new().span(), 'wrong bytecode');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_bytecode_len() {
        let owner = contract_address_const::<1>();
        set_contract_address(owner);
        let kakarot_address = contract_address_const::<2>();
        let evm_address: EthAddress = 3.try_into().unwrap();
        let erc20_contract = deploy_erc20();
        let erc20_token_address = erc20_contract.contract_address;

        let eoa_contract = deploy_eoa(erc20_token_address, kakarot_address, evm_address);

        assert(eoa_contract.bytecode_len() == 0, 'wrong bytecode');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_get_evm_address() {
        let owner = contract_address_const::<1>();
        set_contract_address(owner);
        let kakarot_address = contract_address_const::<2>();
        let evm_address: EthAddress = 3.try_into().unwrap();
        let erc20_contract = deploy_erc20();
        let erc20_token_address = erc20_contract.contract_address;

        let eoa_contract = deploy_eoa(erc20_token_address, kakarot_address, evm_address);

        assert(eoa_contract.get_evm_address() == evm_address, 'wrong evm address');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_eoa_approve_on_constructor() {
        let owner = contract_address_const::<1>();
        set_contract_address(owner);
        let kakarot_address = contract_address_const::<2>();
        let evm_address: EthAddress = 3.try_into().unwrap();
        let erc20_contract = deploy_erc20();
        let erc20_token_address = erc20_contract.contract_address;
        let eoa_contract = deploy_eoa(erc20_token_address, kakarot_address, evm_address);
        let infinite = BoundedInt::<u256>::max();

        let eoa_contract_address = eoa_contract.contract_address;
        assert(
            erc20_contract.allowance(eoa_contract_address, kakarot_address) == infinite,
            'wrong allowance'
        );
    }
}
