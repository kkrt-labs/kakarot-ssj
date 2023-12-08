use contracts::tests::test_utils::{setup_contracts_for_testing, deploy_contract_account};
use core::result::ResultTrait;
use evm::errors::{EVMError, INVALID_DESTINATION};
use evm::instructions::{MemoryOperationTrait, EnvironmentInformationTrait};
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Account, AccountType};
use evm::stack::StackTrait;
use evm::state::{StateTrait, StateInternalTrait, compute_storage_address};
use evm::tests::test_utils::{evm_address, VMBuilderTrait};
use integer::BoundedInt;
use starknet::get_contract_address;

#[test]
fn test_pc_basic() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    vm.exec_pc().expect('exec_pc failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == 0, 'PC should be 0');
}


#[test]
fn test_pc_gets_updated_properly_1() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    vm.set_pc(9000);
    vm.exec_pc().expect('exec_pc failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == 9000, 'updating PC failed');
}

// 0x51 - MLOAD

#[test]
fn test_exec_mload_should_load_a_value_from_memory() {
    assert_mload(0x1, 0, 0x1, 32);
}

#[test]
fn test_exec_mload_should_load_a_value_from_memory_with_memory_expansion() {
    assert_mload(0x1, 16, 0x100000000000000000000000000000000, 64);
}

#[test]
fn test_exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize() {
    assert_mload(0x1, 684, 0x0, 736);
}

fn assert_mload(value: u256, offset: u256, expected_value: u256, expected_memory_size: u32) {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.memory.store(value, 0);

    vm.stack.push(offset).expect('push failed');

    // When
    vm.exec_mload().expect('exec_mload failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == expected_value, 'mload failed');
    assert(vm.memory.size() == expected_memory_size, 'memory size error');
}

#[test]
fn test_exec_pop_should_pop_an_item_from_stack() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0x01).expect('push failed');
    vm.stack.push(0x02).expect('push failed');

    // When
    let result = vm.exec_pop();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0x01, 'stack peek should return 0x01');
}

#[test]
fn test_exec_pop_should_stack_underflow() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    let result = vm.exec_pop();

    // Then
    assert(result.is_err(), 'should return Err ');
    assert!(result.unwrap_err() == EVMError::StackUnderflow, "should return StackUnderflow");
}

#[test]
fn test_exec_mstore_should_store_max_uint256_offset_0() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = vm.memory.load(0);
    assert(stored == BoundedInt::<u256>::max(), 'should have stored max_uint256');
}

#[test]
fn test_exec_mstore_should_store_max_uint256_offset_1() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x01).expect('push failed');

    // When
    let result = vm.exec_mstore();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 64, 'memory should be 64 bytes long');
    let stored = vm.memory.load(1);
    assert(stored == BoundedInt::<u256>::max(), 'should have stored max_uint256');
}

#[test]
fn test_exec_mstore8_should_store_uint8_offset_31() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0xAB).expect('push failed');
    vm.stack.push(31).expect('push failed');

    // When
    let result = vm.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = vm.memory.load(0);
    assert(stored == 0xAB, 'mstore8 failed');
}

#[test]
fn test_exec_mstore8_should_store_uint8_offset_30() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0xAB).expect('push failed');
    vm.stack.push(30).expect('push failed');

    // When
    let result = vm.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = vm.memory.load(0);
    assert(stored == 0xAB00, 'mstore8 failed');
}

#[test]
fn test_exec_mstore8_should_store_uint8_offset_31_then_uint8_offset_30() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0xAB).expect('push failed');
    vm.stack.push(30).expect('push failed');
    vm.stack.push(0xCD).expect('push failed');
    vm.stack.push(31).expect('push failed');

    // When
    let result1 = vm.exec_mstore8();
    let result2 = vm.exec_mstore8();

    // Then
    assert(result1.is_ok() && result2.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = vm.memory.load(0);
    assert(stored == 0xABCD, 'mstore8 failed');
}

#[test]
fn test_exec_mstore8_should_store_last_uint8_offset_31() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0x123456789ABCDEF).expect('push failed');
    vm.stack.push(31).expect('push failed');

    // When
    let result = vm.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 32, 'memory should be 32 bytes long');
    let stored = vm.memory.load(0);
    assert(stored == 0xEF, 'mstore8 failed');
}


#[test]
fn test_exec_mstore8_should_store_last_uint8_offset_63() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.stack.push(0x123456789ABCDEF).expect('push failed');
    vm.stack.push(63).expect('push failed');

    // When
    let result = vm.exec_mstore8();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.memory.size() == 64, 'memory should be 64 bytes long');
    let stored = vm.memory.load(32);
    assert(stored == 0xEF, 'mstore8 failed');
}

