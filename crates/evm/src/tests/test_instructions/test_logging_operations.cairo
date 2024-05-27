use core::integer::BoundedInt;
use core::result::ResultTrait;
use evm::errors::{EVMError, EVMErrorTrait, TYPE_CONVERSION_ERROR};
use evm::instructions::LoggingOperationsTrait;
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{VMBuilderTrait};
use utils::helpers::u256_to_bytes_array;

#[test]
fn test_exec_log0() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(0x1F).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_log0();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 0, 'stack should be empty');

    let mut events = vm.env.state.events;
    assert(events.len() == 1, 'context should have one event');

    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 0, 'event should not have keys');

    assert(event.data.len() == 31, 'event should have 31 bytes');
    let data_expected = u256_to_bytes_array(BoundedInt::<u256>::max()).span().slice(0, 31);
    assert(event.data.span() == data_expected, 'event data are incorrect');
}

#[test]
fn test_exec_log1() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x20).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_log1();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 0, 'stack should be empty');

    let mut events = vm.env.state.events;
    assert(events.len() == 1, 'context should have one event');

    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 1, 'event should have one key');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');

    assert(event.data.len() == 32, 'event should have 32 bytes');
    let data_expected = u256_to_bytes_array(BoundedInt::<u256>::max()).span().slice(0, 32);
    assert(event.data.span() == data_expected, 'event data are incorrect');
}

#[test]
fn test_exec_log2() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x05).expect('push failed');
    vm.stack.push(0x05).expect('push failed');

    // When
    let result = vm.exec_log2();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 0, 'stack should be empty');

    let mut events = vm.env.state.events;
    assert(events.len() == 1, 'context should have one event');

    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 2, 'event should have two keys');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');
    assert(*event.keys[1] == BoundedInt::<u256>::max(), 'event key is not correct');

    assert(event.data.len() == 5, 'event should have 5 bytes');
    let data_expected = u256_to_bytes_array(BoundedInt::<u256>::max()).span().slice(0, 5);
    assert(event.data.span() == data_expected, 'event data are incorrect');
}

#[test]
fn test_exec_log3() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);
    vm.memory.store(0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20);

    vm.stack.push(0x00).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x28).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_log3();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 0, 'stack should be empty');

    let mut events = vm.env.state.events;
    assert(events.len() == 1, 'context should have one event');

    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 3, 'event should have 3 keys');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');
    assert(*event.keys[1] == BoundedInt::<u256>::max(), 'event key is not correct');
    assert(*event.keys[2] == 0x00, 'event key is not correct');

    assert(event.data.len() == 40, 'event should have 40 bytes');
    let data_expected = u256_to_bytes_array(BoundedInt::<u256>::max()).span();
    assert(event.data.span().slice(0, 32) == data_expected, 'event data are incorrect');
    let data_expected = array![0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF].span();
    assert(event.data.span().slice(32, 8) == data_expected, 'event data are incorrect');
}

#[test]
fn test_exec_log4() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);
    vm.memory.store(0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20);

    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x00).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x0A).expect('push failed');
    vm.stack.push(0x20).expect('push failed');

    // When
    let result = vm.exec_log4();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 0, 'stack should be empty');

    let mut events = vm.env.state.events;
    assert(events.len() == 1, 'context should have one event');

    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 4, 'event should have 4 keys');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');
    assert(*event.keys[1] == BoundedInt::<u256>::max(), 'event key is not correct');
    assert(*event.keys[2] == 0x00, 'event key is not correct');
    assert(*event.keys[3] == BoundedInt::<u256>::max(), 'event key is not correct');

    assert(event.data.len() == 10, 'event should have 10 bytes');
    let data_expected = array![0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x00, 0x00].span();
    assert(event.data.span() == data_expected, 'event data are incorrect');
}

#[test]
fn test_exec_log1_read_only_context() {
    // Given
    let mut vm = VMBuilderTrait::new().with_read_only().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x20).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_log1();

    // Then
    assert(result.is_err(), 'should have returned an error');
    assert(result.unwrap_err() == EVMError::WriteInStaticContext, 'err != WriteInStaticContext');
}

#[test]
fn test_exec_log1_size_0_offset_0() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x00).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_log1();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(vm.stack.len() == 0, 'stack should be empty');

    let mut events = vm.env.state.events;
    assert(events.len() == 1, 'context should have one event');

    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 1, 'event should have one key');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');

    assert(event.data.len() == 0, 'event data should be empty');
}

#[test]
fn test_exec_log1_size_too_big() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    let result = vm.exec_log1();

    // Then
    assert(result.is_err(), 'should return an error');
    assert(
        result.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'err != TypeConversionError'
    );
}

#[test]
fn test_exec_log1_offset_too_big() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);

    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x20).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');

    // When
    let result = vm.exec_log1();

    // Then
    assert(result.is_err(), 'should return an error');
    assert(
        result.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'err != TypeConversionError'
    );
}

#[test]
fn test_exec_log_multiple_events() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm.memory.store(BoundedInt::<u256>::max(), 0);
    vm.memory.store(0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20);

    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x00).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x0A).expect('push failed');
    vm.stack.push(0x20).expect('push failed');
    vm.stack.push(0x00).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).expect('push failed');
    vm.stack.push(0x0123456789ABCDEF).expect('push failed');
    vm.stack.push(0x28).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    vm.exec_log3().expect('exec_log3 failed');
    vm.exec_log4().expect('exec_log4 failed');

    // Then
    assert(vm.stack.len() == 0, 'stack size should be 0');

    let mut events = vm.env.state.events;
    assert(events.len() == 2, 'context should have 2 events');

    let event1 = events.pop_front().unwrap();
    assert(event1.keys.len() == 3, 'event1 should have 3 keys');
    assert(*event1.keys[0] == 0x0123456789ABCDEF, 'event1 key is not correct');
    assert(*event1.keys[1] == BoundedInt::<u256>::max(), 'event1 key is not correct');
    assert(*event1.keys[2] == 0x00, 'event1 key is not correct');

    assert(event1.data.len() == 40, 'event1 should have 40 bytes');
    let data_expected = u256_to_bytes_array(BoundedInt::<u256>::max()).span();
    assert(event1.data.span().slice(0, 32) == data_expected, 'event1 data are incorrect');
    let data_expected = array![0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF].span();
    assert(event1.data.span().slice(32, 8) == data_expected, 'event1 data are incorrect');

    let event2 = events.pop_front().unwrap();
    assert(event2.keys.len() == 4, 'event2 should have 4 keys');
    assert(*event2.keys[0] == 0x0123456789ABCDEF, 'event2 key is not correct');
    assert(*event2.keys[1] == BoundedInt::<u256>::max(), 'event2 key is not correct');
    assert(*event2.keys[2] == 0x00, 'event2 key is not correct');
    assert(*event2.keys[3] == BoundedInt::<u256>::max(), 'event2 key is not correct');

    assert(event2.data.len() == 10, 'event2 should have 10 bytes');
    let data_expected = array![0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x00, 0x00].span();
    assert(event2.data.span() == data_expected, 'event2 data are incorrect');
}
