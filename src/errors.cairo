use result::{ResultTrait, Result};

// STACK
const STACK_OVERFLOW: felt252 = 'Kakarot: StackOverflow';
const STACK_UNDERFLOW: felt252 = 'Kakarot: StackUnderflow';

// INSTRUCTIONS
const PC_OUT_OF_BOUNDS: felt252 = 'Kakarot: pc >= bytecode length';

#[derive(Drop, Copy, PartialEq)]
enum EVMError {
    StackError: felt252, 
}

