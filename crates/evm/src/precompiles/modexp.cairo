// CREDITS: The implementation has take reference from [revm](https://github.com/bluealloy/revm/blob/main/crates/precompile/src/modexp.rs)

use core::option::OptionTrait;
use core::traits::TryInto;

use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;

use evm::precompiles::Precompile;

use integer::{u32_overflowing_add, BoundedInt};
use starknet::EthAddress;
use utils::crypto::modexp::lib::modexp;
use utils::helpers::{U256Trait, U8SpanExTrait, U64Trait, FromBytes, BitLengthTrait};

const HEADER_LENGTH: usize = 96;
const MIN_GAS: u128 = 200;

impl ModExp of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x5 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        // The format of input is:
        // <length_of_BASE> <length_of_EXPONENT> <length_of_MODULUS> <BASE> <EXPONENT> <MODULUS>
        // Where every length is a 32-byte left-padded integer representing the number of bytes
        // to be taken up by the next value

        // safe unwraps, since we will always get a 32 byte span
        let base_len: u256 = input.slice_right_padded(0, 32).from_be_bytes().unwrap();
        let exp_len: u256 = input.slice_right_padded(32, 32).from_be_bytes().unwrap();
        let mod_len: u256 = input.slice_right_padded(64, 32).from_be_bytes().unwrap();

        // cast base_len, exp_len , modulus_len to usize, it does not make sense to handle larger values
        let base_len: usize = match base_len.try_into() {
            Option::Some(base_len) => { base_len },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('base_len casting to u32 failed'));
            }
        };
        let exp_len: usize = match exp_len.try_into() {
            Option::Some(base_len) => { base_len },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('base_len casting to u32 failed'));
            }
        };
        let mod_len: usize = match mod_len.try_into() {
            Option::Some(base_len) => { base_len },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('base_len casting to u32 failed'));
            }
        };

        // Handle a special case when both the base and mod length is zero
        if base_len == 0 && mod_len == 0 {
            return Result::Ok((MIN_GAS, array![].span()));
        }

        // Used to extract ADJUSTED_EXPONENT_LENGTH.
        let exp_highp_len = if exp_len <= 32 {
            exp_len
        } else {
            32
        };

        let input = if input.len() >= 96 {
            input.slice(HEADER_LENGTH, input.len() - HEADER_LENGTH)
        } else {
            array![].span()
        };

        let exp_highp = {
            // get right padded bytes so if data.len is less then exp_len we will get right padded zeroes.
            let right_padded_highp = input.slice_right_padded(base_len, 32);
            // If exp_len is less then 32 bytes get only exp_len bytes and do left padding.
            let out = right_padded_highp.slice(0, exp_highp_len).pad_left_with_zeroes(32);
            match out.from_be_bytes() {
                Option::Some(result) => result,
                Option::None => {
                    return Result::Err(EVMError::InvalidParameter('failed to extract exp_highp'));
                }
            }
        };

        let gas = ModExpPrecompileHelperTraitImpl::calc_gas(
            base_len.into(), exp_len.into(), mod_len.into(), exp_highp
        );

        // Padding is needed if the input does not contain all 3 values.
        let base = input.slice_right_padded(0, base_len);
        let exponent = input.slice_right_padded(base_len, exp_len);

        let tmp = match u32_overflowing_add(base_len, exp_len) {
            Result::Ok(v) => v,
            Result::Err(v) => v
        };

        let modulus = input.slice_right_padded(tmp, mod_len);

        let output = modexp(base, exponent, modulus);

        let return_data = output.pad_left_with_zeroes(mod_len);
        Result::Ok((gas.into(), return_data))
    }
}

#[generate_trait]
impl ModExpPrecompileHelperTraitImpl of ModExpPrecompileHelperTrait {
    // Calculate gas cost according to EIP 2565:
    // https://eips.ethereum.org/EIPS/eip-2565
    fn calc_gas(base_length: u64, exp_length: u64, mod_length: u64, exp_highp: u256) -> u64 {
        let multiplication_complexity =
            ModExpPrecompileHelperTrait::calculate_multiplication_complexity(
            base_length, mod_length
        );

        let iteration_count = ModExpPrecompileHelperTrait::calculate_iteration_count(
            exp_length, exp_highp
        );

        let gas = (multiplication_complexity * iteration_count.into()) / 3;
        let gas: u64 = gas.try_into().unwrap_or(BoundedInt::<u64>::max());

        if gas >= 200 {
            gas
        } else {
            200
        }
    }

    fn calculate_multiplication_complexity(base_length: u64, mod_length: u64) -> u256 {
        let max_length = if base_length >= mod_length {
            base_length
        } else {
            mod_length
        };
        let mut words = max_length / 8;
        if max_length % 8 > 0 {
            words += 1;
        }
        let words: u256 = words.into();
        words * words
    }

    fn calculate_iteration_count(exp_length: u64, exp_highp: u256) -> u64 {
        let mut iteration_count: u64 = 0;

        if exp_length <= 32 && exp_highp == 0 {
            iteration_count = 0;
        } else if exp_length <= 32 {
            iteration_count = (exp_highp.bit_len() - 1).into();
        } else if exp_length > 32 {
            let max: u64 = if exp_highp.bit_len() >= 1 {
                exp_highp.bit_len().into()
            } else {
                1
            };

            iteration_count = (8 * (exp_length - 32)) + max - 1;
        }

        if iteration_count >= 1 {
            iteration_count
        } else {
            1
        }
    }
}
