use core::array::ArrayTrait;
use core::option::OptionTrait;

use evm::errors::{EVMError, ensure};
use evm::model::vm::{VM, VMTrait};
use starknet::EthAddress;
use utils::crypto::blake2_compress::compress;
use utils::helpers::{U32Trait, U64Trait, ToBytes};
use evm::precompiles::Precompile;

const GF_ROUND: u64 = 1;
const INPUT_LENGTH: usize = 213;

impl Blake2f of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x9 }
    }

    fn exec(input: Array<u8>) -> Result<(u128, Array<u8>), EVMError> {
        let input = input.span();

        ensure(
            input.len() == INPUT_LENGTH, EVMError::InvalidParameter('Blake2: wrong input length')
        )?;

        let f = match (*input[212]).into() {
            0 => false,
            1 => true,
            _ => {
                return Result::Err(EVMError::InvalidParameter('Blake2: wrong final indicator'));
            }
        };

        let rounds = U32Trait::from_be_bytes(input.slice(0, 4))
            .ok_or(EVMError::TypeConversionError('extraction of u32 failed'))?;

        let gas: u128 = (GF_ROUND * rounds.into()).into();

        let mut h: Array<u64> = Default::default();
        let mut m: Array<u64> = Default::default();

        let mut i = 0;
        let mut pos = 4;
        loop {
            if i == 8 {
                break;
            }

            // safe unwrap, because we have made sure of the input length to be 213
            h.append(U64Trait::from_le_bytes(input.slice(pos, 8)).unwrap());
            i += 1;
            pos += 8;
        };

        let mut i = 0;
        let mut pos = 68;
        loop {
            if i == 16 {
                break;
            }

            // safe unwrap, because we have made sure of the input length to be 213
            m.append(U64Trait::from_le_bytes(input.slice(pos, 8)).unwrap());
            i += 1;
            pos += 8;
        };

        let mut t: Array<u64> = Default::default();

        // safe unwrap, because we have made sure of the input length to be 213
        t.append(U64Trait::from_le_bytes(input.slice(196, 8)).unwrap());
        // safe unwrap, because we have made sure of the input length to be 213
        t.append(U64Trait::from_le_bytes(input.slice(204, 8)).unwrap());

        let res = compress(rounds, h.span(), m.span(), t.span(), f);

        let mut return_data: Array<u8> = Default::default();

        let mut i = 0;
        loop {
            if i == res.len() {
                break;
            }

            let bytes = (*res[i]).to_le_bytes_padded();
            return_data.append_span(bytes);

            i += 1;
        };

        Result::Ok((gas, return_data))
    }
}
