use contracts::contract_account::{
    ContractAccount, IContractAccountDispatcher, IContractAccountDispatcherTrait
};

use contracts::eoa::{ExternallyOwnedAccount};
use contracts::eoa::{IExternallyOwnedAccountDispatcher, IExternallyOwnedAccountDispatcherTrait};
use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcher, KakarotCore};
use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait, UninitializedAccount
};
use evm::model::contract_account::ContractAccountTrait;
use evm::model::{Address};

use evm::tests::test_utils::{deploy_fee, ca_address, other_starknet_address, chain_id};
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{
    testing, contract_address_const, EthAddress, ContractAddress, deploy_syscall,
    get_contract_address
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
    keys.pop_front().expect('pop_log popfront failed');

    let ret = starknet::Event::deserialize(ref keys, ref data);
    assert(data.is_empty(), 'Event has extra data');
    ret
}

/// Author: Openzeppelin https://github.com/OpenZeppelin/cairo-contracts
fn drop_event(address: ContractAddress) {
    testing::pop_log_raw(address).unwrap();
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

fn deploy_contract_account(evm_address: EthAddress, bytecode: Span<u8>) -> Address {
    let ca_address = ContractAccountTrait::deploy(evm_address, 1, bytecode, true)
        .expect('deploy CA failed');
    ca_address
}


fn deploy_eoa(eoa_address: EthAddress) -> IExternallyOwnedAccountDispatcher {
    let kakarot_address = get_contract_address();
    let calldata: Span<felt252> = array![kakarot_address.into(), eoa_address.into()].span();

    let (starknet_address, _) = deploy_syscall(
        UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        eoa_address.into(),
        calldata,
        false
    )
        .expect('failed to deploy EOA');

    let account = IUninitializedAccountDispatcher { contract_address: starknet_address };

    account.initialize(ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap());
    let eoa = IExternallyOwnedAccountDispatcher { contract_address: starknet_address };
    eoa.set_chain_id(chain_id());
    eoa
}


fn fund_account_with_native_token(
    contract_address: ContractAddress, native_token: IERC20CamelDispatcher, amount: u256,
) {
    let current_contract = get_contract_address();
    testing::set_contract_address(constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
    testing::set_contract_address(current_contract);
}

fn setup_contracts_for_testing() -> (IERC20CamelDispatcher, IExtendedKakarotCoreDispatcher) {
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    testing::set_contract_address(kakarot_core.contract_address);
    return (native_token, kakarot_core);
}
