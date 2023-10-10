// LENGTH
const RLP_INVALID_LENGTH: felt252 = 'KKT: RlpInvalidLength';

#[derive(Drop, Copy, PartialEq)]
enum RLPError {
    RlpInvalidLength: felt252,
}


impl RLPErrorIntoU256 of Into<RLPError, u256> {
    fn into(self: RLPError) -> u256 {
        match self {
            RLPError::RlpInvalidLength(error_message) => error_message.into(),
        }
    }
}
