use MockContractUpgradeableV0::HasComponentImpl_upgradeable_component;
use contracts::components::upgradeable::{IupgradeableDispatcher, IupgradeableDispatcherTrait};
use contracts::components::upgradeable::{upgradeable_component};
use contracts::tests::utils;
use debug::PrintTrait;
use serde::Serde;
use starknet::{deploy_syscall, ClassHash, ContractAddress, testing};

use upgradeable_component::{upgradeableImpl};

#[starknet::interface]
trait IMockContractUpgradeable<TContractState> {
    fn version(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod MockContractUpgradeableV0 {
    use contracts::components::upgradeable::{upgradeable_component};
    use super::IMockContractUpgradeable;
    component!(path: upgradeable_component, storage: upgradeable, event: upgradeableEvent);

    #[abi(embed_v0)]
    impl upgradeableImpl = upgradeable_component::upgradeableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        upgradeableEvent: upgradeable_component::Event
    }

    #[external(v0)]
    impl MockContractUpgradeableImpl of IMockContractUpgradeable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            0
        }
    }
}

type TestingState = upgradeable_component::ComponentState<MockContractUpgradeableV0::ContractState>;

impl TestingStateDefault of Default<TestingState> {
    fn default() -> TestingState {
        upgradeable_component::component_state_for_testing()
    }
}

#[test]
#[available_gas(500000)]
fn test_upgradeable_update_contract() {
    let (contract_address, _) = deploy_syscall(
        MockContractUpgradeableV0::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
    )
        .unwrap();

    let version = IMockContractUpgradeableDispatcher { contract_address: contract_address }
        .version();

    assert(version == 0, 'version is not 0');

    let mut call_data: Array<felt252> = array![];

    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();

    IupgradeableDispatcher { contract_address: contract_address }.upgrade_contract(new_class_hash);

    let version = IMockContractUpgradeableDispatcher { contract_address: contract_address }
        .version();
    assert(version == 1, 'version is not 1');
}


#[starknet::contract]
mod MockContractUpgradeableV1 {
    use contracts::components::upgradeable::{upgradeable_component};
    use super::IMockContractUpgradeable;
    component!(path: upgradeable_component, storage: upgradeable, event: upgradeableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        upgradeableEvent: upgradeable_component::Event
    }

    #[external(v0)]
    impl MockContractUpgradeableImpl of IMockContractUpgradeable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            1
        }
    }
}