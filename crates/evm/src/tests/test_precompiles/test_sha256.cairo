use contracts::tests::test_utils::{setup_contracts_for_testing};
use core::result::ResultTrait;
use evm::instructions::system_operations::SystemOperationsTrait;

use evm::memory::MemoryTrait;
use evm::precompiles::sha256::Sha256PrecompileTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{VMBuilderTrait, native_token, other_starknet_address};
use starknet::testing::set_contract_address;
use utils::helpers::U256Trait;

#[test]
fn test_sha_256_precompile() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let calldata = array![0xFF].span();
    vm.message.data = calldata;

    let gas_before = vm.gas_left;
    Sha256PrecompileTrait::exec(ref vm).unwrap();
    let gas_after = vm.gas_left;

    let result = U256Trait::from_bytes(vm.return_data).unwrap();
    let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;

    assert_eq!(result, expected_result);
    assert_eq!(gas_before - gas_after, 72);
}


#[test]
fn test_sha_256_precompile_static_call() {
    let (_, _) = setup_contracts_for_testing();

    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0x20).unwrap(); // retSize
    vm.stack.push(0x20).unwrap(); // retOffset
    vm.stack.push(0x1).unwrap(); // argsSize
    vm.stack.push(0x1F).unwrap(); // argsOffset
    vm.stack.push(0x2).unwrap(); // address
    vm.stack.push(0xFFFFFFFF).unwrap(); // gas

    vm.memory.store(0xFF, 0x0);

    vm.exec_staticcall().unwrap();

    let result = vm.memory.load(0x20);
    let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;
    assert_eq!(result, expected_result);
}
