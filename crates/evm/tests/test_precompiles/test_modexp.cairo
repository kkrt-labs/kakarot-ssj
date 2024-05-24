use core::result::ResultTrait;

use evm::instructions::system_operations::SystemOperationsTrait;

use evm::memory::MemoryTrait;
use evm::precompiles::Precompiles;
use evm::stack::StackTrait;

use evm_tests::test_precompiles::test_data::test_data_modexp::{
    test_modexp_modsize0_returndatasizeFiller_data,
    test_modexp_create2callPrecompiles_test0_berlin_data, test_modexp_eip198_example_1_data,
    test_modexp_eip198_example_2_data, test_modexp_nagydani_1_square_data,
    test_modexp_nagydani_1_qube_data
};
use evm_tests::test_utils::contracts_utils::{setup_contracts_for_testing};
use evm_tests::test_utils::evm_utils::{VMBuilderTrait, native_token, other_starknet_address};
use starknet::EthAddress;
use starknet::testing::set_contract_address;
use utils::helpers::U256Trait;

// the tests are taken from [revm](https://github.com/bluealloy/revm/blob/0629883f5a40e913a5d9498fa37886348c858c70/crates/precompile/src/modexp.rs#L175)

#[test]
fn test_modexp_modsize0_returndatasizeFiller_filler() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let (calldata, expected) = test_modexp_modsize0_returndatasizeFiller_data();

    vm.message.target.evm = EthAddress { address: 5 };
    vm.message.data = calldata;

    let expected_gas = 44_954;

    let gas_before = vm.gas_left;
    Precompiles::exec_precompile(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(gas_before - gas_after, expected_gas);
    assert_eq!(vm.return_data, expected);
}

#[test]
fn test_modexp_create2callPrecompiles_test0_berlin() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let (calldata, expected) = test_modexp_create2callPrecompiles_test0_berlin_data();

    vm.message.data = calldata;
    vm.message.target.evm = EthAddress { address: 5 };
    let expected_gas = 1_360;

    let gas_before = vm.gas_left;
    Precompiles::exec_precompile(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(gas_before - gas_after, expected_gas);
    assert_eq!(vm.return_data, expected);
}

#[test]
fn test_modexp_eip198_example_1() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let (calldata, expected) = test_modexp_eip198_example_1_data();

    vm.message.target.evm = EthAddress { address: 5 };
    vm.message.data = calldata;
    let expected_gas = 1_360;

    let gas_before = vm.gas_left;
    Precompiles::exec_precompile(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(gas_before - gas_after, expected_gas);
    assert_eq!(vm.return_data, expected);
}

#[test]
fn test_modexp_eip198_example_2() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let (calldata, expected) = test_modexp_eip198_example_2_data();

    vm.message.target.evm = EthAddress { address: 5 };
    vm.message.data = calldata;
    let expected_gas = 1_360;

    let gas_before = vm.gas_left;
    Precompiles::exec_precompile(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(gas_before - gas_after, expected_gas);
    assert_eq!(vm.return_data, expected);
}


#[test]
fn test_modexp_nagydani_1_square() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let (calldata, expected) = test_modexp_nagydani_1_square_data();

    vm.message.target.evm = EthAddress { address: 5 };
    vm.message.data = calldata;
    let expected_gas = 200;

    let gas_before = vm.gas_left;
    Precompiles::exec_precompile(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(gas_before - gas_after, expected_gas);
    assert_eq!(vm.return_data, expected);
}

#[test]
fn test_modexp_nagydani_1_qube() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let (calldata, expected) = test_modexp_nagydani_1_qube_data();

    vm.message.target.evm = EthAddress { address: 5 };
    vm.message.data = calldata;
    let expected_gas = 200;

    let gas_before = vm.gas_left;
    Precompiles::exec_precompile(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(gas_before - gas_after, expected_gas);
    assert_eq!(vm.return_data, expected);
}

#[test]
fn test_modexp_berlin_empty_input() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let calldata = array![].span();
    let expected = array![].span();

    vm.message.target.evm = EthAddress { address: 5 };
    vm.message.data = calldata;

    Precompiles::exec_precompile(ref vm).unwrap();

    assert_eq!(vm.return_data, expected);
}
