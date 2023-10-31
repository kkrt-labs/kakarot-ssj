use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::test_utils as contract_utils;
use contracts::tests::test_utils::{
    deploy_kakarot_core, deploy_native_token, fund_account_with_native_token
};
use evm::errors::EVMErrorTrait;
use evm::model::eoa::{EOA, EOATrait};
use evm::tests::test_utils;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::{
    testing, testing::set_contract_address, ContractAddress, contract_address_const,
    storage_base_address_from_felt252, Store, get_contract_address
};


#[test]
#[available_gas(200000000)]
fn test_eoa_deploy() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    contract_utils::drop_event(kakarot_core.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    let maybe_eoa = EOATrait::deploy(test_utils::evm_address());
    let eoa = match maybe_eoa {
        Result::Ok(eoa) => eoa,
        Result::Err(err) => panic_with_felt252(err.to_string())
    };

    let event = contract_utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address)
        .unwrap();

    assert(event.evm_address == test_utils::evm_address(), 'wrong evm address');
    assert(event.starknet_address.into() == eoa.starknet_address, 'wrong starknet address');
}


#[test]
#[available_gas(5000000)]
fn test_eoa_balance() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    let sn_address = kakarot_core.deploy_eoa(test_utils::evm_address());

    fund_account_with_native_token(sn_address, native_token);

    // When
    set_contract_address(kakarot_core.contract_address);
    let eoa = EOATrait::at(test_utils::evm_address()).unwrap().unwrap();
    let balance = eoa.balance().unwrap();

    // Then
    assert(balance == native_token.balanceOf(eoa.starknet_address), 'wrong balance');
}
