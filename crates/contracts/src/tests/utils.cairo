use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcher, KakarotCore};
use eoa::externally_owned_account::{ExternallyOwnedAccount};
use evm::tests::test_utils::{deploy_fee, other_starknet_address, chain_id};
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{testing, contract_address_const, ContractAddress, deploy_syscall};


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
        ExternallyOwnedAccount::TEST_CLASS_HASH.try_into().unwrap(),
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

fn fund_account_with_native_token(
    contract_address: ContractAddress, native_token: IERC20CamelDispatcher
) {
    let amount: u256 = 0x01;
    testing::set_contract_address(constants::ETH_BANK());
    native_token.transfer(contract_address, amount);
}

// Counter Smart Contract Bytecode:
// 0.8.18+commit.87f61d96
// with optimisation enabled (depth 200) (remix.ethereum.org)
// SPDX-License-Identifier: MIT
// pragma solidity >=0.7.0 <0.9.0;

// contract Counter {
//     uint public count;

//     // Function to get the current count
//     function get() public view returns (uint) {
//         return count;
//     }

//     // Function to increment count by 1
//     function inc() public {
//         count += 1;
//     }

//     // Function to decrement count by 1
//     function dec() public {
//         // This function will fail if count = 0
//         count -= 1;
//     }
// }
fn counter_evm_bytecode() -> Span<u8> {
    array![
        0x60,
        0x80,
        0x60,
        0x40,
        0x52,
        0x34,
        0x80,
        0x15,
        0x60,
        0x0f,
        0x57,
        0x60,
        0x00,
        0x80,
        0xfd,
        0x5b,
        0x50,
        0x60,
        0x04,
        0x36,
        0x10,
        0x60,
        0x46,
        0x57,
        0x60,
        0x00,
        0x35,
        0x60,
        0xe0,
        0x1c,
        0x80,
        0x63,
        0x06,
        0x66,
        0x1a,
        0xbd,
        0x14,
        0x60,
        0x4b,
        0x57,
        0x80,
        0x63,
        0x37,
        0x13,
        0x03,
        0xc0,
        0x14,
        0x60,
        0x65,
        0x57,
        0x80,
        0x63,
        0x6d,
        0x4c,
        0xe6,
        0x3c,
        0x14,
        0x60,
        0x6d,
        0x57,
        0x80,
        0x63,
        0xb3,
        0xbc,
        0xfa,
        0x82,
        0x14,
        0x60,
        0x74,
        0x57,
        0x5b,
        0x60,
        0x00,
        0x80,
        0xfd,
        0x5b,
        0x60,
        0x53,
        0x60,
        0x00,
        0x54,
        0x81,
        0x56,
        0x5b,
        0x60,
        0x40,
        0x51,
        0x90,
        0x81,
        0x52,
        0x60,
        0x20,
        0x01,
        0x60,
        0x40,
        0x51,
        0x80,
        0x91,
        0x03,
        0x90,
        0xf3,
        0x5b,
        0x60,
        0x6b,
        0x60,
        0x7a,
        0x56,
        0x5b,
        0x00,
        0x5b,
        0x60,
        0x00,
        0x54,
        0x60,
        0x53,
        0x56,
        0x5b,
        0x60,
        0x6b,
        0x60,
        0x91,
        0x56,
        0x5b,
        0x60,
        0x01,
        0x60,
        0x00,
        0x80,
        0x82,
        0x82,
        0x54,
        0x60,
        0x8a,
        0x91,
        0x90,
        0x60,
        0xb7,
        0x56,
        0x5b,
        0x90,
        0x91,
        0x55,
        0x50,
        0x50,
        0x56,
        0x5b,
        0x60,
        0x01,
        0x60,
        0x00,
        0x80,
        0x82,
        0x82,
        0x54,
        0x60,
        0x8a,
        0x91,
        0x90,
        0x60,
        0xcd,
        0x56,
        0x5b,
        0x63,
        0x4e,
        0x48,
        0x7b,
        0x71,
        0x60,
        0xe0,
        0x1b,
        0x60,
        0x00,
        0x52,
        0x60,
        0x11,
        0x60,
        0x04,
        0x52,
        0x60,
        0x24,
        0x60,
        0x00,
        0xfd,
        0x5b,
        0x80,
        0x82,
        0x01,
        0x80,
        0x82,
        0x11,
        0x15,
        0x60,
        0xc7,
        0x57,
        0x60,
        0xc7,
        0x60,
        0xa1,
        0x56,
        0x5b,
        0x92,
        0x91,
        0x50,
        0x50,
        0x56,
        0x5b,
        0x81,
        0x81,
        0x03,
        0x81,
        0x81,
        0x11,
        0x15,
        0x60,
        0xc7,
        0x57,
        0x60,
        0xc7,
        0x60,
        0xa1,
        0x56,
        0xfe,
        0xa2,
        0x64,
        0x69,
        0x70,
        0x66,
        0x73,
        0x58,
        0x22,
        0x12,
        0x20,
        0xf3,
        0x79,
        0xb9,
        0x08,
        0x9b,
        0x70,
        0xe8,
        0xe0,
        0x0d,
        0xa8,
        0x54,
        0x5f,
        0x9a,
        0x86,
        0xf6,
        0x48,
        0x44,
        0x1f,
        0xdf,
        0x27,
        0xec,
        0xe9,
        0xad,
        0xe2,
        0xc7,
        0x16,
        0x53,
        0xb1,
        0x2f,
        0xb8,
        0x0c,
        0x79,
        0x64,
        0x73,
        0x6f,
        0x6c,
        0x63,
        0x43,
        0x00,
        0x08,
        0x12,
        0x00,
        0x33
    ]
        .span()
}
