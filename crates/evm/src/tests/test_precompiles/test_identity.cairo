use contracts::tests::test_utils::{setup_contracts_for_testing};
use core::result::ResultTrait;
use evm::instructions::system_operations::SystemOperationsTrait;

use evm::memory::MemoryTrait;
use evm::precompiles::identity::IdentityPrecompileTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{VMBuilderTrait, native_token, other_starknet_address};
use starknet::testing::set_contract_address;

#[test]
fn test_identity_precompile() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let calldata = array![0x2A].span();
    vm.message.data = calldata;

    let gas_before = vm.gas_left;
    IdentityPrecompileTrait::exec(ref vm).unwrap();
    let gas_after = vm.gas_left;

    assert_eq!(calldata, vm.return_data);
    assert_eq!(gas_before - gas_after, 18);
}


#[test]
fn test_identity_precompile_static_call() {
    let (_, _) = setup_contracts_for_testing();

    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0x20).unwrap(); // retSize
    vm.stack.push(0x3F).unwrap(); // retOffset
    vm.stack.push(0x20).unwrap(); // argsSize
    vm.stack.push(0x1F).unwrap(); // argsOffset
    vm.stack.push(0x4).unwrap(); // address
    vm.stack.push(0xFFFFFFFF).unwrap(); // gas

    vm.memory.store(0x2A, 0x1F);

    vm.exec_staticcall().unwrap();

    let result = vm.memory.load(0x3F);
    assert_eq!(result, 0x2A);
}
