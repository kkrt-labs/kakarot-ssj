//! The generic account that is deployed by Kakarot Core before being "specialized" into a Contract Account.
//! This aims at having only one class hash for all the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth Address <=> Starknet Address
use starknet::{ContractAddress, EthAddress, ClassHash};

#[starknet::interface]
trait IKakarotCore<TContractState> {
    fn get_account_contract_class_hash(self: @TContractState) -> ClassHash;
}

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn initialize(
        self: @TContractState,
        kakarot_address: ContractAddress,
        evm_address: EthAddress,
        implementation_class: ClassHash
    );
}

#[starknet::contract]
mod UninitializedAccount {
    use starknet::{ContractAddress, EthAddress, SyscallResultTrait};
    use starknet::syscalls::{replace_class_syscall, library_call_syscall};
    use super::{
        IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait, IAccountDispatcher,
        IAccountDispatcherTrait, IAccountLibraryDispatcher, IAccountLibraryDispatcherImpl
    };

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState, kakarot_address: ContractAddress, evm_address: EthAddress
    ) {
        let implementation_class = IKakarotCoreDispatcher { contract_address: kakarot_address }
            .get_account_contract_class_hash();

        IAccountLibraryDispatcher { class_hash: implementation_class }
            .initialize(kakarot_address, evm_address, implementation_class);
        replace_class_syscall(implementation_class).unwrap_syscall();
    }
}
