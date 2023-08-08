use array::ArrayTrait;
use kakarot::evm;
use kakarot::stack::StackTrait;
use option::OptionTrait;
use kakarot::context::CallContext;


#[test]
#[available_gas(2000000)]
fn nominal_case_empty_pc() {
    let bytecode = ArrayTrait::<u8>::new();
    let call_data = ArrayTrait::<u8>::new();
    let call_value = 0;

    // Create a call context.
    let call_context = CallContext {
        bytecode: bytecode.span(), call_data: call_data.span(), value: call_value, 
    };
    // Execute the bytecode.
    let summary = evm::execute(call_context);
}

#[test]
#[available_gas(2000000)]
fn stack_should_increment_len_on_push() {
    // Given
    let u256_val = integer::u256_from_felt252(2);
    let mut stack = kakarot::stack::StackImpl::new();

    // When
    stack.push(u256_val);

    // Then
    let stack_len = stack.len();

    assert(stack_len == 1, 1);
}
