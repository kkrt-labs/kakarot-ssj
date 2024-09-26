pub mod common;
pub mod eip1559;
pub mod eip2930;
pub mod legacy;
pub mod transaction;
pub mod tx_type;
use core::cmp::min;
use core::num::traits::CheckedAdd;
use core::option::OptionTrait;
use core::starknet::{EthAddress, secp256_trait::Signature,};
use crate::errors::{EthTransactionError, RLPErrorImpl};
use crate::traits::bytes::ByteArrayExt;

#[derive(Drop)]
pub struct TransactionMetadata {
    pub address: EthAddress,
    pub account_nonce: u64,
    pub chain_id: u64,
    pub signature: Signature,
}

/// Checks the effective gas price of a transaction as specfified in EIP-1559 with relevant
/// checks.
pub fn check_gas_fee(
    max_fee_per_gas: u128, max_priority_fee_per_gas: Option<u128>, block_base_fee: u128,
) -> Result<(), EthTransactionError> {
    let max_priority_fee_per_gas = max_priority_fee_per_gas.unwrap_or(0);

    if max_fee_per_gas < block_base_fee {
        // `base_fee_per_gas` is greater than the `max_fee_per_gas`
        return Result::Err(EthTransactionError::FeeCapTooLow);
    }
    if max_fee_per_gas < max_priority_fee_per_gas {
        // `max_priority_fee_per_gas` is greater than the `max_fee_per_gas`
        return Result::Err(EthTransactionError::TipAboveFeeCap);
    }

    Result::Ok(())
}

#[cfg(test)]
mod tests {
    use super::check_gas_fee;
    use utils::errors::EthTransactionError;

    #[test]
    fn test_happy_path() {
        let result = check_gas_fee(100, Option::Some(10), 50);
        assert!(result.is_ok());
    }

    #[test]
    fn test_fee_cap_too_low() {
        let result = check_gas_fee(40, Option::Some(10), 50);
        assert_eq!(result, Result::Err(EthTransactionError::FeeCapTooLow));
    }

    #[test]
    fn test_tip_above_fee_cap() {
        let result = check_gas_fee(100, Option::Some(110), 50);
        assert_eq!(result, Result::Err(EthTransactionError::TipAboveFeeCap));
    }

    #[test]
    fn test_priority_fee_none() {
        let result = check_gas_fee(100, Option::None, 50);
        assert!(result.is_ok());
    }
}
