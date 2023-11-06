use contracts::components::ownable::ownable_component;
use contracts::contract_account::ContractAccount;
use contracts::eoa::ExternallyOwnedAccount;
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::kakarot_core::interface::IKakarotCore;
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore, KakarotCore::{KakarotCoreInternal},
};
use contracts::tests::test_data::counter_evm_bytecode;
use contracts::tests::test_upgradeable::{
    MockContractUpgradeableV1, IMockContractUpgradeableDispatcher,
    IMockContractUpgradeableDispatcherTrait
};
use contracts::tests::test_utils as contract_utils;
use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait, UninitializedAccount
};
use core::result::ResultTrait;
use evm::errors::EVMErrorTrait;
use evm::machine::Status;
use evm::model::Address;
use evm::model::contract_account::ContractAccountTrait;
use evm::model::eoa::EOATrait;
use evm::tests::test_utils;
use starknet::{get_caller_address, testing, contract_address_const, ContractAddress, ClassHash};
use utils::helpers::{U32Trait, ByteArrayExTrait, u256_to_bytes_array};

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_owner() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());

    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_transfer_ownership() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.transfer_ownership(test_utils::starknet_address());
    assert(kakarot_core.owner() == test_utils::starknet_address(), 'wrong owner')
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_renounce_ownership() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_deploy_fee() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.deploy_fee() == contract_utils::deploy_fee(), 'wrong deploy_fee');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_chain_id() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.chain_id() == contract_utils::chain_id(), 'wrong chain id');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_deploy_fee() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.deploy_fee() == contract_utils::deploy_fee(), 'wrong deploy_fee');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_deploy_fee(0x100);
    assert(kakarot_core.deploy_fee() == 0x100, 'wrong new deploy_fee');
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_set_native_token() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
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
    let native_token = contract_utils::deploy_native_token();
    let kakarot_core = contract_utils::deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);
    let eoa_starknet_address = kakarot_core.deploy_eoa(test_utils::evm_address());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let event = contract_utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address)
        .unwrap();
    assert(event.starknet_address == eoa_starknet_address, 'wrong starknet address');
}


#[test]
#[available_gas(20000000)]
fn test_kakarot_core_eoa_mapping() {
    // Given
    let native_token = contract_utils::deploy_native_token();
    let kakarot_core = contract_utils::deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);
    assert(
        kakarot_core
            .address_registry(test_utils::evm_address()) == StoredAccountType::UninitializedAccount,
        'should be uninitialized'
    );

    let expected_eoa_starknet_address = kakarot_core.deploy_eoa(test_utils::evm_address());

    // When
    let eoa_starknet_address = kakarot_core.address_registry(test_utils::evm_address());

    // Then
    assert(
        eoa_starknet_address == StoredAccountType::EOA(expected_eoa_starknet_address),
        'wrong starknet address'
    );

    let another_sn_address: ContractAddress = 0xbeef.try_into().unwrap();

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    kakarot_state
        .set_address_registry(
            test_utils::evm_address(), StoredAccountType::EOA(another_sn_address)
        );

    assert(
        kakarot_core
            .address_registry(
                test_utils::evm_address()
            ) == StoredAccountType::EOA(another_sn_address),
        'wrong registry address'
    );
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_compute_starknet_address() {
    let evm_address = test_utils::evm_address();
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());

    // Precomputed Starknet address with the script compute_starknet_address.ts
    // With arguments:
    // ['STARKNET_CONTRACT_ADDRESS', kakarot_address: 0x01, salt: evm_address, class_hash: UninitializedAccount::TEST_CLASS_HASH, constructor_calldata: hash([kakarot_address, evm_address]), ]

    let class_hash = UninitializedAccount::TEST_CLASS_HASH; // used to get the hash using the LSP
    let expected_starknet_address: ContractAddress = contract_address_const::<
        0x50f2821ed90360ac0508d52f8db1f87e541811773bce3dbcaf863c572cd696f
    >();

    let eoa_starknet_address = kakarot_core.compute_starknet_address(evm_address);
    assert(eoa_starknet_address == expected_starknet_address, 'wrong starknet address');
}

