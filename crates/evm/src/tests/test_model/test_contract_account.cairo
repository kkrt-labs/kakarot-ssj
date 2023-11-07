use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::tests::test_data::counter_evm_bytecode;
use contracts::tests::test_utils as contract_utils;
use contracts::tests::test_utils::constants::EVM_ADDRESS;
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::model::{AccountType};
use evm::tests::test_utils;
use starknet::testing::set_contract_address;


#[test]
#[available_gas(200000000)]
fn test_contract_account_deploy() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    set_contract_address(kakarot_core.contract_address);

    let bytecode = counter_evm_bytecode();
    let ca = ContractAccountTrait::deploy(test_utils::evm_address(), bytecode).unwrap();
    let event = contract_utils::pop_log::<
        KakarotCore::ContractAccountDeployed
    >(kakarot_core.contract_address)
        .unwrap();
    assert(ca.evm_address == event.evm_address, 'wrong evm address');
    assert(event.evm_address == test_utils::evm_address(), 'wrong event address');
    assert(ca.nonce().unwrap() == 1, 'initial nonce not 1');
    assert(ca.load_bytecode().unwrap() == bytecode, 'wrong bytecode');
}

#[test]
#[available_gas(2000000000)]
fn test_at_contract_account_deployed() {
    let evm_address = test_utils::evm_address();
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let ca = ContractAccountTrait::deploy(evm_address, Default::default().span()).unwrap();

    let maybe_ca = ContractAccountTrait::at(evm_address).unwrap();
    assert(maybe_ca.is_some(), 'contract account should exist');
    let mut ca = maybe_ca.unwrap();
    assert(ca.evm_address == evm_address, 'evm_address incorrect');
    let registered_ca = match kakarot_core.address_registry(evm_address).expect('should be in registry') {
        AccountType::EOA(_) => panic_with_felt252('should no be EOA'),
        AccountType::ContractAccount(address) => address,
    };
    assert(ca == registered_ca, 'starknet_address mismatch');
}


#[test]
#[available_gas(2000000)]
fn test_at_contract_account_undeployed() {
    let evm_address = EVM_ADDRESS();
    let maybe_ca = ContractAccountTrait::at(evm_address).unwrap();
    assert(maybe_ca.is_none(), 'contract account shouldnt exist');
}

#[test]
#[available_gas(200000000000)]
fn test_balance() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = EVM_ADDRESS();
    let mut ca = ContractAccountTrait::deploy(test_utils::evm_address(), array![].span()).unwrap();
    assert(ca.balance().expect('failed to get balance') == 0, 'initial balance not 0');

    contract_utils::fund_account_with_native_token(ca.starknet_address, native_token, 0x1);

    assert(ca.balance().expect('failed to get new balance') == 1, 'balance not incremented');
}
//TODO add a test with huge amount of bytecode - using SNFoundry and loading data from txt


