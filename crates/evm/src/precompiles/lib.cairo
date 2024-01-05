use core::traits::Into;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::blake2::Blake2PrecompileTrait;
use evm::precompiles::ec_recover::EcRecoverPrecompileTrait;

use evm::precompiles::identity::IdentityPrecompileTrait;
use evm::precompiles::sha256::Sha256PrecompileTrait;
use starknet::EthAddress;

#[generate_trait]
impl PrecompileTraitImpl of PrecompileTrait {
    fn exec_precompile(ref vm: VM) -> Result<(), EVMError> {
        let precompile_address = vm.message.target.evm;

        let result = match precompile_address.address {
            0 => {
                // we should never reach this branch!
                panic!("pre-compile address can't be 0")
            },
            1 => { EcRecoverPrecompileTrait::exec(ref vm) },
            2 => { Sha256PrecompileTrait::exec(ref vm) },
            3 => {
                // we should never reach this branch!
                panic!(
                    "pre-compile at address {} isn't implemented yet", precompile_address.address
                )
            },
            4 => { IdentityPrecompileTrait::exec(ref vm) },
            5 => {
                // we should never reach this branch!
                panic!(
                    "pre-compile at address {} isn't implemented yet", precompile_address.address
                )
            },
            6 => {
                // we should never reach this branch!
                panic!(
                    "pre-compile at address {} isn't implemented yet", precompile_address.address
                )
            },
            7 => {
                // we should never reach this branch!
                panic!(
                    "pre-compile at address {} isn't implemented yet", precompile_address.address
                )
            },
            8 => {
                // we should never reach this branch!
                panic!(
                    "pre-compile at address {} isn't implemented yet", precompile_address.address
                )
            },
            9 => { Blake2PrecompileTrait::exec(ref vm) },
            _ => {
                // we should never reach this branch!
                panic!("address {} isn't a pre-compile", precompile_address.address)
            }
        };

        vm.stop();
        result
    }
}
