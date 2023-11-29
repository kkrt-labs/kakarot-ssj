use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};

use contracts::tests::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
use core::box::BoxTrait;
use core::nullable::NullableTrait;
use core::result::ResultTrait;
use core::traits::Destruct;
use core::traits::TryInto;


use evm::call_helpers::{MachineCallHelpers, CallType, CallArgs};
use evm::machine::Machine;
use evm::machine::MachineTrait;
use evm::model::{Address, account::{AccountBuilderTrait}, eoa::EOATrait};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{MachineBuilderTestTrait, test_address, other_evm_address};
use starknet::testing::set_contract_address;
use starknet::{contract_address_const, EthAddress, ContractAddress};

struct TestSetupValues {
    gas: u128,
    address: EthAddress,
    value: Option::<u256>,
    args_offset: u256,
    args_size: u256,
    ret_offset: usize,
    ret_size: usize,
    caller_address: Address
}

fn prep_machine_prepare_call_test(
    call_type: CallType, kakarot_core_address: ContractAddress
) -> (Machine, TestSetupValues) {
    let kakarot_core = IExtendedKakarotCoreDispatcher { contract_address: kakarot_core_address };
    let caller_address = EthAddress { address: 0xabde2 };
    let caller_address = Address {
        evm: caller_address, starknet: kakarot_core.compute_starknet_address(caller_address)
    };

    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_caller(caller_address)
        .build();

    let gas: u128 = 1000;
    let address = other_evm_address();
    let args_offset = 5;
    let args_size = 1;
    let ret_offset: usize = 15;
    let ret_size: usize = 20;

    machine.stack.push(ret_size.into()).unwrap();
    machine.stack.push(ret_offset.into()).unwrap();
    machine.stack.push(args_size).unwrap();
    machine.stack.push(args_offset).unwrap();

    let value = match call_type {
        CallType::Call => {
            let value = 100;
            machine.stack.push(value).unwrap();
            Option::Some(value)
        },
        CallType::DelegateCall => { Option::None },
        CallType::CallCode => {
            let value = 100;
            machine.stack.push(value).unwrap();
            Option::Some(value)
        },
        CallType::StaticCall => { Option::None },
    };

    machine.stack.push(address.address.into()).unwrap();
    machine.stack.push(gas.into()).unwrap();

    (
        machine,
        TestSetupValues {
            gas, address, value, args_offset, args_size, ret_offset, ret_size, caller_address
        }
    )
}

#[test]
fn test_prepare_call_type_call() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut machine,
        TestSetupValues{gas,
        address,
        value,
        args_offset: _,
        args_size: _,
        ret_offset,
        ret_size,
        caller_address: _ }
    ) =
        prep_machine_prepare_call_test(
        CallType::Call, kakarot_core.contract_address
    );

    let expected_call_args = CallArgs {
        caller: test_address(),
        code_address: Address {
            evm: address, starknet: kakarot_core.compute_starknet_address(address)
        },
        to: Address { evm: address, starknet: kakarot_core.compute_starknet_address(address) },
        gas,
        value: value.unwrap(),
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: true
    };

    let call_args = machine.prepare_call(@CallType::Call).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}

#[test]
fn test_prepare_call_type_delegate_call() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut machine,
        TestSetupValues{gas,
        address,
        value: _,
        args_offset: _,
        args_size: _,
        ret_offset,
        ret_size,
        caller_address }
    ) =
        prep_machine_prepare_call_test(
        CallType::DelegateCall, kakarot_core.contract_address
    );

    let expected_call_args = CallArgs {
        caller: caller_address,
        code_address: Address {
            evm: address, starknet: kakarot_core.compute_starknet_address(address)
        },
        to: Address {
            evm: test_address().evm,
            starknet: kakarot_core.compute_starknet_address(test_address().evm)
        },
        gas,
        value: machine.call_ctx().value,
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: false
    };

    let call_args = machine.prepare_call(@CallType::DelegateCall).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}

#[test]
fn test_prepare_call_type_call_code() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut machine,
        TestSetupValues{gas,
        address,
        value,
        args_offset: _,
        args_size: _,
        ret_offset,
        ret_size,
        caller_address: _ }
    ) =
        prep_machine_prepare_call_test(
        CallType::CallCode, kakarot_core.contract_address
    );

    let expected_call_args = CallArgs {
        caller: test_address(),
        code_address: Address {
            evm: address, starknet: kakarot_core.compute_starknet_address(address)
        },
        to: Address {
            evm: test_address().evm,
            starknet: kakarot_core.compute_starknet_address(test_address().evm)
        },
        gas,
        value: value.unwrap(),
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: false
    };

    let call_args = machine.prepare_call(@CallType::CallCode).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}

#[test]
fn test_prepare_call_type_static_call() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut machine,
        TestSetupValues{gas,
        address,
        value: _,
        args_offset: _,
        args_size: _,
        ret_offset,
        ret_size,
        caller_address: _ }
    ) =
        prep_machine_prepare_call_test(
        CallType::StaticCall, kakarot_core.contract_address
    );

    let expected_call_args = CallArgs {
        caller: test_address(),
        code_address: Address {
            evm: address, starknet: kakarot_core.compute_starknet_address(address)
        },
        to: Address {
            evm: other_evm_address(),
            starknet: kakarot_core.compute_starknet_address(other_evm_address())
        },
        gas,
        value: 0,
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: false
    };

    let call_args = machine.prepare_call(@CallType::StaticCall).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}


#[test]
fn test_init_call_sub_ctx() {
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    set_contract_address(kakarot_core.contract_address);

    let caller_address = EthAddress { address: 0xabde2 };
    let caller_address = Address {
        evm: caller_address, starknet: kakarot_core.compute_starknet_address(caller_address)
    };

    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_caller(caller_address)
        .build();

    let gas: u128 = 1000;
    let address = other_evm_address();
    let value = 100;
    let ret_offset: usize = 15;
    let ret_size: usize = 20;

    let call_args = CallArgs {
        caller: test_address(),
        code_address: Address {
            evm: address, starknet: kakarot_core.compute_starknet_address(address)
        },
        to: Address { evm: address, starknet: kakarot_core.compute_starknet_address(address) },
        gas,
        value,
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: true
    };

    let sender_eoa = EOATrait::deploy(machine.address().evm).expect('failed deploying sender');
    fund_account_with_native_token(sender_eoa.starknet, native_token, 0x10000);

    EOATrait::deploy(address).expect('failed deploying reciever');

    let ctx_count_prev = machine.ctx_count;
    let sender_balance_prev = machine.state.get_account(sender_eoa.evm).balance;
    let reciver_balance_prev = machine.state.get_account(address).balance;

    machine.init_call_sub_ctx(call_args, machine.call_ctx().read_only).unwrap();

    let ctx_count_after = machine.ctx_count;
    let sender_balance_after = machine.state.get_account(sender_eoa.evm).balance;
    let reciver_balance_after = machine.state.get_account(address).balance;

    assert!(
        machine
            .address() == Address {
                evm: address, starknet: kakarot_core.compute_starknet_address(address)
            },
        "wrong execution context address"
    );

    assert!(sender_balance_prev - sender_balance_after == 100, "wrong sender balance");
    assert!(reciver_balance_after - reciver_balance_prev == 100, "wrong reciever balance");

    assert!(ctx_count_after - ctx_count_prev == 1, "ctx count increased by wrong value");
}
