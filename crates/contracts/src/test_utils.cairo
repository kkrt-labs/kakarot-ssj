use contracts::account_contract::{AccountContract};
use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{
    interface::IExtendedKakarotCoreDispatcher, interface::IExtendedKakarotCoreDispatcherTrait,
    KakarotCore
};
use contracts::uninitialized_account::{UninitializedAccount};
use core::fmt::Debug;
use core::result::ResultTrait;
use core::starknet::{
    testing, contract_address_const, EthAddress, ContractAddress, deploy_syscall,
    get_contract_address
};
use evm::backend::starknet_backend;
use evm::model::{Address};

use evm::test_utils::{ca_address, other_starknet_address, chain_id, sequencer_evm_address};
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::constants::BLOCK_GAS_LIMIT;
use utils::eth_transaction::LegacyTransaction;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, start_cheat_sequencer_address_global,
    stop_cheat_caller_address, CheatSpan, start_cheat_caller_address_global
};
use core::starknet::ClassHash;

mod test_upgradeable;

const CLASS_REGISTRY_ADDRESS: felt252 = 0x02398456092472983650923856;

#[starknet::interface]
trait ITestClassRegistry<TContractState> {
    fn get_class_hash(self: @TContractState, class_name: ByteArray) -> ClassHash;
}

#[starknet::contract]
mod TestClassRegistry {
    use core::starknet::ClassHash;
    #[storage]
    struct Storage {
        erc20_class_hash: ClassHash,
        kakarot_core_class_hash: ClassHash,
        account_contract_class_hash: ClassHash,
        uninitialized_account_class_hash: ClassHash
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        erc20_class_hash: ClassHash,
        kakarot_core_class_hash: ClassHash,
        account_contract_class_hash: ClassHash,
        uninitialized_account_class_hash: ClassHash
    ) {
        self.erc20_class_hash.write(erc20_class_hash);
        self.kakarot_core_class_hash.write(kakarot_core_class_hash);
        self.account_contract_class_hash.write(account_contract_class_hash);
        self.uninitialized_account_class_hash.write(uninitialized_account_class_hash);
    }

    #[abi(embed_v0)]
    impl ITestClassRegistry of super::ITestClassRegistry<ContractState> {
        fn get_class_hash(self: @ContractState, class_name: ByteArray) -> ClassHash {
            if class_name == "ERC20" {
                return self.erc20_class_hash.read();
            }
            if class_name == "KakarotCore" {
                return self.kakarot_core_class_hash.read();
            }
            if class_name == "AccountContract" {
                return self.account_contract_class_hash.read();
            }
            if class_name == "UninitializedAccount" {
                return self.uninitialized_account_class_hash.read();
            }
            return 0.try_into().unwrap();
        }
    }
}

fn class_registry() -> ITestClassRegistryDispatcher {
    let maybe_class_registry = declare("TestClassRegistry");
    if maybe_class_registry.is_err() {
        return ITestClassRegistryDispatcher {
            contract_address: CLASS_REGISTRY_ADDRESS.try_into().unwrap()
        };
    };
    let class_registry = maybe_class_registry.unwrap();
    let erc20_class_hash = declare("ERC20").unwrap().class_hash;
    let kakarot_core_class_hash = declare("KakarotCore").unwrap().class_hash;
    let account_contract_class_hash = declare("AccountContract").unwrap().class_hash;
    let uninitialized_account_class_hash = declare("UninitializedAccount").unwrap().class_hash;

    let calldata = array![
        erc20_class_hash.into(),
        kakarot_core_class_hash.into(),
        account_contract_class_hash.into(),
        uninitialized_account_class_hash.into()
    ];

    class_registry
        .deploy_at(@calldata, CLASS_REGISTRY_ADDRESS.try_into().unwrap())
        .expect('Class registry not deployed');
    let class_registry = ITestClassRegistryDispatcher {
        contract_address: CLASS_REGISTRY_ADDRESS.try_into().unwrap()
    };
    class_registry
}

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
    let class = class_registry().get_class_hash("ERC20");
    let maybe_address = deploy_syscall(class, 0, calldata.span(), false);
    match maybe_address {
        Result::Ok((contract_address, _)) => { IERC20CamelDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

fn deploy_kakarot_core(
    native_token: ContractAddress, mut eoas: Span<EthAddress>
) -> IExtendedKakarotCoreDispatcher {
    let account_contract_class_hash = class_registry().get_class_hash("AccountContract");
    let uninitialized_account_class_hash = class_registry().get_class_hash("UninitializedAccount");
    let kakarot_core_class_hash = class_registry().get_class_hash("KakarotCore");
    let mut calldata: Array<felt252> = array![
        other_starknet_address().into(),
        native_token.into(),
        account_contract_class_hash.into(),
        uninitialized_account_class_hash.into(),
        'coinbase',
        BLOCK_GAS_LIMIT.into(),
    ];

    Serde::serialize(@eoas, ref calldata);

    let maybe_address = deploy_syscall(
        kakarot_core_class_hash.try_into().unwrap(), 0, calldata.span(), false
    );

    match maybe_address {
        Result::Ok((
            contract_address, _
        )) => { IExtendedKakarotCoreDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

pub(crate) fn deploy_contract_account(evm_address: EthAddress, bytecode: Span<u8>) -> Address {
    let ca_address = starknet_backend::deploy(evm_address).expect('failed to deploy CA');
    IAccountDispatcher { contract_address: ca_address.starknet }.set_nonce(1);
    IAccountDispatcher { contract_address: ca_address.starknet }.write_bytecode(bytecode);
    ca_address
}

fn deploy_eoa(evm_address: EthAddress) -> IAccountDispatcher {
    let eoa_address = starknet_backend::deploy(evm_address).expect('failed to deploy EOA');

    let eoa = IAccountDispatcher { contract_address: eoa_address.starknet };
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

    // We drop the first event of Kakarot Core, as it is the initializer from Ownable,
    // triggered in the constructor.
    drop_event(kakarot_core.contract_address);

    let sequencer: EthAddress = sequencer_evm_address();

    let sequencer_sn_address = kakarot_core.address_registry(sequencer);
    // We drop the event of the EOA deployment
    drop_event(kakarot_core.contract_address);
    start_cheat_sequencer_address_global(sequencer_sn_address);
    start_cheat_caller_address_global(kakarot_core.contract_address);
    return (native_token, kakarot_core);
}
