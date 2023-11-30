//TODO(migration): test vm methods (low-prio)
// use evm::model::vm::{VM, VMTrait};
// use evm::context::{CallContextTrait, ExecutionContextType, ExecutionContextTrait};
// use evm::errors::DebugEVMError;
// use evm::errors::{EVMError, READ_SYSCALL_FAILED};
// use evm::tests::test_utils::{
//     gas_limit, evm_address, starknet_address, VMBuilderTrait, test_address, gas_price
// };

// #[test]
// fn test_machine_default() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     assert(machine.ctx_count == 1, 'wrong ctx_count');
//     assert(machine.pc() == 0, 'wrong current ctx pc');
//     assert(!machine.reverted(), 'ctx should not be reverted');
//     assert(!vm.stopped(), 'ctx should not be stopped');
// }

// #[test]
// fn test_set_current_ctx() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     let first_ctx = machine.current_ctx.unbox();
//     assert(first_ctx.id() == 0, 'wrong first id');
//     // We need to re-box the context into the machine, otherwise we have a "Variable Moved" error.
//     machine.current_ctx = BoxTrait::new(first_ctx);
//     assert(vm.stack.active_segment == 0, 'wrong initial stack segment');
//     assert(vm.memory.active_segment == 0, 'wrong initial memory segment');

//     // Create another context with id=1
//     let mut second_machine = VMBuilderTrait::new_with_presets().build();
//     let mut second_ctx = second_machine.current_ctx.unbox();
//     second_ctx.ctx_type = ExecutionContextType::Call(1);

//     vm.set_current_ctx(second_ctx);
//     assert(vm.stack.active_segment == 1, 'wrong updated stack segment');
//     assert(vm.memory.active_segment == 1, 'wrong updated stack segment');
//     assert(machine.current_ctx.unbox().id() == 1, 'wrong updated id');
// }

// #[test]
// fn test_set_pc() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     let new_pc = 42;
//     vm.set_pc(new_pc);

//     assert(machine.pc() == new_pc, 'wrong pc');
// }

// #[test]
// fn test_revert() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     vm.set_reverted();

//     assert(machine.reverted(), 'ctx should be reverted');
//     assert(!vm.is_running(), 'ctx should be stopped');
// }

// #[test]
// fn test_increment_gas_unchecked() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     assert(machine.gas_used() == 0, 'wrong gas_used');

//     machine.increment_gas_used_unchecked(gas_limit());

//     assert(machine.gas_used() == gas_limit(), 'wrong gas_used');
// }

// #[test]
// fn test_increment_gas_checked() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     assert(machine.gas_used() == 0, 'wrong gas_used');

//     let result = machine.charge_gas(gas_limit());

//     assert_eq!(result.unwrap_err(), EVMError::OutOfGas);
// }

// #[test]
// fn test_set_stopped() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     vm.set_stopped();

//     assert(!machine.reverted(), 'ctx should not be reverted');
//     assert(!vm.is_running(), 'ctx should be stopped');
// }

// #[test]
// fn test_read_code() {
//     // Given a machine with some bytecode in the call context

//     let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();

//     let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
//     // When we read a code slice
//     let read_code = machine.read_code(3);

//     // Then the read code should be the expected slice and the PC should be updated
//     assert(read_code == array![0x01, 0x02, 0x03].span(), 'wrong bytecode read');
//     // Read Code should not modify PC
//     assert(machine.pc() == 0, 'wrong pc');
// }

// #[test]
// fn test_is_root() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     assert(machine.is_root(), 'current_ctx should be root');
// }

// #[test]
// fn test_call_context_properties() {
//     let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();

//     let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

//     let call_ctx = machine.call_ctx();
//     assert(call_ctx.read_only() == false, 'wrong read_only');
//     assert(call_ctx.gas_limit() == gas_limit(), 'wrong gas_limit');
//     assert(call_ctx.gas_price() == gas_price(), 'wrong gas_price');
//     assert(call_ctx.value() == 123456789, 'wrong value');
//     assert(call_ctx.bytecode() == bytecode, 'wrong bytecode');
//     assert(call_ctx.calldata() == array![4, 5, 6].span(), 'wrong calldata');
// }

// #[test]
// fn test_addresses() {
//     let expected_address = test_address();
//     let mut vm = VMBuilderTrait::new_with_presets().build();

//     let evm_address = machine.address();
//     assert(evm_address == expected_address, 'wrong evm address');
// }

// #[test]
// fn test_set_return_data_root() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());
//     vm.set_return_data(array![0x01, 0x02, 0x03].span());
//     let return_data = machine.return_data();
//     assert(return_data == array![0x01, 0x02, 0x03].span(), 'wrong return data');
// }

// #[test]
// fn test_set_return_data_subctx() {
//     let mut vm = VMBuilderTrait::new().with_nested_vm().build();

//     vm.set_return_data(array![0x01, 0x02, 0x03].span());
//     let return_data = machine.return_data();
//     assert(return_data == array![0x01, 0x02, 0x03].span(), 'wrong return data');
// }

// #[test]
// fn test_return_data() {
//     let mut vm = VMTrait::new(Default::default(), Default::default());

//     let return_data = machine.return_data();
//     assert(return_data.len() == 0, 'wrong length');
// }

