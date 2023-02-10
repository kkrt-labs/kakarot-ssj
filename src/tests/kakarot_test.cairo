// Core lib imports
use array::ArrayTrait;
// Internal imports
use kakarot::context::CallContext;
use kakarot::evm;

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
