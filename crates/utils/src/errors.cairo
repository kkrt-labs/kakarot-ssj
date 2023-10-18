// LENGTH
const RLP_EMPTY_INPUT: felt252 = 'KKT: RlpEmptyInput';
const RLP_INPUT_TOO_SHORT: felt252 = 'KKT: RlpInputTooShort';

#[derive(Drop, Copy, PartialEq)]
enum RLPError {
    RlpEmptyInput: felt252,
    RlpInputTooShort: felt252,
}


impl RLPErrorIntoU256 of Into<RLPError, u256> {
    fn into(self: RLPError) -> u256 {
        match self {
            RLPError::RlpEmptyInput(error_message) => error_message.into(),
            RLPError::RlpInputTooShort(error_message) => error_message.into(),
        }
    }
}
