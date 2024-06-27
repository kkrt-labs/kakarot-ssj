//! The generic account that is deployed by Kakarot Core before being "specialized" into an
//! Externally Owned Account or a Contract Account This aims at having only one class hash for all
//! the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth
//! Address <=> Starknet Address

use starknet::ClassHash;
use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
trait IAccount<TContractState> {
    fn initialize(
        ref self: TContractState,
        kakarot_address: ContractAddress,
        evm_address: EthAddress,
        implementation_class: ClassHash
    );
}


#[starknet::contract]
pub mod UninitializedAccount {
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use core::starknet::SyscallResultTrait;
    use starknet::syscalls::replace_class_syscall;
    use starknet::{ContractAddress, EthAddress, ClassHash, get_caller_address};
    use super::{IAccountLibraryDispatcher, IAccountDispatcherTrait};

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
