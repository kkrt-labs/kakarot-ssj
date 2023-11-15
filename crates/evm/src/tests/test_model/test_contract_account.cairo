use contracts::contract_account::{
    IContractAccountDispatcher, IContractAccountDispatcherTrait, IContractAccount,
    IContractAccountSafeDispatcher, IContractAccountSafeDispatcherTrait
};
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::tests::test_data::counter_evm_bytecode;
use contracts::tests::test_utils as contract_utils;
use contracts::tests::test_utils::constants::EVM_ADDRESS;
use evm::model::account::{Account, ContractAccountBuilderTrait};
use evm::model::contract_account::{ContractAccountTrait};
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
    let ca_address = test_utils::initialize_contract_account(
        test_utils::evm_address(), bytecode, array![].span()
    )
        .unwrap();
    let account = ContractAccountBuilderTrait::new(ca_address)
        .fetch_nonce()
        .fetch_bytecode()
        .build();
    let event = contract_utils::pop_log::<
        KakarotCore::ContractAccountDeployed
    >(kakarot_core.contract_address)
        .unwrap();
    assert(ca_address.evm == event.evm_address, 'wrong evm address');
    assert(event.evm_address == test_utils::evm_address(), 'wrong event address');
    assert(account.nonce == 1, 'initial nonce not 1');
    assert(account.code == bytecode, 'wrong bytecode');
}

#[test]
#[available_gas(2000000000)]
fn test_at_contract_account_deployed() {
    let evm_address = test_utils::evm_address();
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let ca = ContractAccountTrait::deploy(evm_address, Default::default().span(), array![].span())
        .unwrap();

    let ca_address = ContractAccountTrait::at(evm_address)
        .unwrap()
        .expect('contract account should exist');
    assert(ca_address.evm == evm_address, 'evm_address incorrect');
    let (registered_type, registered_address) = kakarot_core
        .address_registry(evm_address)
        .expect('should be in registry');

    assert(registered_type == AccountType::ContractAccount, 'is not CA');
    assert(ca_address.starknet == registered_address, 'starknet_address mismatch');
}


#[test]
#[available_gas(2000000)]
fn test_at_contract_account_undeployed() {
    let evm_address = EVM_ADDRESS();
    let maybe_ca = ContractAccountTrait::at(evm_address).unwrap();
    assert(maybe_ca.is_none(), 'contract account shouldnt exist');
}
//TODO add a test with huge amount of bytecode - using SNFoundry and loading data from txt

#[test]
#[available_gas(2000000)]
fn test_find_false_positive_jumpdests() {
    let bytecode: Span<u8> = array![0x60, 0x5b, 0x5b, 0x61, 0x5b, 0x5b, 0x5b, 0x5b].span();
    let expected_offsets = array![1, 4, 5].span();
    let offsets = ContractAccountTrait::find_false_positive_jumpdests(bytecode);
    assert(offsets == expected_offsets, 'wrong offsets');
}

#[test]
#[available_gas(2_000_000_000)]
fn test_deploy_with_false_positive_jumpdests() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    set_contract_address(kakarot_core.contract_address);

    let bytecode: Span<u8> = array![0x60, 0x5b, 0x5b, 0x61, 0x5b, 0x5b, 0x5b, 0x5b].span();
    let false_positive_jumpdests = ContractAccountTrait::find_false_positive_jumpdests(bytecode);
    let ca_address = ContractAccountTrait::deploy(
        test_utils::evm_address(), bytecode, false_positive_jumpdests
    )
        .expect('CA deployment failed');
    let account = IContractAccountDispatcher { contract_address: ca_address.starknet };
    assert(account.is_false_positive_jumpdest(1), 'should be false positive');
    assert(account.is_false_positive_jumpdest(4), 'should be false positive');
    assert(account.is_false_positive_jumpdest(5), 'should be false positive');
}
