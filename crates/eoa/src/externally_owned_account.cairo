// Migrate https://github.com/kkrt-labs/kakarot/blob/7ec7a96074394ddb592a2b6fbea279c6c5cb25a6/src/kakarot/accounts/eoa/externally_owned_account.cairo#L4
use starknet::{EthAddress, ContractAddress};
use integer::BoundedInt;


#[starknet::interface]
trait IExternallyOwnedAccount<TContractState> {
    fn bytecode(self: @TContractState) -> Span<u8>;
    fn bytecode_len(self: @TContractState) -> u32;
    fn get_evm_address(self: @TContractState) -> EthAddress;
}


#[starknet::contract]
mod ExternallyOwnedAccount {
    use array::{ArrayTrait, SpanTrait};
    use starknet::ContractAddress;
    use starknet::EthAddress;
    use integer::BoundedInt;
    use openzeppelin::token::erc20::{ERC20};
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};


    #[storage]
    struct Storage {
        kakarot_address: ContractAddress,
        evm_address: EthAddress,
        is_initialized: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, kakarot_address: ContractAddress, evm_address: EthAddress
    ) {
        let is_initialized = self.is_initialized.read();
        if is_initialized {
            return;
        }
        self.evm_address.write(evm_address);
        let kakarot_token = IERC20Dispatcher { contract_address: kakarot_address };
        let infinite = BoundedInt::<u256>::max();
        kakarot_token.approve(kakarot_address, infinite);
        self.is_initialized.write(true);
        return;
    }

    #[external(v0)]
    impl ExternallyOwnedAccount of super::IExternallyOwnedAccount<ContractState> {
        fn get_evm_address(self: @ContractState) -> EthAddress {
            return self.evm_address.read();
        }

        fn bytecode(self: @ContractState) -> Span<u8> {
            return ArrayTrait::<u8>::new().span();
        }

        fn bytecode_len(self: @ContractState) -> u32 {
            return 0;
        }
    }
}

