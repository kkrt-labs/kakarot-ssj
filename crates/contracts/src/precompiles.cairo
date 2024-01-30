#[starknet::interface]
trait IPrecompiles<T> {
    fn exec_precompile(self: @T, address: felt252, data: Array<u8>) -> (u128, Span<u8>);
}

#[starknet::contract]
mod Precompiles {
    use core::traits::Into;
    use evm::precompiles::blake2f::Blake2f;
    use evm::precompiles::ec_recover::EcRecover;
    use evm::precompiles::identity::Identity;
    use evm::precompiles::sha256::Sha256;

    use super::IPrecompiles;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Precompiles of IPrecompiles<ContractState> {
        fn exec_precompile(
            self: @ContractState, address: felt252, data: Array<u8>
        ) -> (u128, Span<u8>) {
            let result = match address {
                0 => panic!("Precompile address can't be 0"),
                1 => panic!("Precompile ecRecover not available"),
                2 => Sha256::exec(data),
                _ => panic!("Precompile {} not available", address)
            };
            match result {
                Result::Ok((gas, output)) => (gas, output.span()),
                Result::Err(_) => panic!("Precompile {} failed", address)
            }
        }
    }
}
