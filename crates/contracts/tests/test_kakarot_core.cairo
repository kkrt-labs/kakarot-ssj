use contracts::account_contract::{
    IAccountDispatcher, IAccountDispatcherTrait, AccountContract::TEST_CLASS_HASH
};
use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};
use contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore, KakarotCore::{KakarotCoreInternal},
};
use contracts::test_data::{deploy_counter_calldata, counter_evm_bytecode};
use contracts::uninitialized_account::UninitializedAccount;
use contracts_tests::test_upgradeable::{
    MockContractUpgradeableV1, IMockContractUpgradeableDispatcher,
    IMockContractUpgradeableDispatcherTrait
};
use contracts_tests::test_utils::contracts_utils;
use contracts_tests::test_utils::evm_utils::{sequencer_evm_address, chain_id};
use contracts_tests::test_utils::evm_utils as evm_utils;
use core::num::traits::Zero;
use core::option::OptionTrait;


use core::traits::TryInto;
use evm::model::{Address};
use starknet::{testing, contract_address_const, ContractAddress, EthAddress, ClassHash};
use utils::eth_transaction::{EthereumTransaction, EthereumTransactionTrait, LegacyTransaction};
use utils::helpers::{EthAddressExTrait, u256_to_bytes_array};

#[test]
fn test_kakarot_core_owner() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    assert(kakarot_core.owner() == evm_utils::other_starknet_address(), 'wrong owner')
}

#[test]
fn test_kakarot_core_transfer_ownership() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    assert(kakarot_core.owner() == evm_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(evm_utils::other_starknet_address());
    kakarot_core.transfer_ownership(evm_utils::starknet_address());
    assert(kakarot_core.owner() == evm_utils::starknet_address(), 'wrong owner')
}

#[test]
fn test_kakarot_core_renounce_ownership() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    assert(kakarot_core.owner() == evm_utils::other_starknet_address(), 'wrong owner');
    testing::set_contract_address(evm_utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}

#[test]
fn test_kakarot_core_chain_id() {
    contracts_utils::setup_contracts_for_testing();

    assert(chain_id() == contracts_utils::chain_id(), 'wrong chain id');
}

#[test]
fn test_kakarot_core_set_native_token() {
    let (native_token, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    assert(kakarot_core.get_native_token() == native_token.contract_address, 'wrong native_token');

    testing::set_contract_address(evm_utils::other_starknet_address());
    kakarot_core.set_native_token(contract_address_const::<0xdead>());
    assert(
        kakarot_core.get_native_token() == contract_address_const::<0xdead>(),
        'wrong new native_token'
    );
}

#[test]
fn test_kakarot_core_deploy_eoa() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();
    let eoa_starknet_address = kakarot_core
        .deploy_externally_owned_account(evm_utils::evm_address());

    let event = contracts_utils::pop_log::<
        KakarotCore::AccountDeployed
    >(kakarot_core.contract_address)
        .unwrap();
    assert_eq!(event.starknet_address, eoa_starknet_address);
}

#[test]
fn test_kakarot_core_eoa_mapping() {
    // Given
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();
    assert(
        kakarot_core.address_registry(evm_utils::evm_address()).is_zero(),
        'should be uninitialized'
    );

    let expected_eoa_starknet_address = kakarot_core
        .deploy_externally_owned_account(evm_utils::evm_address());

    // When
    let address = kakarot_core.address_registry(evm_utils::evm_address());

    // Then
    assert_eq!(address, expected_eoa_starknet_address);

    let another_sn_address: ContractAddress = 0xbeef.try_into().unwrap();

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    kakarot_state.set_address_registry(evm_utils::evm_address(), another_sn_address);

    let address = kakarot_core.address_registry(evm_utils::evm_address());
    assert_eq!(address, another_sn_address)
}

#[test]
fn test_kakarot_core_compute_starknet_address() {
    let evm_address = evm_utils::evm_address();
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();
    let expected_starknet_address = kakarot_core.deploy_externally_owned_account(evm_address);

    let actual_starknet_address = kakarot_core.compute_starknet_address(evm_address);
    assert_eq!(actual_starknet_address, expected_starknet_address);
}

