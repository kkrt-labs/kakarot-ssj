// Migrate https://github.com/kkrt-labs/kakarot/blob/7ec7a96074394ddb592a2b6fbea279c6c5cb25a6/src/kakarot/accounts/eoa/externally_owned_account.cairo#L4

#[starknet::interface]
trait IExternallyOwnedAccount<TContractState> {
    fn bytecode(self: @TContractState) -> Span<u8>;
    fn bytecode_len(self: @TContractState) -> u32;
}

#[starknet::contract]
mod ExternallyOwnedAccount {
    use array::{ArrayTrait, SpanTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        starknet_address: ContractAddress
    }

    #[external(v0)]
    impl ExternallyOwnedAccount of super::IExternallyOwnedAccount<ContractState> {
        /// Returns an empty span, required for the EXTCODE opcode
        fn bytecode(self: @ContractState) -> Span<u8> {
            return ArrayTrait::<u8>::new().span();
        }
        /// Return 0 bytecode_len, required for the EXTCODE opcode
        fn bytecode_len(self: @ContractState) -> u32 {
            return 0;
        }
    }
}

