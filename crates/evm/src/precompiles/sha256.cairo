use alexandria_math::sha256::sha256;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use starknet::EthAddress;

const SHA_256_PRECOMPILE_BASE_COST: u128 = 60;
const SHA_256_PRECOMPILE_COST_PER_WORD: u128 = 12;

#[generate_trait]
impl Sha256PrecompileTraitImpl of Sha256PrecompileTrait {
    fn address() -> EthAddress {
        EthAddress { address: 0x2 }
    }

    fn exec(ref vm: VM) -> Result<(), EVMError> {
        let mut input = array![];
        input.append_span(vm.message().data);

        let data_word_size: u128 = ((input.len() + 31) / 32).into();

        let gas: u128 = SHA_256_PRECOMPILE_BASE_COST
            + data_word_size * SHA_256_PRECOMPILE_COST_PER_WORD;

        if (gas > vm.gas_left()) {
            return Result::Err(EVMError::OutOfGas);
        }

        vm.charge_gas(gas)?;

        let result = sha256(input.into());
        vm.return_data = result.span();
        Result::Ok(())
    }
}
