//! The generic account that is deployed by Kakarot Core before being "specialized" into an Externally Owned Account or a Contract Account
//! This aims at having only one class hash for all the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth Address <=> Starknet Address

use starknet::ClassHash;

#[starknet::interface]
trait IUninitializedAccount<TContractState> {
    fn initialize(ref self: TContractState, new_class_hash: ClassHash);
}


#[starknet::contract]
mod UninitializedAccount {
    use contracts::components::upgradeable::IUpgradeable;
    use contracts::components::upgradeable::upgradeable_component;
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use contracts::uninitialized_account::IUninitializedAccount;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{ContractAddress, EthAddress, ClassHash, get_caller_address};

    component!(path: upgradeable_component, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableImpl = upgradeable_component::Upgradeable<ContractState>;

    #[storage]
    struct Storage {
        evm_address: EthAddress,
        kakarot_core_address: ContractAddress,
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradeableEvent: upgradeable_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, kakarot_address: ContractAddress, evm_address: EthAddress
    ) {
        self.kakarot_core_address.write(kakarot_address);
        self.evm_address.write(evm_address);
    }

    #[abi(embed_v0)]
    impl UninitializedAccountImpl of IUninitializedAccount<ContractState> {
        fn initialize(ref self: ContractState, new_class_hash: ClassHash) {
            assert(
                get_caller_address() == self.kakarot_core_address.read(),
                'Caller not Kakarot Core address'
            );
            self.upgradeable.upgrade_contract(new_class_hash);
            let kakarot = self.kakarot_core_address.read();
            let native_token = IKakarotCoreDispatcher { contract_address: kakarot }.native_token();
            // To internally perform value transfer of the network's native
            // token (which conforms to the ERC20 standard), we need to give the
            // KakarotCore contract infinite allowance
            IERC20CamelDispatcher { contract_address: native_token }
                .approve(kakarot, integer::BoundedInt::<u256>::max());

            self.upgradeable.upgrade_contract(new_class_hash);
        }
    }
}
