mod blake2f;
mod ec_recover;
mod identity;
mod sha256;

use core::traits::Into;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::blake2f::Blake2f;
use evm::precompiles::ec_recover::EcRecover;
use evm::precompiles::identity::Identity;
use evm::precompiles::sha256::Sha256;
use starknet::EthAddress;


trait Precompile {
    fn address() -> EthAddress;
    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError>;
}

#[generate_trait]
impl PrecompilesImpl of Precompiles {
    fn exec_precompile(ref vm: VM) -> Result<(), EVMError> {
        let precompile_address = vm.message.target.evm;
        let input = vm.message().data;

        let (gas, result) = match precompile_address.address {
            0 => {
                // we should never reach this branch!
                panic!("pre-compile address can't be 0")
            },
            1 => { EcRecover::exec(input)? },
            2 => { Sha256::exec(input)? },
            3 => {
                // we should never reach this branch!
                panic!(
                    "pre-compile at address {} isn't implemented yet", precompile_address.address
                )
            },
            4 => { Identity::exec(input)? },
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
            9 => { Blake2f::exec(input)? },
            _ => {
                // we should never reach this branch!
                panic!("address {} isn't a pre-compile", precompile_address.address)
            }
        };

        vm.charge_gas(gas)?;
        vm.return_data = result;
        vm.stop();
        return Result::Ok(());
    }
}
