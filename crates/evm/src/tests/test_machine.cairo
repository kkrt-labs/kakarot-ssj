use evm::errors::DebugEVMError;
use evm::errors::{EVMError, READ_SYSCALL_FAILED};
use evm::model::vm::{VM, VMTrait};
use evm::tests::test_utils::{
    tx_gas_limit, evm_address, starknet_address, VMBuilderTrait, test_address, gas_price
};

#[test]
fn test_vm_default() {
    let mut vm = VMTrait::new(Default::default(), Default::default());

    assert!(vm.pc() == 0);
    assert!(vm.is_running());
    assert!(!vm.error);
    assert_eq!(vm.gas_used(), 0);
}


#[test]
fn test_set_pc() {
    let mut vm = VMTrait::new(Default::default(), Default::default());

    let new_pc = 42;
    vm.set_pc(new_pc);

    assert(vm.pc() == new_pc, 'wrong pc');
}

#[test]
fn test_error() {
    let mut vm = VMTrait::new(Default::default(), Default::default());

    vm.set_error();

    assert!(vm.error);
}

#[test]
fn test_increment_gas_checked() {
    let mut vm = VMTrait::new(Default::default(), Default::default());

    assert(vm.gas_used() == 0, 'wrong gas_used');

    let result = vm.charge_gas(tx_gas_limit());

    assert_eq!(result.unwrap_err(), EVMError::OutOfGas);
}

#[test]
fn test_set_stopped() {
    let mut vm = VMTrait::new(Default::default(), Default::default());

    vm.stop();

    assert!(!vm.is_running())
}

#[test]
fn test_read_code() {
    // Given a vm with some bytecode in the call context

    let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
    // When we read a code slice
    let read_code = vm.read_code(3);

    // Then the read code should be the expected slice and the PC should be updated
    assert(read_code == array![0x01, 0x02, 0x03].span(), 'wrong bytecode read');
    // Read Code should not modify PC
    assert(vm.pc() == 0, 'wrong pc');
}

#[test]
fn test_set_return() {
    let mut vm = VMTrait::new(Default::default(), Default::default());
    vm.set_return_data(array![0x01, 0x02, 0x03].span());
    let return_data = vm.return_data();
    assert(return_data == array![0x01, 0x02, 0x03].span(), 'wrong return data');
}

#[test]
fn test_return_data() {
    let mut vm = VMTrait::new(Default::default(), Default::default());

    let return_data = vm.return_data();
    assert(return_data.len() == 0, 'wrong length');
}

