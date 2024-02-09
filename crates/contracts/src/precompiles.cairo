#[starknet::interface]
trait IPrecompiles<T> {
    /// Executes a precompiled contract at a given address with provided data.
    ///
    /// # Arguments
    ///
    /// * `self` - The instance of the current class.
    /// * `address` - The address of the precompiled contract to be executed.
    /// * `data` - The data to be passed to the precompiled contract.
    ///
    /// # Returns
    ///
    /// * A tuple containing:
    ///   * A boolean indicating the success or failure of the execution.
    ///   * The gas cost of the execution.
    ///   * The output data from the execution.
    fn exec_precompile(self: @T, address: felt252, data: Span<u8>) -> (bool, u128, Span<u8>);
}

#[starknet::contract]
mod Precompiles {
    use core::traits::Into;
    use evm::errors::EVMError;
    use evm::precompiles::blake2f::Blake2f;
    use evm::precompiles::ec_recover::EcRecover;
    use evm::precompiles::identity::Identity;
    use evm::precompiles::modexp::ModExp;
    use evm::precompiles::sha256::Sha256;

    use super::IPrecompiles;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Precompiles of IPrecompiles<ContractState> {
        fn exec_precompile(
            self: @ContractState, address: felt252, data: Span<u8>
        ) -> (bool, u128, Span<u8>) {
            let result = match address {
                0 => Result::Err(EVMError::NotImplemented),
                1 => Result::Err(EVMError::NotImplemented),
                2 => Sha256::exec(data),
                3 | 4 => Result::Err(EVMError::NotImplemented),
                5 => ModExp::exec(data),
                _ => Result::Err(EVMError::NotImplemented),
            };
            match result {
                Result::Ok((gas, output)) => (true, gas, output),
                Result::Err(_) => (false, 0, array![].span())
            }
        }
    }
}
