pub mod common;
pub mod eip1559;
pub mod eip2930;
pub mod legacy;
pub mod transaction;
pub mod tx_type;
use core::cmp::min;
use core::num::traits::{CheckedAdd, Zero};
use core::option::OptionTrait;
use core::starknet::{EthAddress, secp256_trait::Signature,};
use utils::errors::{EthTransactionError, RLPErrorImpl};

use utils::helpers::ByteArrayExt;

#[derive(Drop)]
pub struct TransactionMetadata {
    pub address: EthAddress,
    pub account_nonce: u64,
    pub chain_id: u64,
    pub signature: Signature,
}

/// Get the effective gas price of a transaction as specfified in EIP-1559 with relevant
/// checks.
pub fn get_effective_gas_price(
    max_fee_per_gas: u128, max_priority_fee_per_gas: Option<u128>, block_base_fee: u128,
) -> Result<u128, EthTransactionError> {
    let max_priority_fee_per_gas = max_priority_fee_per_gas.unwrap_or(0);

    if max_fee_per_gas < block_base_fee {
        // `base_fee_per_gas` is greater than the `max_fee_per_gas`
        return Result::Err(EthTransactionError::FeeCapTooLow);
    }
    if max_fee_per_gas < max_priority_fee_per_gas {
        // `max_priority_fee_per_gas` is greater than the `max_fee_per_gas`
        return Result::Err(EthTransactionError::TipAboveFeeCap);
    }
    Result::Ok(
        min(
            max_fee_per_gas,
            block_base_fee
                .checked_add(max_priority_fee_per_gas)
                .ok_or(EthTransactionError::TipVeryHigh)?,
        )
    )
}

#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use super::get_effective_gas_price;
    use utils::errors::EthTransactionError;

    #[test]
    fn test_max_fee_superior_block_fee_should_return_effective_gas_price() {
        let result = get_effective_gas_price(100, Option::Some(10), 50);
        assert_eq!(result, Result::Ok(60));
    }

    #[test]
    fn test_max_fee_equal_block_fee_plus_priority_fee_should_return_max_fee() {
        let result = get_effective_gas_price(100, Option::Some(50), 50);
        assert_eq!(result, Result::Ok(100));
    }

    #[test]
    fn test_max_fee_inferior_block_fee_should_err() {
        let result = get_effective_gas_price(40, Option::Some(10), 50);
        assert_eq!(result, Result::Err(EthTransactionError::FeeCapTooLow));
    }

    #[test]
    fn test_max_fee_inferior_priority_fee_should_err() {
        let result = get_effective_gas_price(100, Option::Some(110), 50);
        assert_eq!(result, Result::Err(EthTransactionError::TipAboveFeeCap));
    }

    #[test]
    fn test_block_fee_plus_priority_fee_overflow_should_err() {
        let result = get_effective_gas_price(Bounded::MAX, Option::Some(1), Bounded::MAX);
        assert_eq!(result, Result::Err(EthTransactionError::TipVeryHigh));
    }

    #[test]
    fn test_priority_fee_none_should_use_zero() {
        let result = get_effective_gas_price(100, Option::None, 50);
        assert_eq!(result, Result::Ok(50));
    }

    #[test]
    fn test_max_fee_equal_block_fee_less_than_total_should_return_max_fee() {
        let result = get_effective_gas_price(50, Option::Some(10), 50);
        assert_eq!(result, Result::Ok(50));
    }
}
