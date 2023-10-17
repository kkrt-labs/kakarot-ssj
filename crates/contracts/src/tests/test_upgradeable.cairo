use MockContractUpdatableV0::HasComponentImpl_upgradable_component;
use contracts::components::upgradable::{IUpgradableDispatcher, IUpgradableDispatcherTrait};
use contracts::components::upgradable::{upgradable_component};
use contracts::tests::utils;
use debug::PrintTrait;
use serde::Serde;
use starknet::{deploy_syscall, ClassHash, ContractAddress, testing};

use upgradable_component::{UpgradableImpl};

#[starknet::interface]
trait IMockContractUpdatable<TContractState> {
    fn version(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod MockContractUpdatableV0 {
    use contracts::components::upgradable::{upgradable_component};
    use super::IMockContractUpdatable;
    component!(path: upgradable_component, storage: upgradable, event: UpgradableEvent);

    #[abi(embed_v0)]
    impl UpgradableImpl = upgradable_component::UpgradableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradable: upgradable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradableEvent: upgradable_component::Event
    }

    #[external(v0)]
    impl MockContractUpdatableImpl of IMockContractUpdatable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            0
        }
    }
}

type TestingState = upgradable_component::ComponentState<MockContractUpdatableV0::ContractState>;

impl TestingStateDefault of Default<TestingState> {
    fn default() -> TestingState {
        upgradable_component::component_state_for_testing()
    }
}

#[test]
#[available_gas(500000)]
fn test_upgradable_update_contract() {
    let (contract_address, _) = deploy_syscall(
        MockContractUpdatableV0::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
    )
        .unwrap();

    let version = IMockContractUpdatableDispatcher { contract_address: contract_address }.version();

    assert(version == 0, 'version is not 0');

    let mut call_data: Array<felt252> = array![];

    let new_class_hash: ClassHash = MockContractUpdatableV1::TEST_CLASS_HASH.try_into().unwrap();

    IUpgradableDispatcher { contract_address: contract_address }.upgrade_contract(new_class_hash);

    let version = IMockContractUpdatableDispatcher { contract_address: contract_address }.version();
    assert(version == 1, 'version is not 1');
}


#[starknet::contract]
mod MockContractUpdatableV1 {
    use contracts::components::upgradable::{upgradable_component};
    use super::IMockContractUpdatable;
    component!(path: upgradable_component, storage: upgradable, event: UpgradableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradable: upgradable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradableEvent: upgradable_component::Event
    }

    #[external(v0)]
    impl MockContractUpdatableImpl of IMockContractUpdatable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            1
        }
    }
}
