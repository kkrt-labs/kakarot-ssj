use result::{ResultTrait, Result};
use core::Into;

// STACK
const STACK_OVERFLOW: felt252 = 'Kakarot: StackOverflow';
const STACK_UNDERFLOW: felt252 = 'Kakarot: StackUnderflow';

// INSTRUCTIONS
const PC_OUT_OF_BOUNDS: felt252 = 'Kakarot: pc >= bytecode length';

#[derive(Drop, Copy, PartialEq)]
enum EVMError {
    StackError: felt252,
    InvalidProgramCounter: felt252,
}


impl EVMErrorIntoU256 of Into<EVMError, u256> {
    fn into(self: EVMError) -> u256 {
        match self {
            EVMError::StackError(error_message) => error_message.into(),
            EVMError::InvalidProgramCounter(error_message) => error_message.into(),
        }
    }
}
