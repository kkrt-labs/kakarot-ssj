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
    use starknet::get_caller_address;
    use debug::PrintTrait;

    #[storage]
    struct Storage {
        kakarot_address: ContractAddress,
        evm_address: EthAddress,
        is_initialized: bool,
    }

    #[constructor]
    fn constructor(
        //TODO: Remove native token and fetch from Kakarot Contract, when Kakarot Contract is ready
        ref self: ContractState,
        native_token: ContractAddress,
        kakarot_address: ContractAddress,
        evm_address: EthAddress
    ) {
        let is_initialized = self.is_initialized.read();
        if is_initialized {
            return;
        }
        self.evm_address.write(evm_address);
        let kakarot_token = IERC20Dispatcher { contract_address: native_token };
        let infinite = BoundedInt::<u256>::max();
        let approval_success = kakarot_token.approve(kakarot_address, infinite);
        let caller_address = get_caller_address();
        let test_allowance = kakarot_token.allowance(caller_address, kakarot_address);
        'Caller Address'.print();
        caller_address.print();
        'Kakarot Address'.print();
        kakarot_address.print();
        // TODO: Check why allowance is 0
        'Test Allowance'.print();
        test_allowance.print();
        self.is_initialized.write(true);
        return;
    }

    #[external(v0)]
    impl ExternallyOwnedAccount of super::IExternallyOwnedAccount<ContractState> {
        fn get_evm_address(self: @ContractState) -> EthAddress {
            return self.evm_address.read();
        }

        // @notice Empty bytecode needed for EXTCODE opcodes.
        fn bytecode(self: @ContractState) -> Span<u8> {
            return ArrayTrait::<u8>::new().span();
        }

        // @notice Empty bytecode needed for EXTCODE opcodes.
        fn bytecode_len(self: @ContractState) -> u32 {
            return 0;
        }
    }
}

