use evm::instructions::SystemOperationsTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_machine;
use evm::instructions::MemoryOperationTrait;
use evm::context::{ExecutionContext, ExecutionContextTrait,};
use utils::helpers::load_word;
use traits::Into;
use evm::machine::{Machine, MachineCurrentContext};

#[test]
#[available_gas(20000000)]
fn test_exec_return() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
}

#[test]
#[available_gas(20000000)]
fn test_exec_return_with_offset() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.stack.push(1);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(1);
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
}
