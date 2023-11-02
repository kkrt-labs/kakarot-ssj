use contracts::tests::test_utils as contracts_utils;
use evm::call_helpers::MachineCallHelpers;
use evm::call_helpers::MachineCallHelpersImpl;
use evm::context::{ExecutionContext, ExecutionContextTrait,};
use evm::instructions::MemoryOperationTrait;
use evm::instructions::SystemOperationsTrait;
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{
    setup_machine_with_nested_execution_context, setup_machine, setup_machine_with_bytecode,
    parent_ctx_return_data, initialize_contract_account, native_token,
};
use starknet::{EthAddress, testing};
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
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
    assert(machine.id() == 1, 'wrong ctx id');

    // And
    machine.finalize_calling_context();

    // Then
    assert(machine.id() == 0, 'should be parent id');
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
}


#[test]
#[available_gas(20000000)]
fn test_exec_revert() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_revert().is_ok(), 'Exec revert failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}

#[test]
#[available_gas(20000000)]
fn test_exec_revert_nested() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_revert().is_ok(), 'Exec revert failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
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
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
    assert(machine.id() == 1, 'wrong ctx id');

    // And
    machine.finalize_calling_context();

    // Then
    assert(machine.id() == 0, 'should be parent id');
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
}

#[test]
#[available_gas(40000000)]
fn test_exec_call() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let native_token = contracts_utils::deploy_native_token();
    let kakarot_core = contracts_utils::deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        0xf1,
        0x00
    ]
        .span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    // Deploy bytecode at 0x100
    // ret (+ 0x1 0x1)
    let deployed_bytecode = array![
        0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x60, 0x20, 0x60, 0x00, 0xf3
    ]
        .span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}

#[test]
#[available_gas(40000000)]
fn test_exec_call_no_return() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let native_token = contracts_utils::deploy_native_token();
    let kakarot_core = contracts_utils::deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        0xf1,
        0x00
    ]
        .span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    // Deploy bytecode at 0x100
    // (+ 0x1 0x1)
    let deployed_bytecode = array![0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x00].span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.return_data().is_empty(), 'Wrong return_data len');
    assert(machine.stopped(), 'machine should be stopped')
}
