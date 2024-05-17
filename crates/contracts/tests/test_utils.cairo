use contracts::account_contract::{AccountContract};
use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcher, interface::IExtendedKakarotCoreDispatcherTrait,
    KakarotCore
};
use contracts::uninitialized_account::{UninitializedAccount};
use core::fmt::Debug;
use core::result::ResultTrait;
use evm::backend::starknet_backend;
use evm::model::{Address};

use evm_tests::test_utils::{ca_address, other_starknet_address, chain_id, sequencer_evm_address};
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{
    testing, contract_address_const, EthAddress, ContractAddress, deploy_syscall,
    get_contract_address
};
use utils::constants::BLOCK_GAS_LIMIT;
use utils::eth_transaction::LegacyTransaction;

/// Pop the earliest unpopped logged event for the contract as the requested type
/// and checks there's no more data left on the event, preventing unaccounted params.
/// This function also removes the first key from the event. This is because indexed
/// params are set as event keys, but the first event key is always set as the
/// event ID.
/// Author: Openzeppelin https://github.com/OpenZeppelin/cairo-contracts
fn pop_log<T, +Drop<T>, impl TEvent: starknet::Event<T>>(address: ContractAddress) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;

    // Remove the event ID from the keys
    keys.pop_front().expect('pop_log popfront failed');

    let ret = starknet::Event::deserialize(ref keys, ref data);
    ret
}

fn pop_log_debug<T, +Drop<T>, +Debug<T>, impl TEvent: starknet::Event<T>>(
    address: ContractAddress
) -> Option<T> {
    let (mut keys, mut data) = testing::pop_log_raw(address)?;

    // Remove the event ID from the keys
    keys.pop_front().expect('pop_log popfront failed');

    let ret = starknet::Event::deserialize(ref keys, ref data);

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

    pub(crate) fn EVM_ADDRESS() -> EthAddress {
        0xc0ffee.try_into().unwrap()
    }

    pub(crate) fn ETH_BANK() -> ContractAddress {
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

fn deploy_kakarot_core(
    native_token: ContractAddress, mut eoas: Span<EthAddress>
) -> IExtendedKakarotCoreDispatcher {
    let mut calldata: Array<felt252> = array![
        other_starknet_address().into(),
        native_token.into(),
        AccountContract::TEST_CLASS_HASH.try_into().unwrap(),
        UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        'coinbase',
        BLOCK_GAS_LIMIT.into(),
    ];

    Serde::serialize(@eoas, ref calldata);

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

pub fn deploy_contract_account(evm_address: EthAddress, bytecode: Span<u8>) -> Address {
    let ca_address = starknet_backend::deploy(evm_address).expect('failed to deploy CA');
    IAccountDispatcher { contract_address: ca_address.starknet }.set_nonce(1);
    IAccountDispatcher { contract_address: ca_address.starknet }.write_bytecode(bytecode);
    ca_address
}

fn deploy_eoa(eoa_address: EthAddress) -> IAccountDispatcher {
    let kakarot_address = get_contract_address();
    let calldata: Span<felt252> = array![kakarot_address.into(), eoa_address.into()].span();

    let (starknet_address, _) = deploy_syscall(
        UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(),
        eoa_address.into(),
        calldata,
        true
    )
        .expect('failed to deploy EOA');

    let eoa = IAccountDispatcher { contract_address: starknet_address };
    eoa
}

fn call_transaction(
    chain_id: u128, destination: Option<EthAddress>, calldata: Span<u8>
) -> LegacyTransaction {
    LegacyTransaction {
        chain_id, nonce: 0, gas_price: 0, gas_limit: 500000000, destination, amount: 0, calldata
    }
}

fn fund_account_with_native_token(
    contract_address: ContractAddress, native_token: IERC20CamelDispatcher, amount: u256,
) {
    let current_contract = get_contract_address();
    testing::set_contract_address(constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
    testing::set_contract_address(current_contract);
}

pub(crate) fn setup_contracts_for_testing() -> (
    IERC20CamelDispatcher, IExtendedKakarotCoreDispatcher
) {
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(
        native_token.contract_address, array![sequencer_evm_address()].span()
    );

    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggered in the constructor.
    drop_event(kakarot_core.contract_address);

    let sequencer: EthAddress = sequencer_evm_address();

    let sequencer_sn_address = kakarot_core.address_registry(sequencer);
    // We drop the event of the EOA deployment
    drop_event(kakarot_core.contract_address);
    testing::set_sequencer_address(sequencer_sn_address);
    testing::set_contract_address(kakarot_core.contract_address);
    return (native_token, kakarot_core);
}
