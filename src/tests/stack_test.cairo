// Core lib imports
use array::ArrayTrait;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use dict::Felt252DictTrait;

// Internal imports
use kakarot::stack::StackTrait;

const U32_MAX: u32 = 4294967295_u32;

#[test]
#[available_gas(2000000)]
fn stack_new_test() {
    let mut stack = StackTrait::new();
    let result_len = stack.len();
    assert(result_len == 0_usize, 'stack length should be 0');
}

#[test]
#[available_gas(2000000)]
fn stack_is_empty_test() {
    let mut stack = StackTrait::new();
    let result = stack.is_empty();
    assert(result == true, 'stack should be empty');
}

#[test]
#[available_gas(2000000)]
fn stack_push_test() {
    let mut stack = StackTrait::new();
    let val_1: u256 = 1.into();
    let val_2: u256 = 1.into();

    stack.push(val_1);
    stack.push(val_2);
    let result_len = stack.len();
    let result_is_empty = stack.is_empty();
    let low = stack.items.get(0);
    let high = stack.items.get(1);
    let stack_val_1 = u256 { low: low, high: high };
    assert(result_is_empty == false, 'must not be empty');
    assert(result_len == 2_usize, 'len should be 2');
    assert(stack_val_1 == val_1, 'wrong result');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('u32_mul Overflow', ))]
fn stack_push_u32_max_test() {
    let mut stack = StackTrait::new();
    stack.len = U32_MAX;
    let val_1: u256 = 1.into();
    stack.push(val_1);
}

#[test]
#[available_gas(2000000)]
fn stack_peek_test() {
    let mut stack = StackTrait::new();
    let val_1: u256 = 1.into();
    let val_2: u256 = 1.into();
    stack.push(val_1);
    stack.push(val_2);
    let last_item = stack.peek().unwrap();
    assert(last_item == val_2, 'wrong result');
}

#[test]
#[available_gas(2000000)]
fn stack_peek_empty_test() {
    let mut stack = StackTrait::new();
    let result = stack.peek();
    assert(result.is_none(), 'should return None');
}

#[test]
#[available_gas(2000000)]
fn stack_pop_test() {
    let mut stack = StackTrait::new();
    let val_1: u256 = 1.into();
    let val_2: u256 = 1.into();

    stack.push(val_1);
    stack.push(val_2);
    let result = stack.pop().unwrap();
    let result_len = stack.len();
    assert(result_len == 1_usize, 'should remove item');
    assert(result == val_2, 'wrong result');
}

#[test]
#[available_gas(2000000)]
fn stack_pop_empty_test() {
    let mut stack = StackTrait::new();
    let result = stack.pop();
    assert(result.is_none(), 'should return None');
}