#[test]
fn test_msize_initial() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    let result = vm.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == 0, 'initial memory size should be 0');
}

#[test]
fn test_exec_msize_store_max_offset_0() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.memory.store(BoundedInt::<u256>::max(), 0x00);

    // When
    let result = vm.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == 32, 'should 32 bytes after MSTORE');
}

#[test]
fn test_exec_msize_store_max_offset_1() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.memory.store(BoundedInt::<u256>::max(), 0x01);

    // When
    let result = vm.exec_msize();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == 64, 'should 64 bytes after MSTORE');
}

#[test]
fn test_exec_jump_valid() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
    vm.init_valid_jump_destinations();

    let counter = 0x03;
    vm.stack.push(counter).expect('push failed');

    // When
    vm.exec_jump().expect('exec_jump failed');

    // Then
    let pc = vm.pc();
    assert(pc == 0x03, 'PC should be JUMPDEST');
}


#[test]
fn test_exec_jump_invalid() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let counter = 0x02;
    vm.stack.push(counter).expect('push failed');

    // When
    let result = vm.exec_jump();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::InvalidJump, 'invalid jump dest');
}

#[test]
fn test_exec_jump_out_of_bounds() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let counter = 0xFF;
    vm.stack.push(counter).expect('push failed');

    // When
    let result = vm.exec_jump();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::InvalidJump, 'invalid jump dest');
}

// TODO: This is third edge case in which `0x5B` is part of PUSHN instruction and hence
// not a valid opcode to jump to
#[test]
fn test_exec_jump_inside_pushn() {
    // Given
    let bytecode: Span<u8> = array![0x60, 0x5B, 0x60, 0x00].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let counter = 0x01;
    vm.stack.push(counter).expect('push failed');

    // When
    let result = vm.exec_jump();

    // Then
    assert(result.is_err(), 'exec_jump should throw error');
    assert(result.unwrap_err() == EVMError::InvalidJump, 'jump dest should be invalid');
}

#[test]
fn test_exec_jumpi_valid_non_zero_1() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
    vm.init_valid_jump_destinations();

    let b = 0x1;
    vm.stack.push(b).expect('push failed');
    let counter = 0x03;
    vm.stack.push(counter).expect('push failed');

    // When
    vm.exec_jumpi().expect('exec_jumpi failed');

    // Then
    let pc = vm.pc();
    assert(pc == 0x03, 'PC should be JUMPDEST');
}

#[test]
fn test_exec_jumpi_valid_non_zero_2() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
    vm.init_valid_jump_destinations();

    let b = 0x69;
    vm.stack.push(b).expect('push failed');
    let counter = 0x03;
    vm.stack.push(counter).expect('push failed');

    // When
    vm.exec_jumpi().expect('exec_jumpi failed');

    // Then
    let pc = vm.pc();
    assert(pc == 0x03, 'PC should be JUMPDEST');
}

#[test]
fn test_exec_jumpi_valid_zero() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let b = 0x0;
    vm.stack.push(b).expect('push failed');
    let counter = 0x03;
    vm.stack.push(counter).expect('push failed');
    let old_pc = vm.pc();

    // When
    vm.exec_jumpi().expect('exec_jumpi failed');

    // Then
    let pc = vm.pc();
    // ideally we should assert that it incremented, but incrementing is done by `decode_and_execute`
    // so we can assume that will be done
    assert(pc == old_pc, 'PC should be same');
}

#[test]
fn test_exec_jumpi_invalid_non_zero() {
    // Given
    let bytecode: Span<u8> = array![0x60, 0x5B, 0x60, 0x00].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let b = 0x69;
    vm.stack.push(b).expect('push failed');
    let counter = 0x69;
    vm.stack.push(counter).expect('push failed');

    // When
    let result = vm.exec_jumpi();

    // Then
    assert(result.is_err(), 'invalid jump dest');
    assert(result.unwrap_err() == EVMError::InvalidJump, 'invalid jump dest');
}


#[test]
fn test_exec_jumpi_invalid_zero() {
    // Given
    let bytecode: Span<u8> = array![0x01, 0x02, 0x03, 0x5B, 0x04, 0x05].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let b = 0x0;
    vm.stack.push(b).expect('push failed');
    let counter = 0x69;
    vm.stack.push(counter).expect('push failed');
    let old_pc = vm.pc();

    // When
    vm.exec_jumpi().expect('exec_jumpi failed');

    // Then
    let pc = vm.pc();
    // ideally we should assert that it incremented, but incrementing is done by `decode_and_execute`
    // so we can assume that will be done
    assert(pc == old_pc, 'PC should be same');
}

