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
const BLOCK_HASH_SYSCALL_FAILED: felt252 = 'KKT: block_hash syscall failed';
const WRITE_SYSCALL_FAILED: felt252 = 'KKT: write syscall failed';
const CONTRACT_SYSCALL_FAILED: felt252 = 'KKT: contract syscall failed';

// CALL
const CALL_GAS_GT_GAS_LIMIT: felt252 = 'KKT: call gas gt gas limit';

#[derive(Drop, Copy, PartialEq)]
enum EVMError {
    StackError: felt252,
    InvalidProgramCounter: felt252,
    TypeConversionError: felt252,
    ReturnDataError: felt252,
    JumpError: felt252,
    NotImplemented,
    UnknownOpcode: u8,
    SyscallFailed: felt252,
    WriteInStaticContext: felt252,
    InsufficientGas: felt252,
}


impl EVMErrorIntoU256 of Into<EVMError, u256> {
    fn into(self: EVMError) -> u256 {
        match self {
            EVMError::StackError(error_message) => error_message.into(),
            EVMError::InvalidProgramCounter(error_message) => error_message.into(),
            EVMError::TypeConversionError(error_message) => error_message.into(),
            EVMError::ReturnDataError(error_message) => error_message.into(),
            EVMError::JumpError(error_message) => error_message.into(),
            EVMError::NotImplemented => 'NotImplemented'.into(),
            // TODO: refactor with dynamic strings once supported
            EVMError::UnknownOpcode => 'UnknownOpcode'.into(),
            EVMError::SyscallFailed(error_message) => error_message.into(),
            EVMError::WriteInStaticContext(error_message) => error_message.into(),
            EVMError::InsufficientGas(error_message) => error_message.into(),
        }
    }
}
