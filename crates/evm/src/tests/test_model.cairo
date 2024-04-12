use evm::model::contract_account::ContractAccountTrait;
mod test_contract_account;
mod test_eoa;
mod test_vm;
use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::test_utils::{
    setup_contracts_for_testing, fund_account_with_native_token, deploy_contract_account
};
use evm::model::account::AccountTrait;
use evm::state::{State, StateChangeLog, StateChangeLogTrait};
use evm::model::{Address, Account, AccountType, eoa::{EOATrait}, AddressTrait};
use evm::tests::test_utils::{evm_address};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::set_contract_address;
use core::starknet::EthAddress;

#[test]
fn test_is_deployed_eoa_exists() {
    // Given
    let (_, kakarot_core) = setup_contracts_for_testing();
    EOATrait::deploy(evm_address()).expect('failed deploy eoa account',);

    // When

    // When
    set_contract_address(kakarot_core.contract_address);
    let is_deployed = evm_address().is_deployed();

    // Then
    assert(is_deployed, 'account should be deployed');
}

#[test]
fn test_is_deployed_ca_exists() {
    // Given
    setup_contracts_for_testing();
    deploy_contract_account(evm_address(), array![].span());

    // When
    let is_deployed = evm_address().is_deployed();
    // Then
    assert(is_deployed, 'account should be deployed');
}

#[test]
fn test_is_deployed_undeployed() {
    // Given
    let (_, kakarot_core) = setup_contracts_for_testing();

    // When
    set_contract_address(kakarot_core.contract_address);
    let is_deployed = evm_address().is_deployed();

    // Then
    assert(!is_deployed, 'account shouldnt be deployed');
}


#[test]
fn test_account_balance_eoa() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let eoa_address = EOATrait::deploy(evm_address()).expect('failed deploy eoa account',);

    fund_account_with_native_token(eoa_address.starknet, native_token, 0x1);

    // When
    set_contract_address(kakarot_core.contract_address);
    let account = AccountTrait::fetch(evm_address()).unwrap();
    let balance = account.balance();

    // Then
    assert(balance == native_token.balanceOf(eoa_address.starknet), 'wrong balance');
}

#[test]
fn test_address_balance_eoa() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let eoa_address = EOATrait::deploy(evm_address()).expect('failed deploy eoa account',);

    fund_account_with_native_token(eoa_address.starknet, native_token, 0x1);

    // When
    set_contract_address(kakarot_core.contract_address);
    let account = AccountTrait::fetch(evm_address()).unwrap();
    let balance = account.balance();

    // Then
    assert(balance == native_token.balanceOf(eoa_address.starknet), 'wrong balance');
}


#[test]
fn test_account_has_code_or_nonce_empty() {
    // Given
    setup_contracts_for_testing();
    let mut _eoa_address = EOATrait::deploy(evm_address()).expect('failed deploy eoa',);

    // When
    let account = AccountTrait::fetch(evm_address()).unwrap();

    // Then
    assert_eq!(account.has_code_or_nonce(), false);
}


#[test]
fn test_account_has_code_or_nonce_contract_account() {
    // Given
    setup_contracts_for_testing();
    let mut _ca_address = deploy_contract_account(evm_address(), array![].span());

    // When
    let account = AccountTrait::fetch(evm_address()).unwrap();

    // Then
    assert(account.has_code_or_nonce() == true, 'account shouldhave codeornonce');
}


#[test]
fn test_account_has_code_or_nonce_undeployed() {
    // Given
    setup_contracts_for_testing();

    // When
    let account = AccountTrait::fetch_or_create(evm_address());

    // Then
    assert(account.has_code_or_nonce() == false, 'account has codeornonce');
}

#[test]
fn test_account_has_code_or_nonce_account_to_deploy() {
    // Given
    setup_contracts_for_testing();

    // When
    let mut account = AccountTrait::fetch_or_create(evm_address());
    // Mock account as an existing contract account in the cached state.
    account.nonce = 1;
    account.code = array![0x1].span();

    // Then
    assert(account.has_code_or_nonce() == true, 'account should exist');
}


#[test]
fn test_account_balance_contract_account() {
    // Given
    let (native_token, _) = setup_contracts_for_testing();
    let mut ca_address = deploy_contract_account(evm_address(), array![].span());

    fund_account_with_native_token(ca_address.starknet, native_token, 0x1);

    // When
    let account = AccountTrait::fetch(evm_address()).unwrap();
    let balance = account.balance();

    // Then
    assert(balance == native_token.balanceOf(ca_address.starknet), 'wrong balance');
}

#[test]
fn test_account_commit_already_deployed() {
    setup_contracts_for_testing();
    let mut ca_address = deploy_contract_account(evm_address(), array![].span());

    let mut state: State = Default::default();

    // When
    let mut account = AccountTrait::fetch(evm_address()).unwrap();
    account.nonce = 420;
    account.code = array![0x1].span();
    account.commit(ref state);

    // Then
    let account_dispatcher = IAccountDispatcher { contract_address: ca_address.starknet };
    let nonce = account_dispatcher.get_nonce();
    let code = account_dispatcher.bytecode();
    assert(nonce == 420, 'wrong nonce');
    assert(code == array![0x1].span(), 'notdeploying =  unmodified code');
}

//TODO unskip after selfdestruct rework
// #[test]
// fn test_account_commit_redeploy_selfdestructed_new_nonce() {
//     setup_contracts_for_testing();
//     let mut ca_address = deploy_contract_account(evm_address(), array![].span());

//     // When
//     // Selfdestructing the deployed CA to reset its code and nonce.
//     // Setting the nonce and the code of a CA
//     IAccountDispatcher { contract_address: ca_address.starknet }.selfdestruct();
//     let mut account = AccountTrait::fetch(evm_address()).unwrap();
//     account.nonce = 420;
//     account.code = array![0x1].span();
//     account.commit();

//     // Then
//     let account_dispatcher = IAccountDispatcher { contract_address: ca_address.starknet };
//     let nonce = account_dispatcher.nonce();
//     let code = account_dispatcher.bytecode();
//     assert(nonce == 420, 'nonce should be modified');
//     assert(code == array![0x1].span(), 'code should be modified');
// }

#[test]
fn test_account_commit_undeployed() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm = evm_address();
    let starknet = kakarot_core.compute_starknet_address(evm);
    let mut state: State = Default::default();
    // When
    let mut account = Account {
        address: Address { evm, starknet },
        nonce: 420,
        code: array![0x69].span(),
        balance: 0,
        selfdestruct: false,
    };
    account.nonce = 420;
    account.code = array![0x1].span();
    account.commit(ref state);

    // Then
    let account_dispatcher = IAccountDispatcher { contract_address: starknet };
    let nonce = account_dispatcher.get_nonce();
    let code = account_dispatcher.bytecode();
    assert(nonce == 420, 'nonce should be modified');
    assert(code == array![0x1].span(), 'code should be modified');
}

#[test]
fn test_address_balance_contract_account() {
    // Given
    let (native_token, _) = setup_contracts_for_testing();
    let mut ca_address = deploy_contract_account(evm_address(), array![].span());

    fund_account_with_native_token(ca_address.starknet, native_token, 0x1);

    // When
    let account = AccountTrait::fetch(evm_address()).unwrap();
    let balance = account.balance();

    // Then
    // Then
    assert(balance == native_token.balanceOf(ca_address.starknet), 'wrong balance');
}
