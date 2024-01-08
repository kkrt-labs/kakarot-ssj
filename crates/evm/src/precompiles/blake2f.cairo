use core::array::ArrayTrait;
use core::option::OptionTrait;

use evm::errors::EVMError;
use evm::model::vm::{VM, VMTrait};
use starknet::EthAddress;
use utils::crypto::blake2_compress::compress;
use utils::helpers::{U32Trait, U64Trait};

const GF_ROUND: u64 = 1;
const INPUT_LENGTH: usize = 213;

#[generate_trait]
impl Blake2fPrecompileTraitImpl of Blake2fPrecompileTrait {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x9 }
    }

    fn exec(ref vm: VM) -> Result<(), EVMError> {
        let mut input = array![];
        input.append_span(vm.message().data);
        let input = input.span();

        if input.len() != INPUT_LENGTH {
            return Result::Err(EVMError::InvalidParameter('Blake2: wrong input length'));
        };

        let f = match (*input[212]).into() {
            0 => false,
            1 => true,
            _ => {
                return Result::Err(EVMError::InvalidParameter('Blake2: wrong final indicator'));
            }
        };

        let rounds = match U32Trait::from_be_bytes(input.slice(0, 4)) {
            Option::Some(rounds) => rounds,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError('extraction of u32 failed'));
            }
        };

        let gas: u128 = (GF_ROUND * rounds.into()).into();

        if (gas > vm.gas_left()) {
            return Result::Err(EVMError::OutOfGas);
        }

        vm.charge_gas(gas)?;

        let mut h: Array<u64> = Default::default();
        let mut m: Array<u64> = Default::default();

        let mut i = 0;
        let mut pos = 4;
        loop {
            if i == 8 {
                break;
            }

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

            m.append(U64Trait::from_le_bytes(input.slice(pos, 8)).unwrap());
            i += 1;
            pos += 8;
        };

        let mut t: Array<u64> = Default::default();
        t.append(U64Trait::from_le_bytes(input.slice(196, 8)).unwrap());
        t.append(U64Trait::from_le_bytes(input.slice(204, 8)).unwrap());

        let res = compress(rounds, h.span(), m.span(), t.span(), f);

        let mut return_data: Array<u8> = Default::default();

        let mut i = 0;
        loop {
            if i == res.len() {
                break;
            }

            let bytes = (*res[i]).to_le_bytes_padded().span();
            return_data.append_span(bytes);

            i += 1;
        };

        vm.return_data = return_data.span();
        Result::Ok(())
    }
}
