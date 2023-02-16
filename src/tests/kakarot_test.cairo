// Core lib imports
use array::ArrayTrait;
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
fn failed_to_specialize0() {
     let u256_val = integer::u256_from_felt(2); 

     let mut stack = kakarot::stack::StackImpl::new();

     stack.push(u256_val);

     let stack_len = stack.len();
      
     assert(stack_len == stack_len, 1);

}

#[test]
fn failed_to_specialize1() {
    let u256_val = integer::u256_from_felt(2); 

    let mut stack = kakarot::stack::StackImpl::new();

    stack.push(u256_val);

    let maybe_val = stack.pop();
    match maybe_val {
            Option::Some(x) => {
            assert(x == u256_val, 1);
            },
            Option::None(()) => {
            
            },
     }

     
 
}
