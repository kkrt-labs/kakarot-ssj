use contracts::components::ownable::ownable_component;
use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore};
use contracts::tests::test_upgradeable::{
    MockContractUpdatableV1, IMockContractUpdatableDispatcher, IMockContractUpdatableDispatcherTrait
};
use contracts::tests::utils;
use debug::PrintTrait;
use eoa::externally_owned_account::ExternallyOwnedAccount;
use evm::tests::test_utils;
use starknet::{get_caller_address, testing, contract_address_const, ContractAddress, ClassHash};

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_owner() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());

    assert(kakarot_core.owner() == utils::other_starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_transfer_ownership() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.owner() == utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.transfer_ownership(test_utils::starknet_address());
    assert(kakarot_core.owner() == test_utils::starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_renounce_ownership() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.owner() == utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_deploy_fee() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.deploy_fee() == utils::deploy_fee(), 'wrong deploy_fee');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_deploy_fee() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.deploy_fee() == utils::deploy_fee(), 'wrong deploy_fee');
    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.set_deploy_fee(0x100);
    assert(kakarot_core.deploy_fee() == 0x100, 'wrong new deploy_fee');
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_native_token() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
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
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
    let eoa_starknet_address = kakarot_core.deploy_eoa(test_utils::evm_address());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    utils::drop_event(kakarot_core.contract_address);

    let event = utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address).unwrap();
    assert(event.starknet_address == eoa_starknet_address, 'wrong starknet address');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_compute_starknet_address() {
    let evm_address = test_utils::evm_address();
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());

    // Precomputed Starknet address with starknet-rs and starknetjs
    // With arguments:
    // ['STARKNET_CONTRACT_ADDRESS', kakarot_address: 0x01, salt: evm_address, class_hash: ExternallyOwnedAccount::TEST_CLASS_HASH, constructor_calldata: hash([kakarot_address, evm_address]), ]
    let expected_starknet_address: ContractAddress = contract_address_const::<
        0x4ce3d4b8b65c387f5e7c1abcecf364ebc7cbfdbc3e7de18e813bead64cc0ce5
    >();

    let eoa_starknet_address = kakarot_core.compute_starknet_address(evm_address);

    assert(eoa_starknet_address == expected_starknet_address, 'wrong starknet address');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_upgrade_contract() {
    let kakarot_core = utils::deploy_kakarot_core(test_utils::native_token());
    let class_hash: ClassHash = MockContractUpdatableV1::TEST_CLASS_HASH.try_into().unwrap();

    testing::set_contract_address(utils::other_starknet_address());
    kakarot_core.upgrade(class_hash);

    let version = IMockContractUpdatableDispatcher {
        contract_address: kakarot_core.contract_address
    }
        .version();
    assert(version == 1, 'version is not 1');
}
