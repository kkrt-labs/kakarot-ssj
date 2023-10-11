use evm::kakarot_core::IExtendedKakarotCoreDispatcherImpl;
use evm::tests::test_utils;
use starknet::{get_caller_address, testing, contract_address_const};

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_owner() {
    let kakarot_core = test_utils::deploy_kakarot_core();

    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_transfer_ownership() {
    let kakarot_core = test_utils::deploy_kakarot_core();
    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.transfer_ownership(test_utils::starknet_address());
    assert(kakarot_core.owner() == test_utils::starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_renounce_ownership() {
    let kakarot_core = test_utils::deploy_kakarot_core();
    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_deploy_fee() {
    let kakarot_core = test_utils::deploy_kakarot_core();
    assert(kakarot_core.deploy_fee() == test_utils::deploy_fee(), 'wrong deploy_fee');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_deploy_fee() {
    let kakarot_core = test_utils::deploy_kakarot_core();
    assert(kakarot_core.deploy_fee() == test_utils::deploy_fee(), 'wrong deploy_fee');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_deploy_fee(0x100);
    assert(kakarot_core.deploy_fee() == 0x100, 'wrong new deploy_fee');
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_native_token() {
    let kakarot_core = test_utils::deploy_kakarot_core();
    assert(kakarot_core.native_token() == test_utils::native_token(), 'wrong native_token');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_native_token() {
    let kakarot_core = test_utils::deploy_kakarot_core();
    assert(kakarot_core.native_token() == test_utils::native_token(), 'wrong native_token');

    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_native_token(contract_address_const::<0xdead>());
    assert(
        kakarot_core.native_token() == contract_address_const::<0xdead>(), 'wrong new native_token'
    );
}
