use alexandria_math::sha256::sha256;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::Precompile;
use starknet::EthAddress;

const BASE_COST: u128 = 60;
const COST_PER_WORD: u128 = 12;

impl Sha256 of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x2 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        let mut input_array = array![];
        input_array.append_span(input);
        let result = sha256(input_array);

        return Result::Ok((gas, result.span()));
    }
}