#[test]
fn test_kakarot_core_upgrade_contract() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();

    testing::set_contract_address(evm_utils::other_starknet_address());
    kakarot_core.upgrade(class_hash);

    let version = IMockContractUpgradeableDispatcher {
        contract_address: kakarot_core.contract_address
    }
        .version();
    assert(version == 1, 'version is not 1');
}

#[test]
#[available_gas(2000000000000000000)]
fn test_eth_send_transaction_non_deploy_tx() {
    // Given
    let (native_token, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let evm_address = evm_utils::evm_address();
    let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
    contracts_utils::fund_account_with_native_token(
        eoa, native_token, 0xfffffffffffffffffffffffffff
    );

    let counter_address = 'counter_contract'.try_into().unwrap();
    contracts_utils::deploy_contract_account(counter_address, counter_evm_bytecode());

    let gas_limit = evm_utils::tx_gas_limit();
    let gas_price = evm_utils::gas_price();
    let value = 0;

    // Then
    // selector: function get()
    let data_get_tx = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // check counter value is 0 before doing inc
    let tx = contracts_utils::call_transaction(
        chain_id(), Option::Some(counter_address), data_get_tx
    );
    let (_, return_data) = kakarot_core
        .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx));

    assert_eq!(return_data, u256_to_bytes_array(0).span());

    // selector: function inc()
    let data_increment_counter = array![0x37, 0x13, 0x03, 0xc0].span();

    // When
    testing::set_contract_address(eoa);

    let tx = LegacyTransaction {
        chain_id: chain_id(),
        nonce: 0,
        destination: Option::Some(counter_address),
        amount: value,
        gas_price,
        gas_limit,
        calldata: data_increment_counter
    };

    let (success, _) = kakarot_core
        .eth_send_transaction(EthereumTransaction::LegacyTransaction(tx));
    assert!(success);

    // Then
    // selector: function get()
    let data_get_tx = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // check counter value is 1
    let tx = contracts_utils::call_transaction(
        chain_id(), Option::Some(counter_address), data_get_tx
    );
    let (_, _) = kakarot_core
        .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx));
    let (_, return_data) = kakarot_core
        .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx));

    // Then
    assert_eq!(return_data, u256_to_bytes_array(1).span());
}

#[test]
fn test_eth_call() {
    // Given
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let evm_address = evm_utils::evm_address();
    kakarot_core.deploy_externally_owned_account(evm_address);

    let account = contracts_utils::deploy_contract_account(
        evm_utils::other_evm_address(), counter_evm_bytecode()
    );
    let counter = IAccountDispatcher { contract_address: account.starknet };
    counter.write_storage(0, 1);

    let to = Option::Some(evm_utils::other_evm_address());
    // selector: function get()
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    // When
    let tx = contracts_utils::call_transaction(chain_id(), to, calldata);
    let (success, return_data) = kakarot_core
        .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx));

    // Then
    assert_eq!(success, true);
    assert_eq!(return_data, u256_to_bytes_array(1).span());
}

