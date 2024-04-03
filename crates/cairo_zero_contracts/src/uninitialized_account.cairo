//! The generic account that is deployed by Kakarot Core before being "specialized" into a Contract Account.
//! This aims at having only one class hash for all the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth Address <=> Starknet Address

use starknet::ClassHash;

#[starknet::interface]
trait IUninitializedAccount<TContractState> {
    fn initialize(ref self: TContractState);
}

#[starknet::interface]
trait IKakarotCore<TContractState> {
    fn get_account_contract_class_hash(self: @TContractState) -> ClassHash;
}

const INITIALIZE_SELECTOR: felt252 =
    0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463; // sn_keccak('initialize')

#[starknet::contract]
mod UninitializedAccount {
    use core::starknet::SyscallResultTrait;
    use starknet::{
        ContractAddress, EthAddress, get_caller_address, replace_class_syscall,
        library_call_syscall
    };
    use super::{
        IUninitializedAccount, IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait,
        INITIALIZE_SELECTOR
    };

    #[storage]
    struct Storage {
        Account_evm_address: EthAddress,
        Account_kakarot_address: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, kakarot_address: ContractAddress, evm_address: EthAddress
    ) {
        self.Account_kakarot_address.write(kakarot_address);
        self.Account_evm_address.write(evm_address);
    }

    #[abi(embed_v0)]
    impl UninitializedAccountImpl of IUninitializedAccount<ContractState> {
        fn initialize(ref self: ContractState) {
            let kakarot = IKakarotCoreDispatcher {
                contract_address: self.Account_kakarot_address.read()
            };
            let implementation_class = kakarot.get_account_contract_class_hash();
            replace_class_syscall(implementation_class).unwrap_syscall();

            let calldata = array![implementation_class.into()];
            library_call_syscall(implementation_class, INITIALIZE_SELECTOR, calldata.span())
                .unwrap_syscall();
        }
    }
}
