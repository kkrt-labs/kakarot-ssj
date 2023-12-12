use contracts::eoa::{IExternallyOwnedAccountDispatcher, IExternallyOwnedAccountDispatcherTrait};
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::test_utils as contract_utils;
use contracts::tests::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
use evm::errors::EVMErrorTrait;
use evm::model::eoa::{EOATrait};
use evm::tests::test_utils::{chain_id, evm_address, VMBuilderTrait};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::{set_contract_address, set_chain_id};


#[test]
fn test_eoa_deploy() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    contract_utils::drop_event(kakarot_core.contract_address);

    let eoa_address = EOATrait::deploy(evm_address()).expect('deployment of EOA failed');

    let event = contract_utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address)
        .unwrap();

    assert(event.evm_address == evm_address(), 'wrong evm address');
    assert(event.starknet_address.into() == eoa_address.starknet, 'wrong starknet address');

    set_chain_id(chain_id().into());
    let mut vm = VMBuilderTrait::new_with_presets().build();
    let chain_id = vm.env.chain_id;

    let eoa = IExternallyOwnedAccountDispatcher { contract_address: eoa_address.starknet };
    assert(eoa.chain_id() == chain_id, 'wrong chain id');
}
