// LENGTH
const RLP_EMPTY_INPUT: felt252 = 'KKT: EmptyInput';
const RLP_INPUT_TOO_SHORT: felt252 = 'KKT: InputTooShort';

#[derive(Drop, Copy, PartialEq)]
enum RLPError {
    EmptyInput: felt252,
    InputTooShort: felt252,
}


impl RLPErrorIntoU256 of Into<RLPError, u256> {
    fn into(self: RLPError) -> u256 {
        match self {
            RLPError::EmptyInput(error_message) => error_message.into(),
            RLPError::InputTooShort(error_message) => error_message.into(),
        }
    }
}

#[generate_trait]
impl RLPErrorImpl<T> of RLPErrorTrait<T> {
    fn map_err(self: Result<T, RLPError>) -> Result<T, EthTransactionError> {
        match self {
            Result::Ok(val) => Result::Ok(val),
            Result::Err(error) => { Result::Err(EthTransactionError::RLPError(error)) }
        }
    }
}


#[derive(Drop, Copy, PartialEq)]
enum RLPHelpersError {
    NotAString,
    FailedParsingU128,
    FailedParsingU256,
    NotAList
}

#[generate_trait]
impl RLPHelpersErrorImpl<T> of RLPHelpersErrorTrait<T> {
    fn map_err(self: Result<T, RLPHelpersError>) -> Result<T, EthTransactionError> {
        match self {
            Result::Ok(val) => Result::Ok(val),
            Result::Err(error) => { Result::Err(EthTransactionError::RlpHelpersError(error)) }
        }
    }
}


#[derive(Drop, Copy, PartialEq)]
enum EthTransactionError {
    RLPError: RLPError,
    ExpectedRLPItemToBeList,
    ExpectedRLPItemToBeString,
    ChainIdIsIncoorect,
    AccountNonceIsIncorrect,
    RlpHelpersError: RLPHelpersError,
    Other: felt252
}
