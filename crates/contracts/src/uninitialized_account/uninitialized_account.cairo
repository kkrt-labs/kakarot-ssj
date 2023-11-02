//! The generic account that is deployed by Kakarot Core before being "specialized" into an Externally Owned Account or a Contract Account
//! This aims at having only one class hash for all the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth Address <=> Starknet Address
#[starknet::contract]
mod UninitializedAccount {
    use contracts::components::upgradeable::IUpgradeable;
    use contracts::components::upgradeable::upgradeable_component;
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use contracts::uninitialized_account::interface::IUninitializedAccount;
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

    #[external(v0)]
    impl UninitializedAccountImpl of IUninitializedAccount<ContractState> {
        fn initialize(ref self: ContractState, new_class_hash: ClassHash) {
            assert(
                get_caller_address() == self.kakarot_core_address.read(),
                'Caller not Kakarot Core address'
            );
            let kkt_address = self.kakarot_core_address.read();
            let native_token = IKakarotCoreDispatcher { contract_address: kkt_address }
                .native_token();
            IERC20CamelDispatcher { contract_address: native_token }
                .approve(kkt_address, integer::BoundedInt::<u256>::max());

            self.upgradeable.upgrade_contract(new_class_hash);
        }
    }
}
