use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use starknet::EthAddress;

const IDENTITY_PRECOMPILE_BASE_COST: u128 = 15;
const IDENTITY_PRECOMPILE_COST_PER_WORD: u128 = 3;

#[generate_trait]
impl IdentityPrecompileTraitImpl of IdentityPrecompileTrait {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x4 }
    }

    fn exec(ref vm: VM) -> Result<(), EVMError> {
        let input = vm.message().data;

        let data_word_size: u128 = ((input.len() + 31) / 32).into();

        let gas: u128 = IDENTITY_PRECOMPILE_BASE_COST
            + (data_word_size * IDENTITY_PRECOMPILE_COST_PER_WORD);

        vm.charge_gas(gas)?;
        vm.return_data = input;

        Result::Ok(())
    }
}
