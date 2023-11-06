use contracts::tests::test_utils::setup_contracts_for_testing;
use evm::errors::{EVMError, STACK_UNDERFLOW, INVALID_DESTINATION, WRITE_IN_STATIC_CONTEXT};
use evm::instructions::{MemoryOperationTrait, EnvironmentInformationTrait};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::stack::StackTrait;
use evm::state::{StateTrait, StateInternalTrait, compute_storage_address};
use evm::tests::test_utils::{
    setup_machine, setup_machine_with_bytecode, evm_address, setup_static_machine
};
use integer::BoundedInt;
use starknet::get_contract_address;

#[test]
#[available_gas(20000000)]
fn test_pc_basic() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_pc();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == 0, 'PC should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_pc_gets_updated_properly_1() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.set_pc(9000);
    machine.exec_pc();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == 9000, 'updating PC failed');
}

// 0x51 - MLOAD

#[test]
#[available_gas(20000000000)]
fn test_exec_mload_should_load_a_value_from_memory() {
    assert_mload(0x1, 0, 0x1, 32);
}

#[test]
#[available_gas(20000000000)]
fn test_exec_mload_should_load_a_value_from_memory_with_memory_expansion() {
    assert_mload(0x1, 16, 0x100000000000000000000000000000000, 64);
}

#[test]
#[available_gas(20000000000)]
fn test_exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize() {
    assert_mload(0x1, 684, 0x0, 736);
}

fn assert_mload(value: u256, offset: u256, expected_value: u256, expected_memory_size: u32) {
    // Given
    let mut machine = setup_machine();
    machine.memory.store(value, 0);

    machine.stack.push(offset);

    // When
    machine.exec_mload();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == expected_value, 'mload failed');
    assert(machine.memory.size() == expected_memory_size, 'memory size error');
}

#[test]
#[available_gas(20000000)]
fn test_exec_pop_should_pop_an_item_from_stack() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0x01);
    machine.stack.push(0x02);

    // When
    let result = machine.exec_pop();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 0x01, 'stack peek should return 0x01');
}

#[test]
#[available_gas(20000000)]
fn test_exec_pop_should_stack_underflow() {
    // Given
    let mut machine = setup_machine();

    // When
    let result = machine.exec_pop();

    // Then
    assert(result.is_err(), 'should return Err ');
    assert(
        result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW), 'should return StackUnderflow'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_max_uint256_offset_0() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(BoundedInt::<u256>::max());
    machine.stack.push(0x00);

    // When
    let result = machine.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = machine.memory.load(0);
    assert(stored == BoundedInt::<u256>::max(), 'should have stored max_uint256');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore_should_store_max_uint256_offset_1() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(BoundedInt::<u256>::max());
    machine.stack.push(0x01);

    // When
    let result = machine.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 64, 'memory should be 64 bytes long');
    let stored = machine.memory.load(1);
    assert(stored == BoundedInt::<u256>::max(), 'should have stored max_uint256');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_uint8_offset_31() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0xAB);
    machine.stack.push(31);

    // When
    let result = machine.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = machine.memory.load(0);
    assert(stored == 0xAB, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_uint8_offset_30() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0xAB);
    machine.stack.push(30);

    // When
    let result = machine.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = machine.memory.load(0);
    assert(stored == 0xAB00, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_uint8_offset_31_then_uint8_offset_30() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0xAB);
    machine.stack.push(30);
    machine.stack.push(0xCD);
    machine.stack.push(31);

    // When
    let result1 = machine.exec_mstore8();
    let result2 = machine.exec_mstore8();

    // Then
    assert(result1.is_ok() && result2.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = machine.memory.load(0);
    assert(stored == 0xABCD, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_last_uint8_offset_31() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0x123456789ABCDEF);
    machine.stack.push(31);

    // When
    let result = machine.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = machine.memory.load(0);
    assert(stored == 0xEF, 'mstore8 failed');
}


