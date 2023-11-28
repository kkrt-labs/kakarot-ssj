use starknet::{replace_class_syscall, ClassHash};

#[starknet::interface]
trait IUpgradeable<TContractState> {
    fn upgrade_contract(ref self: TContractState, new_class_hash: ClassHash);
}


#[starknet::component]
mod upgradeable_component {
    use starknet::ClassHash;
    use starknet::info::get_caller_address;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractUpgraded: ContractUpgraded
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUpgraded {
        new_class_hash: ClassHash
    }

    #[embeddable_as(Upgradeable)]
    impl UpgradeableImpl<
        TContractState, +HasComponent<TContractState>
    > of super::IUpgradeable<ComponentState<TContractState>> {
        fn upgrade_contract(
            ref self: ComponentState<TContractState>, new_class_hash: starknet::ClassHash
        ) {
            starknet::replace_class_syscall(new_class_hash).expect('replace class failed');
            self.emit(ContractUpgraded { new_class_hash: new_class_hash });
        }
    }
}
