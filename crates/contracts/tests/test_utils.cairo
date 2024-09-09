use contracts::account_contract::{AccountContract};
use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcher, interface::IExtendedKakarotCoreDispatcherTrait,
    KakarotCore
};
use contracts::{UninitializedAccount};
use core::fmt::Debug;
use core::result::ResultTrait;
use core::starknet::ClassHash;
use core::starknet::{
    testing, contract_address_const, EthAddress, ContractAddress,
    get_contract_address
};
use core::starknet::syscalls::deploy_syscall;
use evm::backend::starknet_backend;
use evm::model::{Address};

use evm::test_utils::{ca_address, other_starknet_address, chain_id, sequencer_evm_address};
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use snforge_std::{
    declare, DeclareResult, DeclareResultTrait, ContractClassTrait, start_cheat_caller_address,
    start_cheat_sequencer_address_global, stop_cheat_caller_address, CheatSpan,
    start_cheat_caller_address_global
};
use utils::constants::BLOCK_GAS_LIMIT;
use utils::eth_transaction::LegacyTransaction;


mod constants {
    use core::starknet::{EthAddress, testing, contract_address_const, ContractAddress};
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
    let class = declare("ERC20").unwrap().contract_class().class_hash;
    let maybe_address = deploy_syscall(*class, 0, calldata.span(), false);
    match maybe_address {
        Result::Ok((contract_address, _)) => { IERC20CamelDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

fn deploy_kakarot_core(
    native_token: ContractAddress, mut eoas: Span<EthAddress>
) -> IExtendedKakarotCoreDispatcher {
    let account_contract_class_hash = declare("AccountContract")
        .unwrap()
        .contract_class()
        .class_hash;
    let uninitialized_account_class_hash = declare("UninitializedAccount")
        .unwrap()
        .contract_class()
        .class_hash;
    let kakarot_core_class_hash = declare("KakarotCore").unwrap().contract_class().class_hash;
    let mut calldata: Array<felt252> = array![
        other_starknet_address().into(),
        native_token.into(),
        (*account_contract_class_hash).into(),
        (*uninitialized_account_class_hash).into(),
        'coinbase',
        BLOCK_GAS_LIMIT.into(),
    ];

    Serde::serialize(@eoas, ref calldata);

    let maybe_address = deploy_syscall(
        (*kakarot_core_class_hash).into(), 0, calldata.span(), false
    );

    match maybe_address {
        Result::Ok((
            contract_address, _
        )) => { IExtendedKakarotCoreDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

pub(crate) fn deploy_contract_account(
    kakarot_core: IExtendedKakarotCoreDispatcher, evm_address: EthAddress, bytecode: Span<u8>
) -> Address {
    let eoa = deploy_eoa(kakarot_core, evm_address);
    let starknet_address = eoa.contract_address;
    start_cheat_caller_address(starknet_address, kakarot_core.contract_address);
    IAccountDispatcher { contract_address: starknet_address }.set_nonce(1);
    IAccountDispatcher { contract_address: starknet_address }.write_bytecode(bytecode);
    stop_cheat_caller_address(starknet_address);
    Address { evm: evm_address, starknet: starknet_address }
}

fn deploy_eoa(
    kakarot_core: IExtendedKakarotCoreDispatcher, evm_address: EthAddress
) -> IAccountDispatcher {
    let starknet_address = kakarot_core.deploy_externally_owned_account(evm_address);
    IAccountDispatcher { contract_address: starknet_address }
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
    start_cheat_caller_address(native_token.contract_address, constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
    stop_cheat_caller_address(native_token.contract_address);
}

pub(crate) fn setup_contracts_for_testing() -> (
    IERC20CamelDispatcher, IExtendedKakarotCoreDispatcher
) {
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(
        native_token.contract_address, [sequencer_evm_address()].span()
    );

    let sequencer: EthAddress = sequencer_evm_address();

    let sequencer_sn_address = kakarot_core.address_registry(sequencer);
    start_cheat_sequencer_address_global(sequencer_sn_address);
    start_cheat_caller_address_global(kakarot_core.contract_address);
    return (native_token, kakarot_core);
}
