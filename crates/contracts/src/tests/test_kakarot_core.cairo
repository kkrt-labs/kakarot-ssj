use contracts::contract_account::ContractAccount::TEST_CLASS_HASH as ContractAccountTestClassHash;
use contracts::contract_account::ContractAccount;
use contracts::contract_account::{IContractAccountDispatcher, IContractAccountDispatcherTrait};
use contracts::eoa::{
    ExternallyOwnedAccount, IExternallyOwnedAccountDispatcher,
    IExternallyOwnedAccountDispatcherTrait
};
use contracts::kakarot_core::interface::IKakarotCore;
use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore, KakarotCore::{KakarotCoreInternal},
};
use contracts::tests::test_data::{deploy_counter_calldata, counter_evm_bytecode};
use contracts::tests::test_upgradeable::{
    MockContractUpgradeableV1, IMockContractUpgradeableDispatcher,
    IMockContractUpgradeableDispatcherTrait
};
use contracts::tests::test_utils as contract_utils;
use contracts::uninitialized_account::UninitializedAccount;
use core::option::OptionTrait;


use core::traits::TryInto;
use evm::model::{AccountType, Address};
use evm::tests::test_utils;
use starknet::{testing, contract_address_const, ContractAddress, EthAddress, ClassHash};
use utils::helpers::{EthAddressExTrait, u256_to_bytes_array};
//Required for assert_eq! macro
use utils::traits::{EthAddressDebug, ContractAddressDebug};

#[test]
fn test_kakarot_core_owner() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());

    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner')
}

#[test]
fn test_kakarot_core_transfer_ownership() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.transfer_ownership(test_utils::starknet_address());
    assert(kakarot_core.owner() == test_utils::starknet_address(), 'wrong owner')
}

#[test]
fn test_kakarot_core_renounce_ownership() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}

#[test]
fn test_kakarot_core_deploy_fee() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.deploy_fee() == contract_utils::deploy_fee(), 'wrong deploy_fee');
}

#[test]
fn test_kakarot_core_chain_id() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.chain_id() == contract_utils::chain_id(), 'wrong chain id');
}

#[test]
fn test_kakarot_core_set_deploy_fee() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    assert(kakarot_core.deploy_fee() == contract_utils::deploy_fee(), 'wrong deploy_fee');
    testing::set_contract_address(test_utils::other_starknet_address());
    kakarot_core.set_deploy_fee(0x100);
    assert(kakarot_core.deploy_fee() == 0x100, 'wrong new deploy_fee');
}

#[test]
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
fn test_kakarot_core_deploy_eoa() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let eoa_starknet_address = kakarot_core.deploy_eoa(test_utils::evm_address());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggered in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let event = contract_utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address)
        .unwrap();
    assert(event.starknet_address == eoa_starknet_address, 'wrong starknet address');
}

#[test]
fn test_kakarot_core_eoa_mapping() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    assert(
        kakarot_core.address_registry(test_utils::evm_address()).is_none(),
        'should be uninitialized'
    );

    let expected_eoa_starknet_address = kakarot_core.deploy_eoa(test_utils::evm_address());

    // When
    let (account_type, address) = kakarot_core
        .address_registry(test_utils::evm_address())
        .expect('should be in registry');

    // Then
    assert(account_type == AccountType::EOA, 'wrong account_type address');
    assert(address == expected_eoa_starknet_address, 'wrong address');

    let another_sn_address: ContractAddress = 0xbeef.try_into().unwrap();

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    kakarot_state
        .set_address_registry(
            test_utils::evm_address(), StoredAccountType::EOA(another_sn_address)
        );

    let (account_type, address) = kakarot_core
        .address_registry(test_utils::evm_address())
        .expect('should be in registry');
    assert(account_type == AccountType::EOA, 'wrong registry address2');
    assert(address == another_sn_address, 'wrong address2');
}

#[test]
#[ignore]
fn test_kakarot_core_compute_starknet_address() {
    let evm_address = test_utils::evm_address();
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let expected_starknet_address = kakarot_core.deploy_eoa(evm_address);

    let actual_starknet_address = kakarot_core.compute_starknet_address(evm_address);
    assert_eq!(actual_starknet_address, expected_starknet_address);
}

#[test]
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

#[test]
fn test_kakarot_contract_account_nonce() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let address = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), Default::default().span()
    );

    // When
    let nonce = kakarot_core.contract_account_nonce(address.evm);

    // Then
    assert(nonce == 1, 'wrong nonce');
}

#[test]
fn test_kakarot_contract_account_storage_at() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let address = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), Default::default().span()
    );
    let ca = IContractAccountDispatcher { contract_address: address.starknet };
    let expected_value = 420;
    let key = 69;
    ca.set_storage_at(69, expected_value);

    // When
    let value = kakarot_core.contract_account_storage_at(address.evm, key);

    // Then
    assert(value == expected_value, 'wrong storage value');
}

#[test]
fn test_kakarot_contract_account_bytecode() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let address = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), counter_evm_bytecode()
    );

    // When
    let bytecode = kakarot_core.contract_account_bytecode(address.evm);

    // Then
    assert(bytecode == counter_evm_bytecode(), 'wrong bytecode');
}

