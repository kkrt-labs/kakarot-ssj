use contracts::contract_account::contract_account::ContractAccount;
use contracts::contract_account::interface::{
    IContractAccountDispatcher, IContractAccountDispatcherTrait
};
use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcher, KakarotCore};
use contracts::uninitialized_account::interface::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
};
use contracts::uninitialized_account::uninitialized_account::UninitializedAccount;

use debug::PrintTrait;
use eoa::externally_owned_account::{ExternallyOwnedAccount};
use evm::tests::test_utils::{deploy_fee, ca_address, other_starknet_address, chain_id};
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{
    testing, contract_address_const, ContractAddress, deploy_syscall, get_contract_address
};

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
    use starknet::{EthAddress, testing, contract_address_const, ContractAddress};
    fn ZERO() -> ContractAddress {
        contract_address_const::<0>()
    }

    fn OWNER() -> ContractAddress {
        contract_address_const::<0xabde1>()
    }

    fn OTHER() -> ContractAddress {
        contract_address_const::<0xe1145>()
    }

    fn EVM_ADDRESS() -> EthAddress {
        0xc0ffee.try_into().unwrap()
    }

    fn ETH_BANK() -> ContractAddress {
        contract_address_const::<0x777>()
    }
}

fn deploy_native_token() -> IERC20CamelDispatcher {
    let calldata: Array<felt252> = array![
        'STARKNET_ETH', 'ETH', 0x00, 0xfffffffffffffffffffffffffff, constants::ETH_BANK().into()
    ];
    let maybe_address = deploy_syscall(
        ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    );
    match maybe_address {
        Result::Ok((contract_address, _)) => { IERC20CamelDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}
fn deploy_kakarot_core(native_token: ContractAddress) -> IExtendedKakarotCoreDispatcher {
    let calldata: Array<felt252> = array![
        native_token.into(),
        deploy_fee().into(),
        UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        ContractAccount::TEST_CLASS_HASH.try_into().unwrap(),
        other_starknet_address().into(),
        chain_id().into()
    ];
    let maybe_address = deploy_syscall(
        KakarotCore::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    );

    match maybe_address {
        Result::Ok((
            contract_address, _
        )) => { IExtendedKakarotCoreDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

fn deploy_contract_account(
    kakarot_address: ContractAddress, bytecode: Span<u8>
) -> IContractAccountDispatcher {
    testing::set_contract_address(kakarot_address);
    let calldata: Array<felt252> = array![kakarot_address.into(), ca_address().into(),];

    let (contract_address, _) = deploy_syscall(
        UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .expect('Deployment should succeed');
    IUninitializedAccountDispatcher { contract_address }
        .initialize(ContractAccount::TEST_CLASS_HASH.try_into().unwrap());

    let contract_account = IContractAccountDispatcher { contract_address };

    // Initialize the contract account
    contract_account.set_nonce(1);
    contract_account.set_bytecode(bytecode);

    contract_account
}


fn fund_account_with_native_token(
    contract_address: ContractAddress, native_token: IERC20CamelDispatcher
) {
    let current_contract = get_contract_address();
    let amount: u256 = 0x01;
    testing::set_contract_address(constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
    testing::set_contract_address(current_contract);
}
