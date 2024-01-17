use core::option::OptionTrait;
use core::traits::TryInto;

use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;

use integer::{u32_overflowing_add};
use starknet::EthAddress;
use utils::crypto::modexp::lib::modexp;
use utils::helpers::{U256Trait, U8SpanExTrait};

const HEADER_LENGTH: usize = 96;
const MIN_GAS: u128 = 200;

#[generate_trait]
impl ModExpPrecompileTraitImpl of ModExpPrecompileTrait {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x5 }
    }

    fn exec(ref vm: VM) -> Result<(), EVMError> {
        let mut input = array![];
        input.append_span(vm.message().data);
        let input = input.span();

        // The format of input is:
        // <length_of_BASE> <length_of_EXPONENT> <length_of_MODULUS> <BASE> <EXPONENT> <MODULUS>
        // Where every length is a 32-byte left-padded integer representing the number of bytes
        // to be taken up by the next value

        // safe unwraps, since we will always get a 32 byte span
        let base_len: u256 = U256Trait::from_be_bytes(input.get_right_padded_span(0, 32)).unwrap();
        let exp_len: u256 = U256Trait::from_be_bytes(input.get_right_padded_span(32, 32)).unwrap();
        let mod_len: u256 = U256Trait::from_be_bytes(input.get_right_padded_span(64, 32)).unwrap();

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
            vm.charge_gas(MIN_GAS)?;
            return Result::Ok(());
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
            let right_padded_highp = input.get_right_padded_span(base_len, 32);
            // If exp_len is less then 32 bytes get only exp_len bytes and do left padding.
            let out = right_padded_highp.slice(0, exp_highp_len).left_padding(32);
            U256Trait::from_be_bytes(out)
        };

        // todo calc gas & gas

        // Padding is needed if the input does not contain all 3 values.
        let base = input.get_right_padded_span(0, base_len);
        let exponent = input.get_right_padded_span(base_len, exp_len);

        let tmp = match u32_overflowing_add(base_len, exp_len) {
            Result::Ok(v) => v,
            Result::Err(v) => v
        };

        let modulus = input.get_right_padded_span(tmp, mod_len);

        let output = modexp(base, exponent, modulus);

        vm.return_data = output.left_padding(mod_len);

        Result::Ok(())
    }
}
