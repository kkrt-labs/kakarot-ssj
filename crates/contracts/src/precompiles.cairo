#[starknet::interface]
trait IPrecompiles<T> {
    fn exec_precompile(self: @T, address: felt252, data: Array<u8>) -> Span<u8>;
}

#[starknet::contract]
mod Precompiles {
    use alexandria_math::sha256::sha256;

    use super::IPrecompiles;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Precompiles of IPrecompiles<ContractState> {
        fn exec_precompile(self: @ContractState, address: felt252, data: Array<u8>) -> Span<u8> {
            let result = match address {
                0 => panic!("Precompile address can't be 0"),
                1 => panic!("Precompile ecRecover not available"),
                2 => sha256(data).span(),
                _ => panic!("Precompile {} not available", address)
            };
            return result;
        }
    }
}
