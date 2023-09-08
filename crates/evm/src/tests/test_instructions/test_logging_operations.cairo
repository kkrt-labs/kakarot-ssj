use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait,
};
use evm::stack::StackTrait;
use evm::memory::MemoryTrait;
use evm::tests::test_utils::{setup_execution_context, setup_read_only_execution_context};
use evm::errors::{EVMError, STATE_MODIFICATION_ERROR};
use evm::instructions::LoggingOperationsTrait;
use integer::BoundedInt;

#[test]
#[available_gas(20000000)]
fn test_exec_log0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.memory.store(BoundedInt::<u256>::max(), 0);

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x0123456789ABCDEF);
    ctx.stack.push(0x1F);
    ctx.stack.push(0x00);

    // When
    let result = ctx.exec_log0();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 4, 'stack size should be 4');
    let mut events = ctx.events();
    assert(events.len() == 1, 'context should have one event');
    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 0, 'event should not have keys');
    assert(event.data.len() == 1, 'event should have one data');
    assert(
        *event.data[0] == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        'event data should be max_u248'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_log1() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.memory.store(BoundedInt::<u256>::max(), 0);

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x0123456789ABCDEF);
    ctx.stack.push(0x20);
    ctx.stack.push(0x00);

    // When
    let result = ctx.exec_log1();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 3, 'stack size should be 3');
    let mut events = ctx.events();
    assert(events.len() == 1, 'context should have one event');
    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 1, 'event should have one key');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');
    assert(event.data.len() == 2, 'event should have one data');
    assert(
        *event.data[0] == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        'event data0 should be max_u248'
    );
    assert(*event.data[1] == 0xff, 'event data1 should be 0xFF');
}

#[test]
#[available_gas(20000000)]
fn test_exec_log1_read_only_context() {
    // Given
    let mut ctx = setup_read_only_execution_context();

    ctx.memory.store(BoundedInt::<u256>::max(), 0);

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x0123456789ABCDEF);
    ctx.stack.push(0x20);
    ctx.stack.push(0x00);

    // When
    let result = ctx.exec_log1();

    // Then
    assert(result.is_err(), 'should have returned an error');
    assert(
        result.unwrap_err() == EVMError::StateModificationError(STATE_MODIFICATION_ERROR),
        'err != StateModificationError'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_log2() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.memory.store(BoundedInt::<u256>::max(), 0);

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x0123456789ABCDEF);
    ctx.stack.push(0x05);
    ctx.stack.push(0x05);

    // When
    let result = ctx.exec_log2();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 2, 'stack size should be 2');
    let mut events = ctx.events();
    assert(events.len() == 1, 'context should have one event');
    let event = events.pop_front().unwrap();
    assert(event.keys.len() == 2, 'event should have two keys');
    assert(*event.keys[0] == 0x0123456789ABCDEF, 'event key is not correct');
    assert(*event.keys[1] == BoundedInt::<u256>::max(), 'event key is not correct');
    assert(event.data.len() == 1, 'event should have one data');
    assert(*event.data[0] == 0xFFFFFFFFFF, 'event data is not correct');
}

#[test]
#[available_gas(20000000)]
fn test_exec_log3_and_log4() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.memory.store(BoundedInt::<u256>::max(), 0);
    ctx.memory.store(0x0123456789ABCDEF000000000000000000000000000000000000000000000000, 0x20);

    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x0123456789ABCDEF);
    ctx.stack.push(0x0A);
    ctx.stack.push(0x20);
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(0x0123456789ABCDEF);
    ctx.stack.push(0x28);
    ctx.stack.push(0x00);

    // When
    let result = ctx.exec_log3();
    let result = ctx.exec_log4();

    // Then
    assert(result.is_ok(), 'should have succeeded');
    assert(ctx.stack.len() == 0, 'stack size should be 0');

    let mut events = ctx.events();
    assert(events.len() == 2, 'context should have 2 events');

    let event1 = events.pop_front().unwrap();
    assert(event1.keys.len() == 3, 'event1 should have 3 keys');
    assert(*event1.keys[0] == 0x0123456789ABCDEF, 'event1 key is not correct');
    assert(*event1.keys[1] == BoundedInt::<u256>::max(), 'event1 key is not correct');
    assert(*event1.keys[2] == 0x00, 'event1 key is not correct');

    assert(event1.data.len() == 2, 'event1 should have 2 datas');
    assert(
        *event1.data[0] == 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        'event1 data is not correct'
    );
    assert(*event1.data[1] == 0xff0123456789ABCDEF, 'event1 data is not correct');

    let event2 = events.pop_front().unwrap();
    assert(event2.keys.len() == 4, 'event2 should have 4 keys');
    assert(*event2.keys[0] == 0x0123456789ABCDEF, 'event2 key is not correct');
    assert(*event2.keys[1] == BoundedInt::<u256>::max(), 'event2 key is not correct');
    assert(*event2.keys[2] == 0x00, 'event2 key is not correct');
    assert(*event2.keys[3] == BoundedInt::<u256>::max(), 'event2 key is not correct');

    assert(event2.data.len() == 1, 'event2 should have one data');
    assert(*event2.data[0] == 0x0123456789ABCDEF0000, 'event2 data is not correct');
}