#[test]
#[available_gas(20000000)]
fn test_exec_mstore8_should_store_last_uint8_offset_63() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0x123456789ABCDEF);
    machine.stack.push(63);

    // When
    let result = machine.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.memory.size() == 64, 'memory should be 64 bytes long');
    let stored = machine.memory.load(32);
    assert(stored == 0xEF, 'mstore8 failed');
}

#[test]
#[available_gas(20000000)]
fn test_msize_initial() {
    // Given
    let mut machine = setup_machine();

    // When
    let result = machine.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == 0, 'initial memory size should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_msize_store_max_offset_0() {
    // Given
    let mut machine = setup_machine();
    machine.memory.store(BoundedInt::<u256>::max(), 0x00);

    // When
    let result = machine.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == 32, 'should 32 bytes after MSTORE');
}

#[test]
#[available_gas(20000000)]
fn test_exec_msize_store_max_offset_1() {
    // Given
    let mut machine = setup_machine();
    machine.memory.store(BoundedInt::<u256>::max(), 0x01);

    // When
    let result = machine.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == 64, 'should 64 bytes after MSTORE');
}

#[test]
#[available_gas(20000000)]
fn test_exec_jump_valid() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let counter = 0x03;
    machine.stack.push(counter);

    // When
    machine.exec_jump();

    // Then
    let pc = machine.pc();
    assert(pc == 0x03, 'PC should be JUMPDEST');
}


#[test]
#[available_gas(20000000)]
fn test_exec_jump_invalid() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let counter = 0x02;
    machine.stack.push(counter);

    // When
    let result = machine.exec_jump();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::JumpError(INVALID_DESTINATION), 'invalid jump dest');
}

#[test]
#[available_gas(20000000)]
fn test_exec_jump_out_of_bounds() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let counter = 0xFF;
    machine.stack.push(counter);

    // When
    let result = machine.exec_jump();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::JumpError(INVALID_DESTINATION), 'invalid jump dest');
}

// TODO: This is third edge case in which `0x5B` is part of PUSHN instruction and hence
// not a valid opcode to jump to
//
// Remove ignore once its handled
#[test]
#[available_gas(20000000)]
#[ignore]
fn test_exec_jump_inside_pushn() {
    // Given
    let bytecode: Span<u8> = array![0x60, 0x5B, 0x60, 0x00].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let counter = 0x01;
    machine.stack.push(counter);

    // When
    let result = machine.exec_jump();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::JumpError(INVALID_DESTINATION), 'invalid jump dest');
}

#[test]
#[available_gas(20000000)]
fn test_exec_jumpi_valid_non_zero_1() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let b = 0x1;
    machine.stack.push(b);
    let counter = 0x03;
    machine.stack.push(counter);
    let old_pc = machine.pc();

    // When
    machine.exec_jumpi();

    // Then
    let pc = machine.pc();
    assert(pc == 0x03, 'PC should be JUMPDEST');
}

#[test]
#[available_gas(20000000)]
fn test_exec_jumpi_valid_non_zero_2() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let b = 0x69;
    machine.stack.push(b);
    let counter = 0x03;
    machine.stack.push(counter);
    let old_pc = machine.pc();

    // When
    machine.exec_jumpi();

    // Then
    let pc = machine.pc();
    assert(pc == 0x03, 'PC should be JUMPDEST');
}

#[test]
#[available_gas(20000000)]
fn test_exec_jumpi_valid_zero() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let b = 0x0;
    machine.stack.push(b);
    let counter = 0x03;
    machine.stack.push(counter);
    let old_pc = machine.pc();

    // When
    machine.exec_jumpi();

    // Then
    let pc = machine.pc();
    // ideally we should assert that it incremented, but incrementing is done by `decode_and_execute`
    // so we can assume that will be done
    assert(pc == old_pc, 'PC should be same');
}

