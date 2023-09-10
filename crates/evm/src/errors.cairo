use result::{ResultTrait, Result};
use core::Into;

// STACK
const STACK_OVERFLOW: felt252 = 'Kakarot: StackOverflow';
const STACK_UNDERFLOW: felt252 = 'Kakarot: StackUnderflow';

// INSTRUCTIONS
const PC_OUT_OF_BOUNDS: felt252 = 'Kakarot: pc >= bytecode length';

// TYPE CONVERSION
const TYPE_CONVERSION_ERROR: felt252 = 'Kakarot: type conversion error';

// RETURNDATA
const RETURNDATA_OUT_OF_BOUNDS_ERROR: felt252 = 'Kakarot: ReturnDataOutOfBounds';

#[derive(Drop, Copy, PartialEq)]
enum EVMError {
    StackError: felt252,
    InvalidProgramCounter: felt252,
    TypeConversionError: felt252,
    ReturnDataError: felt252
}


impl EVMErrorIntoU256 of Into<EVMError, u256> {
    fn into(self: EVMError) -> u256 {
        match self {
            EVMError::StackError(error_message) => error_message.into(),
            EVMError::InvalidProgramCounter(error_message) => error_message.into(),
            EVMError::TypeConversionError(error_message) => error_message.into(),
            EVMError::ReturnDataError(error_message) => error_message.into(),
        }
    }
}
