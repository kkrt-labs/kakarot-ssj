use starknet::{replace_class_syscall, ClassHash};

#[starknet::interface]
trait Iupgradeable<TContractState> {
    fn upgrade_contract(ref self: TContractState, class_hash: ClassHash);
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
        ContractUpgrated: ContractUpgrated
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUpgrated {
        new_class_hash: ClassHash
    }

    #[embeddable_as(upgradeableImpl)]
    impl upgradeable<
        TContractState, +HasComponent<TContractState>
    > of super::Iupgradeable<ComponentState<TContractState>> {
        fn upgrade_contract(
            ref self: ComponentState<TContractState>, class_hash: starknet::ClassHash
        ) {
            starknet::replace_class_syscall(class_hash);
            self.emit(ContractUpgrated { new_class_hash: class_hash });
        }
    }
}