#[test]
fn test_process_transaction() {
    // Given
    let (native_token, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let evm_address = evm_utils::evm_address();
    let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
    contracts_utils::fund_account_with_native_token(
        eoa, native_token, 0xfffffffffffffffffffffffffff
    );
    let chain_id = chain_id();

    let _account = contracts_utils::deploy_contract_account(
        evm_utils::other_evm_address(), counter_evm_bytecode()
    );

    let nonce = 0;
    let to = Option::Some(evm_utils::other_evm_address());
    let gas_limit = evm_utils::tx_gas_limit();
    let gas_price = evm_utils::gas_price();
    let value = 0;
    // selector: function get()
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();

    let tx = EthereumTransaction::LegacyTransaction(
        LegacyTransaction {
            chain_id, nonce, destination: to, amount: value, gas_price, gas_limit, calldata
        }
    );

    // When
    let mut kakarot_core = KakarotCore::unsafe_new_contract_state();
    let result = kakarot_core
        .process_transaction(origin: Address { evm: evm_address, starknet: eoa }, :tx);
    let return_data = result.return_data;

    // Then
    assert!(result.success);
    assert(return_data == u256_to_bytes_array(0).span(), 'wrong result');
}

#[test]
fn test_eth_send_transaction_deploy_tx() {
    // Given
    let (native_token, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let evm_address = evm_utils::evm_address();
    let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
    contracts_utils::fund_account_with_native_token(
        eoa, native_token, 0xfffffffffffffffffffffffffff
    );

    let gas_limit = evm_utils::tx_gas_limit();
    let gas_price = evm_utils::gas_price();
    let value = 0;

    // When
    // Set the contract address to the EOA address, so that the caller of the `eth_send_transaction` is an eoa
    let tx = LegacyTransaction {
        chain_id: chain_id(),
        nonce: 0,
        destination: Option::None,
        amount: value,
        gas_price,
        gas_limit,
        calldata: deploy_counter_calldata()
    };
    testing::set_contract_address(eoa);
    let (_, deploy_result) = kakarot_core
        .eth_send_transaction(EthereumTransaction::LegacyTransaction(tx));

    // Then
    let expected_address: EthAddress = 0x19587b345dcadfe3120272bd0dbec24741891759
        .try_into()
        .unwrap();
    assert(deploy_result == expected_address.to_bytes().span(), 'returndata not counter bytecode');

    // Set back the contract address to Kakarot for the calculation of the deployed SN contract address, where we use a kakarot
    // internal functions and thus must "mock" its address.
    let computed_sn_addr = kakarot_core.compute_starknet_address(expected_address);
    let CA = IAccountDispatcher { contract_address: computed_sn_addr };
    let bytecode = CA.bytecode();
    assert(bytecode == counter_evm_bytecode(), 'wrong bytecode');

    // Check that the account was created and `get` returns 0.
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c].span();
    let to = Option::Some(expected_address);

    // No need to set address back to eoa, as eth_call doesn't use the caller address.
    let tx = LegacyTransaction {
        chain_id: chain_id(),
        nonce: 0,
        destination: to,
        amount: value,
        gas_price,
        gas_limit,
        calldata
    };
    let (_, result) = kakarot_core
        .eth_call(origin: evm_address, tx: EthereumTransaction::LegacyTransaction(tx));
    // Then
    assert(result == u256_to_bytes_array(0).span(), 'wrong result');
}


#[test]
fn test_account_class_hash() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let class_hash = kakarot_core.uninitialized_account_class_hash();

    assert(
        class_hash == UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(), 'wrong class hash'
    );

    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();
    testing::set_contract_address(evm_utils::other_starknet_address());
    kakarot_core.set_account_class_hash(new_class_hash);

    assert(kakarot_core.uninitialized_account_class_hash() == new_class_hash, 'wrong class hash');
    let event = contracts_utils::pop_log::<
        KakarotCore::AccountClassHashChange
    >(kakarot_core.contract_address)
        .unwrap();
    assert(event.old_class_hash == class_hash, 'wrong old hash');
    assert(
        event.new_class_hash == kakarot_core.uninitialized_account_class_hash(), 'wrong new hash'
    );
}

#[test]
fn test_account_contract_class_hash() {
    let (_, kakarot_core) = contracts_utils::setup_contracts_for_testing();

    let class_hash = kakarot_core.get_account_contract_class_hash();

    assert(class_hash == TEST_CLASS_HASH.try_into().unwrap(), 'wrong class hash');

    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();
    testing::set_contract_address(evm_utils::other_starknet_address());
    kakarot_core.set_account_contract_class_hash(new_class_hash);

    assert(kakarot_core.get_account_contract_class_hash() == new_class_hash, 'wrong class hash');
    let event = contracts_utils::pop_log::<
        KakarotCore::EOAClassHashChange
    >(kakarot_core.contract_address)
        .unwrap();
    assert(event.old_class_hash == class_hash, 'wrong old hash');
    assert(
        event.new_class_hash == kakarot_core.get_account_contract_class_hash(), 'wrong new hash'
    );
}
