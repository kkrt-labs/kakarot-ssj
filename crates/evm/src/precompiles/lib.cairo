use core::traits::Into;
use evm::errors::EVMError;
use evm::model::vm::VM;

use evm::precompiles::identity::IdentityPrecompileTrait;
use starknet::EthAddress;

#[generate_trait]
impl PrecompileTraitImpl of PrecompileTrait {
    fn exec_precompile(ref vm: VM) -> Result<(), EVMError> {
        let precompile_address = vm.message.target.evm;

        if (precompile_address == IdentityPrecompileTrait::address()) {
            IdentityPrecompileTrait::exec(ref vm)
        } else {
            panic!("precompile at address {} not implemented", precompile_address.address)
        }
    }
}
