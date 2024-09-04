mod blake2f;
mod ec_add;
mod ec_mul;
mod ec_recover;
mod identity;
mod modexp;
mod p256verify;
mod sha256;
use core::starknet::EthAddress;

use core::traits::Into;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::blake2f::Blake2f;
use evm::precompiles::ec_recover::EcRecover;
use evm::precompiles::identity::Identity;
use evm::precompiles::modexp::ModExp;
use evm::precompiles::p256verify::P256Verify;
use evm::precompiles::sha256::Sha256;


trait Precompile {
    fn address() -> EthAddress;
    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError>;
}

#[generate_trait]
impl PrecompilesImpl of Precompiles {
    fn exec_precompile(ref vm: VM) -> Result<(), EVMError> {
        let precompile_address = vm.message.code_address.evm;
        let input = vm.message().data;

        let (gas, result) = if precompile_address.address == 0x100 {
            P256Verify::exec(input)?
        } else {
            match precompile_address.address {
                0x00 => {
                    // we should never reach this branch!
                    panic!("pre-compile address can't be 0")
                },
                0x01 => { EcRecover::exec(input)? },
                0x02 => { Sha256::exec(input)? },
                0x03 => {
                    // we should never reach this branch!
                    panic!(
                        "pre-compile at address {} isn't implemented yet",
                        precompile_address.address
                    )
                },
                0x04 => { Identity::exec(input)? },
                0x05 => { ModExp::exec(input)? },
                0x06 => {
                    // we should never reach this branch!
                    panic!(
                        "pre-compile at address {} isn't implemented yet",
                        precompile_address.address
                    )
                },
                0x07 => {
                    // we should never reach this branch!
                    panic!(
                        "pre-compile at address {} isn't implemented yet",
                        precompile_address.address
                    )
                },
                0x08 => {
                    // we should never reach this branch!
                    panic!(
                        "pre-compile at address {} isn't implemented yet",
                        precompile_address.address
                    )
                },
                0x09 => { Blake2f::exec(input)? },
                0x0a => {
                    // Point Evaluation
                    panic!(
                        "pre-compile at address {} isn't implemented yet",
                        precompile_address.address
                    )
                },
                _ => {
                    // we should never reach this branch!
                    panic!("address {} isn't a pre-compile", precompile_address.address)
                }
            }
        };

        vm.charge_gas(gas)?;
        vm.return_data = result;
        vm.stop();
        return Result::Ok(());
    }
}