#[test]
#[available_gas(20000000)]
fn test_exec_jumpi_invalid_non_zero() {
    // Given
    let bytecode: Span<u8> = array![0x60, 0x5B, 0x60, 0x00].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let b = 0x69;
    machine.stack.push(b);
    let counter = 0x69;
    machine.stack.push(counter);

    // When
    let result = machine.exec_jumpi();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::JumpError(INVALID_DESTINATION), 'invalid jump dest');
}


#[test]
#[available_gas(20000000)]
fn test_exec_jumpi_invalid_zero() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let b = 0x0;
    machine.stack.push(b);
    let counter = 0x69;
    machine.stack.push(counter);
    let old_pc = machine.pc();

    // When
    machine.exec_jumpi();

    // Then
    let pc = machine.pc();
    // ideally we should assert that it incremented, but incrementing is done by `decode_and_execut`
    // so we can assume that will be done
    assert(pc == old_pc, 'PC should be same');
}

// TODO: This is third edge case in which `0x5B` is part of PUSHN instruction and hence
// not a valid opcode to jump to
//
// Remove ignore once its handled
#[test]
#[available_gas(20000000)]
#[ignore]
fn test_exec_jumpi_inside_pushn() {
    // Given
    let bytecode: Span<u8> = array![0x60, 0x5B, 0x60, 0x00].span();
    let mut machine = setup_machine_with_bytecode(bytecode);
    let b = 0x00;
    machine.stack.push(b);
    let counter = 0x01;
    machine.stack.push(counter);

    // When
    let result = machine.exec_jumpi();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::JumpError(INVALID_DESTINATION), 'invalid jump dest');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sload_from_state() {
    // Given
    let mut machine = setup_machine();
    let key: u256 = 0x100000000000000000000000000000001;
    let value = 0x02;
    // `evm_address` must match the one used to instantiate the machine
    machine.state.write_state(machine.address().evm, key, value);

    machine.stack.push(key.into());

    // When
    let result = machine.exec_sload();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == value, 'sload failed');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sload_from_storage() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let mut machine = setup_machine();
    let mut ca = ContractAccountTrait::deploy(machine.address().evm, array![].span()).unwrap();
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    ca.set_storage_at(key, value);

    machine.stack.push(key.into());

    // When
    let result = machine.exec_sload();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == value, 'sload failed');
}

#[test]
#[available_gas(2000000)]
fn test_exec_sstore_from_state() {
    // Given
    let mut machine = setup_machine();
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    machine.stack.push(value);
    machine.stack.push(key);

    // When
    let result = machine.exec_sstore();

    // Then
    assert(machine.state.read_state(evm_address(), key).unwrap() == value, 'wrong value in state')
}
#[test]
#[available_gas(2000000)]
fn test_exec_sstore_static_call() {
    // Given
    let mut machine = setup_static_machine();
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    machine.stack.push(value);
    machine.stack.push(key);
    let storage_address = compute_storage_address(key);

    // When
    let result = machine.exec_sstore();

    // Then
    assert(result.is_err(), 'should have errored');
    assert(
        result.unwrap_err() == EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT),
        'wrong error variant'
    );
}

#[test]
#[available_gas(200000000)]
fn test_exec_sstore_finalized() {
    // Given
    // Setting the contract address is required so that `get_contract_address` in
    // `CA::deploy` returns the kakarot address
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let mut machine = setup_machine();
    // Deploys the contract account to be able to commit storage changes.
    let ca = ContractAccountTrait::deploy(machine.address().evm, array![].span()).unwrap();
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    machine.stack.push(value);
    machine.stack.push(key);

    // When
    let result = machine.exec_sstore();
    machine.state.commit_context();
    machine.state.commit_storage();

    // Then
    assert(ca.storage_at(key).unwrap() == value, 'wrong value in journal')
}

#[test]
#[available_gas(20000000)]
fn test_gas_should_push_gas_limit_to_stack() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_gas().unwrap();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(result == machine.gas_limit().into(), 'stack top should be gas_limit');
}
