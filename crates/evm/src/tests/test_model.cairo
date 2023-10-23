use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::utils::{
    deploy_kakarot_core, deploy_native_token, fund_account_with_native_token
};
use evm::model::{Account, AccountTrait};
use evm::tests::test_utils::{evm_address};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::{set_contract_address};

#[test]
#[available_gas(20000000)]
fn test_account_at_eoa() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    let eoa = kakarot_core.deploy_eoa(evm_address());

    // When
    set_contract_address(kakarot_core.contract_address);
    let account = AccountTrait::account_at(evm_address()).unwrap().unwrap();

    // Then
    assert(account.is_eoa(), 'wrong account type');
}

#[test]
#[available_gas(20000000)]
#[ignore]
fn test_account_at_ca() {
    //TODO: implement this once ContractAccounts are deployable
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    // kakarot_core.deploy_contrat_account(...);

    // When
    set_contract_address(kakarot_core.contract_address);
    let account = AccountTrait::account_at(evm_address()).unwrap().unwrap();

    // Then
    assert(account.is_ca(), 'wrong account type');
}


#[test]
#[available_gas(20000000)]
fn test_account_at_undeployed() {
    //TODO: implement this once ContractAccounts are deployable
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);

    // When
    set_contract_address(kakarot_core.contract_address);
    let maybe_account = AccountTrait::account_at(evm_address()).unwrap();

    // Then
    assert(maybe_account.is_none(), 'account should be None');
}


#[test]
#[available_gas(5000000)]
fn test_balance_eoa() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    let eoa = kakarot_core.deploy_eoa(evm_address());

    fund_account_with_native_token(eoa, native_token);

    // When
    set_contract_address(kakarot_core.contract_address);
    let account = AccountTrait::account_at(evm_address()).unwrap().unwrap();
    let balance = account.balance().unwrap();

    // Then
    assert(balance == native_token.balanceOf(eoa), 'wrong balance');
}

// TODO: implement balance once contracts accounts can be deployed
#[ignore]
#[test]
#[available_gas(5000000)]
fn test_balance_contract_account() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    // TODO: deploy contract account
    // and fund it

    // When
    set_contract_address(kakarot_core.contract_address);
    let account = AccountTrait::account_at(evm_address()).unwrap().unwrap();
    let balance = account.balance().unwrap();

    // Then
    panic_with_felt252('Not implemented yet');
}
