pub mod common;
pub mod eip1559;
pub mod eip2930;
pub mod legacy;
pub mod transaction;
pub mod tx_type;
pub mod validation;
use core::cmp::min;
use core::num::traits::{CheckedAdd, Zero};
use core::option::OptionTrait;
use core::starknet::{EthAddress, secp256_trait::Signature,};
use utils::errors::{EthTransactionError, RLPErrorImpl, RLPHelpersErrorImpl};

use utils::helpers::ByteArrayExt;

#[derive(Drop)]
pub struct TransactionMetadata {
    pub address: EthAddress,
    pub account_nonce: u64,
    pub chain_id: u64,
    pub signature: Signature,
}

#[derive(Copy, Drop, Debug, PartialEq)]
pub enum TransactTo {
    /// Simple call to an address.
    Call: EthAddress,
    /// Contract creation.
    Create,
}

/// Get the effective gas price of a transaction as specfified in EIP-1559 with relevant
/// checks.
fn get_effective_gas_price(
    max_fee_per_gas: Option<u256>, max_priority_fee_per_gas: Option<u256>, block_base_fee: u256,
) -> Result<u256, EthTransactionError> {
    match max_fee_per_gas {
        Option::Some(max_fee) => {
            let max_priority_fee_per_gas = max_priority_fee_per_gas.unwrap_or(0);

            // only enforce the fee cap if provided input is not zero
            if !(max_fee.is_zero() && max_priority_fee_per_gas.is_zero())
                && max_fee < block_base_fee {
                // `base_fee_per_gas` is greater than the `max_fee_per_gas`
                return Result::Err(EthTransactionError::FeeCapTooLow);
            }
            if max_fee < max_priority_fee_per_gas {
                // `max_priority_fee_per_gas` is greater than the `max_fee_per_gas`
                return Result::Err(EthTransactionError::TipAboveFeeCap);
            }
            Result::Ok(
                min(
                    max_fee,
                    block_base_fee
                        .checked_add(max_priority_fee_per_gas)
                        .ok_or(EthTransactionError::TipVeryHigh)?,
                )
            )
        },
        Option::None => Result::Ok(
            block_base_fee
                .checked_add(max_priority_fee_per_gas.unwrap_or(0))
                .ok_or(EthTransactionError::TipVeryHigh)?
        ),
    }
}
