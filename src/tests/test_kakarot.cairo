use array::ArrayTrait;
use option::OptionTrait;
use traits::{Into, TryInto};
use kakarot::evm;
use kakarot::stack::StackTrait;
use kakarot::context::CallContext;
use kakarot::errors;


#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Kakarot: pc >= bytecode length',))]
fn nominal_case_empty_pc() {
    let bytecode = ArrayTrait::<u8>::new();
    let call_data = ArrayTrait::<u8>::new();
    let call_value = 0;

    // Create a call context.
    let call_context = CallContext {
        bytecode: bytecode.span(), call_data: call_data.span(), value: call_value,
    };
    // Execute the bytecode.
    let summary = evm::execute(call_context, 0.try_into().unwrap(), 0.try_into().unwrap(), 0, 0);
}
