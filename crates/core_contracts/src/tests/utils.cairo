use core_contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcher, contract::KakarotCore
};
use eoa::externally_owned_account::{ExternallyOwnedAccount};
use evm::tests::test_utils::{deploy_fee, other_starknet_address, chain_id};
use starknet::{testing, contract_address_const, ContractAddress, deploy_syscall};
use core_contracts::erc20::contract::ERC20;
use core_contracts::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};


/// Pop the earliest unpopped logged event for the contract as the requested type
/// and checks there's no more data left on the event, preventing unaccounted params.
/// This function also removes the first key from the event. This is because indexed
/// params are set as event keys, but the first event key is always set as the
/// event ID.
/// Author: Openzeppelin https://github.com/OpenZeppelin/cairo-contracts
fn pop_log<T, impl TDrop: Drop<T>, impl TEvent: starknet::Event<T>>(
    address: ContractAddress
) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;

    // Remove the event ID from the keys
    keys.pop_front();

    let ret = starknet::Event::deserialize(ref keys, ref data);
    assert(data.is_empty(), 'Event has extra data');
    ret
}

/// Author: Openzeppelin https://github.com/OpenZeppelin/cairo-contracts
fn drop_event(address: ContractAddress) {
    testing::pop_log_raw(address);
}

/// Author: Openzeppelin https://github.com/OpenZeppelin/cairo-contracts
fn assert_no_events_left(address: ContractAddress) {
    assert(testing::pop_log_raw(address).is_none(), 'Events remaining on queue');
}

mod constants {
    use starknet::{testing, contract_address_const, ContractAddress};
    fn ZERO() -> ContractAddress {
        contract_address_const::<0>()
    }

    fn OWNER() -> ContractAddress {
        contract_address_const::<0xabde1>()
    }

    fn OTHER() -> ContractAddress {
        contract_address_const::<0xe1145>()
    }

    fn ETH_BANK() -> ContractAddress {
        contract_address_const::<0x777>()
    }
}

fn deploy_native_token() -> IERC20CamelDispatcher {
    let calldata: Array<felt252> = array![
        'STARKNET_ETH', 'ETH', 0x00, 0xfffffffffffffffffffffffffff, constants::ETH_BANK().into()
    ];
    let (contract_address, _) = deploy_syscall(
        ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    IERC20CamelDispatcher { contract_address }
}


fn deploy_kakarot_core(native_token: ContractAddress) -> IExtendedKakarotCoreDispatcher {
    let calldata: Array<felt252> = array![
        native_token.into(),
        deploy_fee().into(),
        ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        other_starknet_address().into(),
        chain_id().into()
    ];

    let (contract_address, _) = deploy_syscall(
        KakarotCore::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    IExtendedKakarotCoreDispatcher { contract_address }
}

fn fund_account_with_native_token(
    contract_address: ContractAddress, native_token: IERC20CamelDispatcher
) {
    let amount: u256 = 0x01;
    testing::set_contract_address(constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
}
