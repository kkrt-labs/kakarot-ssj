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

#[starknet::interface]
trait IHelpers<T> {
    /// Gets the hash of a specific StarkNet block within the range of
    /// [first_v0_12_0_block, current_block - 10].
    ///
    /// # Arguments
    ///
    /// * `block_number` - The block number for which to get the hash.
    ///
    /// # Returns
    /// The hash of the specified block.
    /// 
    /// # Errors
    /// `Block number out of range` - If the block number is greater than `current_block - 10`.
    /// `0`: The block number is inferior to `first_v0_12_0_block`.
    fn get_block_hash(self: @T, block_number: u64) -> felt252;

    /// Computes the keccak hash of the provided data.
    ///
    /// The data is expected to be an array of full 64-bit words.
    /// The last u64-word to hash may be incomplete and is provided separately.
    /// # Arguments
    ///
    /// * `words` - The full 64-bit words to hash.
    /// * `last_input_word` - The last word to hash.
    /// * `last_input_num_bytes` - The number of bytes in the last word.
    ///
    /// # Returns
    /// The EVM-compatible keccak hash of the provided data.
    fn keccak(
        self: @T, words: Array<u64>, last_input_word: u64, last_input_num_bytes: usize
    ) -> u256;
}

#[starknet::contract]
mod Cairo1Helpers {
    use core::keccak::cairo_keccak;
    use core::traits::Into;
    use core::{starknet, starknet::SyscallResultTrait};
    use evm::errors::EVMError;
    use evm::precompiles::blake2f::Blake2f;
    use evm::precompiles::ec_recover::EcRecover;
    use evm::precompiles::identity::Identity;
    use evm::precompiles::modexp::ModExp;
    use evm::precompiles::sha256::Sha256;

    use super::{IPrecompiles, IHelpers};
    use utils::helpers::U256Trait;

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

    #[abi(embed_v0)]
    impl Helpers of IHelpers<ContractState> {
        fn get_block_hash(self: @ContractState, block_number: u64) -> felt252 {
            starknet::get_block_hash_syscall(block_number).unwrap_syscall()
        }

        fn keccak(
            self: @ContractState,
            mut words: Array<u64>,
            last_input_word: u64,
            last_input_num_bytes: usize
        ) -> u256 {
            cairo_keccak(ref words, last_input_word, last_input_num_bytes).reverse_endianness()
        }
    }
}
