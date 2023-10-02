use evm::instructions::BlockInformationTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_machine;
use starknet::testing::{set_block_timestamp, set_block_number};
use utils::constants::CHAIN_ID;

#[test]
#[available_gas(20000000)]
fn test_block_timestamp_set_to_1692873993() {
    // Given
    let mut machine = setup_machine();
    // 24/08/2023 12h46 33s
    // If not set the default timestamp is 0.
    set_block_timestamp(1692873993);
    // When
    machine.exec_timestamp();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 1692873993, 'stack top should be 1692873993');
}

#[test]
#[available_gas(20000000)]
fn test_block_number_set_to_32() {
    // Given
    let mut machine = setup_machine();
    // If not set the default block number is 0.
    set_block_number(32);
    // When
    machine.exec_number();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 32, 'stack top should be 32');
}

#[test]
#[available_gas(20000000)]
fn test_gaslimit() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.exec_gaslimit();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    // This value is set in [setup_execution_context].
    assert(machine.stack.peek().unwrap() == 0xffffff, 'stack top should be 0xffffff');
}

#[test]
#[available_gas(20000000)]
fn test_basefee() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.exec_basefee();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 0xaaaaaa, 'stack top should be 0xaaaaaa');
}

#[test]
#[available_gas(20000000)]
fn test_chainid_should_push_chain_id_to_stack() {
    // Given
    let mut machine = setup_machine();

    // CHAIN_ID = KKRT (0x4b4b5254) in ASCII
    // TODO: Replace the hardcoded value by a value set in kakarot main contract constructor
    let chain_id: u256 = CHAIN_ID;

    // When
    machine.exec_chainid();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(result == chain_id, 'stack should have chain id');
}
