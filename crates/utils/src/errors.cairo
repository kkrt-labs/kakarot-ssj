// LENGTH
pub const RLP_EMPTY_INPUT: felt252 = 'KKT: EmptyInput';
pub const RLP_INPUT_TOO_SHORT: felt252 = 'KKT: InputTooShort';

#[derive(Drop, Copy, PartialEq)]
pub enum RLPError {
    EmptyInput,
    InputTooShort,
    InvalidInput
}


pub impl RLPErrorIntoU256 of Into<RLPError, u256> {
    fn into(self: RLPError) -> u256 {
        match self {
            RLPError::EmptyInput => 'input is null'.into(),
            RLPError::InputTooShort => 'input too short'.into(),
            RLPError::InvalidInput => 'rlp input not conform'.into()
        }
    }
}

#[generate_trait]
pub impl RLPErrorImpl<T> of RLPErrorTrait<T> {
    fn map_err(self: Result<T, RLPError>) -> Result<T, EthTransactionError> {
        match self {
            Result::Ok(val) => Result::Ok(val),
            Result::Err(error) => { Result::Err(EthTransactionError::RLPError(error)) }
        }
    }
}


#[derive(Drop, Copy, PartialEq)]
pub enum RLPHelpersError {
    NotAString,
    FailedParsingU128,
    FailedParsingU256,
    FailedParsingAddress,
    FailedParsingAccessList,
    NotAList
}

#[generate_trait]
pub impl RLPHelpersErrorImpl<T> of RLPHelpersErrorTrait<T> {
    fn map_err(self: Result<T, RLPHelpersError>) -> Result<T, EthTransactionError> {
        match self {
            Result::Ok(val) => Result::Ok(val),
            Result::Err(error) => { Result::Err(EthTransactionError::RlpHelpersError(error)) }
        }
    }
}


#[derive(Drop, Copy, PartialEq)]
pub enum EthTransactionError {
    RLPError: RLPError,
    ExpectedRLPItemToBeList,
    ExpectedRLPItemToBeString,
    TransactionTypeError,
    RlpHelpersError: RLPHelpersError,
    // the usize represents the encountered length of payload
    TopLevelRlpListWrongLength: usize,
    // the usize represents the encountered length of payload
    LegacyTxWrongPayloadLength: usize,
    // the usize represents the encountered length of payload
    TypedTxWrongPayloadLength: usize,
    IncorrectChainId,
    IncorrectAccountNonce,
    Other: felt252
}