#[test]
#[should_panic(expected: ('unimplemented', 'ENTRYPOINT_FAILED'))]
fn test_kakarot_contract_account_false_positive_jumpdest() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let address = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), Default::default().span()
    );
    let ca = IContractAccountDispatcher { contract_address: address.starknet };
    let offset = 1337;
    ca.set_false_positive_jumpdest(offset);

    // When
    let is_false_jumpdest = kakarot_core
        .contract_account_false_positive_jumpdest(address.evm, offset);

    // Then
    assert(is_false_jumpdest, 'should be false jumpdest');
}

#[test]
#[ignore]
fn test_eth_send_transaction() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

    let account = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), counter_evm_bytecode()
    );

    let to = Option::Some(test_utils::other_evm_address());
    let gas_limit = test_utils::tx_gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;

    // Then
    // selector: function get()
    let data_get_tx = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // check counter value is 0 before doing inc
    let (_, return_data) = kakarot_core
        .eth_call(
            origin: evm_address,
            to: Option::Some(account.evm),
            gas_limit: gas_limit,
            gas_price: gas_price,
            value: 0,
            calldata: data_get_tx
        );

    assert(return_data == u256_to_bytes_array(0).span(), 'counter value not 0');

    // selector: function inc()
    let calldata = array![0x37, 0x13, 0x03, 0xc0].span();

    // When
    testing::set_contract_address(eoa);
    let return_data = kakarot_core
        .eth_send_transaction(:to, :gas_limit, :gas_price, :value, :calldata);

    // Then
    // selector: function get()
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // When
    let (_, return_data) = kakarot_core
        .eth_call(origin: evm_address, :to, :gas_limit, :gas_price, :value, :calldata);

    // Then
    assert(return_data == u256_to_bytes_array(1).span(), 'counter value is not 1');
}

#[test]
#[ignore]
fn test_eth_call() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    kakarot_core.deploy_eoa(evm_address);

    let account = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), counter_evm_bytecode()
    );
    let counter = IContractAccountDispatcher { contract_address: account.starknet };
    counter.set_storage_at(0, 1);

    let to = Option::Some(test_utils::other_evm_address());
    let gas_limit = test_utils::tx_gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;
    // selector: function get()
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // When
    let (_, return_data) = kakarot_core
        .eth_call(origin: evm_address, :to, :gas_limit, :gas_price, :value, :calldata);

    // Then
    assert(return_data == u256_to_bytes_array(1).span(), 'wrong result');
}

#[test]
#[ignore]
fn test_process_transaction() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

    let _account = contract_utils::deploy_contract_account(
        test_utils::other_evm_address(), counter_evm_bytecode()
    );

    let to = Option::Some(test_utils::other_evm_address());
    let gas_limit = test_utils::tx_gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;
    // selector: function get()
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // When
    let mut kakarot_core = KakarotCore::unsafe_new_contract_state();
    let result = kakarot_core
        .process_transaction(
            origin: Address { evm: evm_address, starknet: eoa },
            :to,
            :gas_limit,
            :gas_price,
            :value,
            :calldata
        );
    let return_data = result.return_data;

    assert!(result.success);

    // Then
    assert(return_data == u256_to_bytes_array(0).span(), 'wrong result');
}

#[test]
#[ignore]
fn test_eth_send_transaction_deploy_tx() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

    let to = Option::None;
    let gas_limit = test_utils::tx_gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;

    // When
    // Set the contract address to the EOA address, so that the caller of the `eth_send_transaction` is an eoa
    testing::set_contract_address(eoa);
    let (_, deploy_result) = kakarot_core
        .eth_send_transaction(
            :to, :gas_limit, :gas_price, :value, calldata: deploy_counter_calldata()
        );

    // Then
    let expected_address: EthAddress = 0x19587b345dcadfe3120272bd0dbec24741891759
        .try_into()
        .unwrap();
    assert(deploy_result == expected_address.to_bytes().span(), 'returndata not counter bytecode');

    // Set back the contract address to Kakarot for the calculation of the deployed SN contract address, where we use a kakarot
    // internal functions and thus must "mock" its address.
    testing::set_contract_address(kakarot_core.contract_address);
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let computed_sn_addr = kakarot_state.compute_starknet_address(expected_address);
    let CA = IContractAccountDispatcher { contract_address: computed_sn_addr };
    let bytecode = CA.bytecode();
    assert(bytecode == counter_evm_bytecode(), 'wrong bytecode');

    // Check that the account was created and `get` returns 0.
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();
    let to = Option::Some(expected_address);

    // No need to set address back to eoa, as eth_call doesn't use the caller address.
    let (_, result) = kakarot_core
        .eth_call(origin: evm_address, :to, :gas_limit, :gas_price, :value, :calldata);
    // Then
    assert(result == u256_to_bytes_array(0).span(), 'wrong result');
}
#[test]
fn test_contract_account_class_hash() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggered in the constructor
    contract_utils::drop_event(kakarot_core.contract_address);

    let class_hash = kakarot_core.ca_class_hash();

    assert(class_hash == ContractAccountTestClassHash.try_into().unwrap(), 'wrong class hash');

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
fn test_account_class_hash() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggered in the constructor
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
fn test_eoa_class_hash() {
    let kakarot_core = contract_utils::deploy_kakarot_core(test_utils::native_token());
    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggered in the constructor
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
