use contracts::account_contract::{AccountContract, IAccountDispatcher, IAccountDispatcherTrait};
use contracts::test_data::counter_evm_bytecode;
use contracts_tests::test_utils::evm_utils::{ca_address, native_token};
use contracts_tests::test_utils::contracts_utils::{setup_contracts_for_testing, deploy_contract_account};

#[test]
fn test_ca_deploy() {
    setup_contracts_for_testing();
    let ca_address = deploy_contract_account(ca_address(), Default::default().span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let initial_bytecode = contract_account.bytecode();
    assert(initial_bytecode.is_empty(), 'bytecode should be empty');
    assert(contract_account.get_evm_address() == ca_address(), 'wrong ca evm address');
    assert(contract_account.get_nonce() == 1, 'wrong nonce');
}

#[test]
fn test_ca_bytecode() {
    setup_contracts_for_testing();
    let bytecode = counter_evm_bytecode();
    let ca_address = deploy_contract_account(ca_address(), bytecode);
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let contract_bytecode = contract_account.bytecode();
    assert(contract_bytecode == bytecode, 'wrong contract bytecode');
}


#[test]
fn test_ca_get_nonce() {
    setup_contracts_for_testing();
    let ca_address = deploy_contract_account(ca_address(), Default::default().span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let initial_nonce = contract_account.get_nonce();
    assert(initial_nonce == 1, 'nonce should be 1');

    let expected_nonce = 100;
    contract_account.set_nonce(expected_nonce);

    let nonce = contract_account.get_nonce();

    assert(nonce == expected_nonce, 'wrong contract nonce');
}


#[test]
fn test_ca_storage() {
    setup_contracts_for_testing();
    let ca_address = deploy_contract_account(ca_address(), Default::default().span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let storage_slot = 0x555;

    let initial_storage = contract_account.storage(storage_slot);
    assert(initial_storage == 0, 'value should be 0');

    let expected_storage = 0x444;
    contract_account.write_storage(storage_slot, expected_storage);

    let storage = contract_account.storage(storage_slot);

    assert(storage == expected_storage, 'wrong contract storage');
}
