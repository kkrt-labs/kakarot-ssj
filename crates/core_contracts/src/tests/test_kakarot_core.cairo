use core_contracts::kakarot_core::{IExtendedKakarotCoreDispatcherImpl, KakarotCore};
use core_contracts::tests::utils;
use evm::tests::test_utils;
use starknet::{get_caller_address, testing, contract_address_const, ContractAddress, ClassHash};
use debug::PrintTrait;
use eoa::externally_owned_account::ExternallyOwnedAccount;

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_owner() {
    let kakarot_core = utils::deploy_kakarot_core();

    assert(kakarot_core.owner() == utils::other_starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_transfer_ownership() {
    let kakarot_core = utils::deploy_kakarot_core();
    assert(kakarot_core.owner() == utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.transfer_ownership(test_utils::starknet_address());
    assert(kakarot_core.owner() == test_utils::starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_renounce_ownership() {
    let kakarot_core = utils::deploy_kakarot_core();
    assert(kakarot_core.owner() == utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_deploy_fee() {
    let kakarot_core = utils::deploy_kakarot_core();
    assert(kakarot_core.deploy_fee() == utils::deploy_fee(), 'wrong deploy_fee');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_deploy_fee() {
    let kakarot_core = utils::deploy_kakarot_core();
    assert(kakarot_core.deploy_fee() == utils::deploy_fee(), 'wrong deploy_fee');
    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.set_deploy_fee(0x100);
    assert(kakarot_core.deploy_fee() == 0x100, 'wrong new deploy_fee');
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_native_token() {
    let kakarot_core = utils::deploy_kakarot_core();
    assert(kakarot_core.native_token() == test_utils::native_token(), 'wrong native_token');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_native_token() {
    let kakarot_core = utils::deploy_kakarot_core();
    assert(kakarot_core.native_token() == test_utils::native_token(), 'wrong native_token');

    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_native_token(contract_address_const::<0xdead>());
    assert(
        kakarot_core.native_token() == contract_address_const::<0xdead>(), 'wrong new native_token'
    );
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_deploy_eoa() {
    let kakarot_core = utils::deploy_kakarot_core();
    let eoa_starknet_address = kakarot_core.deploy_eoa(test_utils::evm_address());
    let event = utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address).unwrap();
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_compute_starknet_address() {
    let evm_address = test_utils::evm_address();
    let kakarot_core = utils::deploy_kakarot_core();
    let expected_starknet_address = kakarot_core.compute_starknet_address(evm_address);
    let eoa_starknet_address = kakarot_core.deploy_eoa(evm_address);

    '***'.print();
    'EOA CLASS HASH'.print();
    (ExternallyOwnedAccount::TEST_CLASS_HASH).print();
    '***'.print();

    '***'.print();
    'EOA STARKNET ADDRESS'.print();
    eoa_starknet_address.print();
    '***'.print();

    '***'.print();
    'EXPECTED STARKNET ADDRESS'.print();
    expected_starknet_address.print();
    '***'.print();
    assert(expected_starknet_address == eoa_starknet_address, 'wrong starknet address');
}

