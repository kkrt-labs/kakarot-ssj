use evm::context::{ExecutionContext, ExecutionContextTrait,};
use evm::instructions::MemoryOperationTrait;
use evm::instructions::SystemOperationsTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::stack::StackTrait;
use evm::tests::test_utils::{
    setup_machine_with_nested_execution_context, setup_machine, parent_ctx_return_data
};
use utils::helpers::load_word;

#[test]
#[available_gas(20000000)]
fn test_exec_return() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(1000 == load_word(32, parent_ctx_return_data(ref machine)), 'Wrong return_data');
}

#[test]
#[available_gas(20000000)]
fn test_exec_return_with_offset() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
    // When
    machine.stack.push(1);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(1);
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(256 == load_word(32, parent_ctx_return_data(ref machine)), 'Wrong return_data');
}
