// STACK
const STACK_OVERFLOW: felt252 = 'KKT: StackOverflow';
const STACK_UNDERFLOW: felt252 = 'KKT: StackUnderflow';

// INSTRUCTIONS
const PC_OUT_OF_BOUNDS: felt252 = 'KKT: pc >= bytecode length';

// TYPE CONVERSION
const TYPE_CONVERSION_ERROR: felt252 = 'KKT: type conversion error';

// RETURNDATA
const RETURNDATA_OUT_OF_BOUNDS_ERROR: felt252 = 'KKT: ReturnDataOutOfBounds';

// JUMP
const INVALID_DESTINATION: felt252 = 'KKT: invalid JUMP destination';

// EVM STATE
const WRITE_IN_STATIC_CONTEXT: felt252 = 'KKT: WriteInStaticContext';

// STARKNET_SYSCALLS
const READ_SYSCALL_FAILED: felt252 = 'KKT: read syscall failed';

#[derive(Drop, Copy, PartialEq)]
enum EVMErrorEnum {
    StackError: felt252,
    InvalidProgramCounter: felt252,
    ReturnDataError: felt252,
    JumpError: felt252,
    NotImplemented,
    UnknownOpcode: u8,
    WriteInStaticContext: felt252
}

#[derive(Drop, Copy, PartialEq)]
enum InternalErrorEnum {
    TypeConversionError: felt252,
    SyscallFailed: felt252
}

#[derive(Drop, Copy, PartialEq)]
enum Errors {
    EVMError: EVMErrorEnum,
    InternalError: InternalErrorEnum
}

impl ErrorsIntoU256 of Into<Errors, u256> {
    fn into(self: Errors) -> u256 {
        match self {
            Errors::EVMError(error) => error.into(),
            Errors::InternalError(error) => error.into(),
        }
    }
}

impl EVMErrorEnumIntoU256 of Into<EVMErrorEnum, u256> {
    fn into(self: EVMErrorEnum) -> u256 {
        match self {
            EVMErrorEnum::StackError(error_message) => error_message.into(),
            EVMErrorEnum::InvalidProgramCounter(error_message) => error_message.into(),
            EVMErrorEnum::ReturnDataError(error_message) => error_message.into(),
            EVMErrorEnum::JumpError(error_message) => error_message.into(),
            EVMErrorEnum::NotImplemented => 'NotImplemented'.into(),
            // TODO: refactor with dynamic strings once supported
            EVMErrorEnum::UnknownOpcode => 'UnknownOpcode'.into(),
            EVMErrorEnum::WriteInStaticContext(error_message) => error_message.into(),
        }
    }
}

impl InternalErrorEnumIntoU256 of Into<InternalErrorEnum, u256> {
    fn into(self: InternalErrorEnum) -> u256 {
        match self {
            InternalErrorEnum::TypeConversionError(error_message) => error_message.into(),
            InternalErrorEnum::SyscallFailed(error_message) => error_message.into(),
        }
    }
}
