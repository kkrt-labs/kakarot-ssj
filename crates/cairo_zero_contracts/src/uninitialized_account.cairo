//! The generic account that is deployed by Kakarot Core before being "specialized" into a Contract Account.
//! This aims at having only one class hash for all the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth Address <=> Starknet Address

#[starknet::interface]
trait IKakarotCore<TContractState> {
    fn get_account_contract_class_hash(self: @TContractState) -> starknet::ClassHash;
}

const INITIALIZE_SELECTOR: felt252 =
    0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463; // sn_keccak('initialize')

#[starknet::contract]
mod UninitializedAccount {
    use core::starknet::SyscallResultTrait;
    use starknet::{
        ContractAddress, EthAddress, replace_class_syscall, library_call_syscall
    };
    use super::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait, INITIALIZE_SELECTOR};

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState, kakarot_address: ContractAddress, evm_address: EthAddress
    ) {
        let implementation_class = IKakarotCoreDispatcher { contract_address: kakarot_address }
            .get_account_contract_class_hash();

        let calldata = array![
            kakarot_address.into(), evm_address.into(), implementation_class.into()
        ];
        library_call_syscall(implementation_class, INITIALIZE_SELECTOR, calldata.span())
            .unwrap_syscall();

        replace_class_syscall(implementation_class).unwrap_syscall();
    }
}
