// STACK
const STACK_OVERFLOW: felt252 = 'KKT: StackOverflow';
const STACK_UNDERFLOW: felt252 = 'KKT: StackUnderflow';

// INSTRUCTIONS
const PC_OUT_OF_BOUNDS: felt252 = 'KKT: pc >= bytecode length';

// TYPE CONVERSION
const TYPE_CONVERSION_ERROR: felt252 = 'KKT: type conversion error';

// RETURNDATA
const RETURNDATA_OUT_OF_BOUNDS_ERROR: felt252 = 'KKT: ReturnDataOutOfBounds';

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
