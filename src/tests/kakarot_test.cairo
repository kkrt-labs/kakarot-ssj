// Core lib imports
use array::ArrayTrait;
use option::OptionTrait;
// Internal imports
use kakarot::context::CallContext;
use kakarot::evm;
use kakarot::stack::StackTrait;

#[test]
fn nominal_case() {
    let bytecode = ArrayTrait::<u8>::new();
    let call_data = ArrayTrait::<u8>::new();
    let call_value = 0;
    // Create a call context.
    let call_context = CallContext {
        bytecode: bytecode, call_data: call_data, value: call_value, 
    };
    // Execute the bytecode.
    let summary = evm::execute(call_context);
}


#[test]
fn stack_should_increment_len_on_push() {
    // Given
    let u256_val = integer::u256_from_felt(2);
    let mut stack = kakarot::stack::StackImpl::new();

    // When
    stack.push(u256_val);

    // Then
    let stack_len = stack.len();

    assert(stack_len == 1_u32, 1);
}

#[test]
fn stack_should_pop_pushed_value() {
    // Given
    let u256_val = integer::u256_from_felt(2);
    let mut stack = kakarot::stack::StackImpl::new();

    // When
    stack.push(u256_val);

    // Then
    let unwrapped_val = stack.pop().unwrap();

    assert(unwrapped_val == u256_val, 1);
}

#[test]
fn stack_should_peek_pushed_n_value() {
    // Given
    let u256_val1 = integer::u256_from_felt(1);
    let u256_val0 = integer::u256_from_felt(2);

    let mut stack = kakarot::stack::StackImpl::new();

    // When
    stack.push(u256_val1);
    stack.push(u256_val0);
    // Then
    let unwrapped_val = stack.peek(0_u32).unwrap();
    assert(*unwrapped_val == u256_val0, 1);
}
