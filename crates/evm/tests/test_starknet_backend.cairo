use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::KakarotCore;
use contracts_tests::test_utils as contract_utils;
use contracts_tests::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
use evm::backend::starknet_backend;
use evm::errors::EVMErrorTrait;
use evm_tests::test_utils::{chain_id, evm_address, VMBuilderTrait};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::{set_contract_address, set_chain_id};


#[test]
fn test_account_deploy() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let eoa_address = starknet_backend::deploy(evm_address()).expect('deployment of EOA failed');

    let event = contract_utils::pop_log::<
        KakarotCore::AccountDeployed
    >(kakarot_core.contract_address)
        .unwrap();

    assert(event.evm_address == evm_address(), 'wrong evm address');
    assert(event.starknet_address.into() == eoa_address.starknet, 'wrong starknet address');

    set_chain_id(chain_id().into());
    let mut vm = VMBuilderTrait::new_with_presets().build();
    let chain_id = vm.env.chain_id;

    let eoa = IAccountDispatcher { contract_address: eoa_address.starknet };
    let evm_address = eoa.get_evm_address();
    assert!(eoa.is_initialized());
}
