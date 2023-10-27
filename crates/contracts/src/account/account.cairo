#[starknet::contract]
mod Account {
    use contracts::account::interface::IAccount;
    use contracts::components::upgradeable::IUpgradeable;
    use contracts::components::upgradeable::upgradeable_component;
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
    impl AccountImpl of IAccount<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(
                get_caller_address() == self.kakarot_core_address.read(),
                'Caller not Kakarot Core address'
            );
            self.upgradeable.upgrade_contract(new_class_hash);
        }
    }
}
