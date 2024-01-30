use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use starknet::EthAddress;
use evm::precompiles::Precompile;

const BASE_COST: u128 = 15;
const COST_PER_WORD: u128 = 3;

impl Identity of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x4 }
    }

    fn exec(input: Array<u8>) -> Result<(u128, Array<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        return Result::Ok((gas, input));
    }
}