// TODO: This is third edge case in which `0x5B` is part of PUSHN instruction and hence
// not a valid opcode to jump to
//
// Remove ignore once its handled
#[test]
#[should_panic(expected: ('exec_jump should throw error',))]
fn test_exec_jumpi_inside_pushn() {
    // Given
    let bytecode: Span<u8> = array![0x60, 0x5B, 0x60, 0x00].span();

    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

    let b = 0x00;
    vm.stack.push(b).expect('push failed');
    let counter = 0x01;
    vm.stack.push(counter).expect('push failed');

    // When
    let result = vm.exec_jumpi();

    // Then
    assert(result.is_err(), 'exec_jump should throw error');
    assert(result.unwrap_err() == EVMError::InvalidJump, 'jump dest should be invalid');
}

#[test]
fn test_exec_sload_from_state() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    let key: u256 = 0x100000000000000000000000000000001;
    let value = 0x02;
    // `evm_address` must match the one used to instantiate the vm
    vm.env.state.write_state(vm.message().target.evm, key, value);

    vm.stack.push(key.into()).expect('push failed');

    // When
    let result = vm.exec_sload();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == value, 'sload failed');
}

#[test]
fn test_exec_sload_from_storage() {
    // Given
    setup_contracts_for_testing();
    let mut vm = VMBuilderTrait::new_with_presets().build();
    let mut ca_address = deploy_contract_account(vm.message().target.evm, array![].span());
    let account = Account {
        account_type: AccountType::ContractAccount,
        address: ca_address,
        code: array![0xab, 0xcd, 0xef].span(),
        nonce: 1,
        balance: 0,
        selfdestruct: false
    };
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    account.store_storage(key, value).expect('store failed');

    vm.stack.push(key.into()).expect('push failed');

    // When
    let result = vm.exec_sload();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.pop().unwrap() == value, 'sload failed');
}

#[test]
fn test_exec_sstore_from_state() {
    // Given
    setup_contracts_for_testing();
    let mut vm = VMBuilderTrait::new_with_presets().build();
    let mut ca_address = deploy_contract_account(vm.message().target.evm, array![].span());
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    vm.stack.push(value).expect('push failed');
    vm.stack.push(key).expect('push failed');

    // When
    vm.exec_sstore().expect('exec sstore failed');

    // Then
    assert(vm.env.state.read_state(evm_address(), key).unwrap() == value, 'wrong value in state')
}
#[test]
fn test_exec_sstore_static_call() {
    // Given
    setup_contracts_for_testing();
    let mut vm = VMBuilderTrait::new_with_presets().with_read_only().build();
    let mut ca_address = deploy_contract_account(vm.message().target.evm, array![].span());
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    vm.stack.push(value).expect('push failed');
    vm.stack.push(key).expect('push failed');

    // When
    let result = vm.exec_sstore();

    // Then
    assert(result.is_err(), 'should have errored');
    assert(result.unwrap_err() == EVMError::WriteInStaticContext, 'wrong error variant');
}

#[test]
fn test_exec_sstore_finalized() {
    // Given
    // Setting the contract address is required so that `get_contract_address` in
    // `CA::deploy` returns the kakarot address
    setup_contracts_for_testing();
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // Deploys the contract account to be able to commit storage changes.
    let ca_address = deploy_contract_account(vm.message().target.evm, array![].span());
    let account = Account {
        account_type: AccountType::ContractAccount,
        address: ca_address,
        code: array![].span(),
        nonce: 1,
        balance: 0,
        selfdestruct: false
    };
    let key: u256 = 0x100000000000000000000000000000001;
    let value: u256 = 0xABDE1E11A5;
    vm.stack.push(value).expect('push failed');
    vm.stack.push(key).expect('push failed');

    // When
    vm.exec_sstore().expect('exec_sstore failed');
    vm.env.state.commit_storage().expect('commit storage failed');

    // Then
    assert(account.fetch_storage(key).unwrap() == value, 'wrong committed value')
}

#[test]
fn test_gas_should_push_gas_left_to_stack() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    vm.exec_gas().unwrap();

    // Then
    let result = vm.stack.peek().unwrap();
    assert(result == vm.gas_left().into(), 'stack top should be gas_limit');
}