#[test]
#[available_gas(20000000)]
fn test_kakarot_core_upgrade_contract() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    let class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();

    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.upgrade(class_hash);

    let version = IMockContractUpgradeableDispatcher {
        contract_address: kakarot_core.contract_address
    }
        .version();
    assert(version == 1, 'version is not 1');
}

// TODO add tests related to contract accounts once they can be deployed.
#[ignore]
#[test]
#[available_gas(20000000)]
fn test_kakarot_contract_account() {}

#[test]
#[available_gas(2000000000000)]
fn test_eth_call() {
    // Given
    let native_token = contract_utils::deploy_native_token();
    let kakarot_core = contract_utils::deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

    let account = ContractAccountTrait::deploy(
        test_utils::other_evm_address(), counter_evm_bytecode()
    )
        .unwrap();

    let to = Option::Some(test_utils::other_evm_address());
    let gas_limit = test_utils::gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;
    // selector: function get()
    let data = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // When

    let return_data = kakarot_core
        .eth_call(from: evm_address, :to, :gas_limit, :gas_price, :value, :data);

    // Then
    assert(return_data == u256_to_bytes_array(0).span(), 'wrong result');
}


#[test]
#[available_gas(2000000000)]
fn test_handle_call() {
    // Given
    let native_token = contract_utils::deploy_native_token();
    let kakarot_core = contract_utils::deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);
    let account = ContractAccountTrait::deploy(
        test_utils::other_evm_address(), counter_evm_bytecode()
    )
        .unwrap();

    let to = Option::Some(test_utils::other_evm_address());
    let gas_limit = test_utils::gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;
    // selector: function get()
    let data = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // When

    let mut kakarot_core = KakarotCore::unsafe_new_contract_state();
    let result = kakarot_core
        .handle_call(
            from: Address { evm: evm_address, starknet: eoa },
            :to,
            :gas_limit,
            :gas_price,
            :value,
            :data
        )
        .expect('handle_call failed');
    let return_data = result.return_data;

    assert(result.status == Status::Stopped, 'wrong status');

    // Then
    assert(return_data == u256_to_bytes_array(0).span(), 'wrong result');
}

#[test]
#[available_gas(20000000)]
fn test_contract_account_class_hash() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let class_hash = kakarot_core.ca_class_hash();

    assert(class_hash == ContractAccount::TEST_CLASS_HASH.try_into().unwrap(), 'wrong class hash');

    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_ca_class_hash(new_class_hash);

    assert(kakarot_core.ca_class_hash() == new_class_hash, 'wrong class hash');
    let event = contract_utils::pop_log::<
        KakarotCore::CAClassHashChange
    >(kakarot_core.contract_address)
        .unwrap();
    assert(event.old_class_hash == class_hash, 'wrong old hash');
    assert(event.new_class_hash == kakarot_core.ca_class_hash(), 'wrong new hash');
}

#[test]
#[available_gas(20000000)]
fn test_account_class_hash() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let class_hash = kakarot_core.account_class_hash();

    assert(
        class_hash == UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(), 'wrong class hash'
    );

    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_account_class_hash(new_class_hash);

    assert(kakarot_core.account_class_hash() == new_class_hash, 'wrong class hash');
    let event = contract_utils::pop_log::<
        KakarotCore::AccountClassHashChange
    >(kakarot_core.contract_address)
        .unwrap();
    assert(event.old_class_hash == class_hash, 'wrong old hash');
    assert(event.new_class_hash == kakarot_core.account_class_hash(), 'wrong new hash');
}


#[test]
#[available_gas(20000000)]
fn test_eoa_class_hash() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggerred in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let class_hash = kakarot_core.eoa_class_hash();

    assert(
        class_hash == ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        'wrong class hash'
    );

    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_eoa_class_hash(new_class_hash);

    assert(kakarot_core.eoa_class_hash() == new_class_hash, 'wrong class hash');
    let event = contract_utils::pop_log::<
        KakarotCore::EOAClassHashChange
    >(kakarot_core.contract_address)
        .unwrap();
    assert(event.old_class_hash == class_hash, 'wrong old hash');
    assert(event.new_class_hash == kakarot_core.eoa_class_hash(), 'wrong new hash');
}
