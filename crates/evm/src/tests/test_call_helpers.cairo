use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};

use contracts::tests::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
use core::box::BoxTrait;
use core::nullable::NullableTrait;
use core::result::ResultTrait;
use core::traits::Destruct;
use core::traits::TryInto;

use evm::call_helpers::{CallHelpers, CallType, CallArgs};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Address, account::{AccountBuilderTrait}, eoa::EOATrait};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{VMBuilderTrait, test_address, other_evm_address, caller};
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
) -> (VM, TestSetupValues) {
    let kakarot_core = IExtendedKakarotCoreDispatcher { contract_address: kakarot_core_address };
    let caller_address = EthAddress { address: 0xabde2 };
    let caller_address = Address {
        evm: caller_address, starknet: kakarot_core.compute_starknet_address(caller_address)
    };

    let mut vm = VMBuilderTrait::new_with_presets().with_caller(caller_address).build();

    let gas: u128 = 1000;
    let address = other_evm_address();
    let args_offset = 5;
    let args_size = 1;
    let ret_offset: usize = 15;
    let ret_size: usize = 20;

    vm.stack.push(ret_size.into()).unwrap();
    vm.stack.push(ret_offset.into()).unwrap();
    vm.stack.push(args_size).unwrap();
    vm.stack.push(args_offset).unwrap();

    let value = match call_type {
        CallType::Call => {
            let value = 100;
            vm.stack.push(value).unwrap();
            Option::Some(value)
        },
        CallType::DelegateCall => { Option::None },
        CallType::CallCode => {
            let value = 100;
            vm.stack.push(value).unwrap();
            Option::Some(value)
        },
        CallType::StaticCall => { Option::None },
    };

    vm.stack.push(address.address.into()).unwrap();
    vm.stack.push(gas.into()).unwrap();

    (
        vm,
        TestSetupValues {
            gas, address, value, args_offset, args_size, ret_offset, ret_size, caller_address
        }
    )
}

#[test]
fn test_prepare_call_type_call() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut vm,
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
        should_transfer: true,
        read_only: false
    };

    let call_args = vm.prepare_call(@CallType::Call).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}

#[test]
fn test_prepare_call_type_delegate_call() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut vm,
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
        value: vm.message().value,
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: false,
        read_only: false
    };

    let call_args = vm.prepare_call(@CallType::DelegateCall).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}

#[test]
fn test_prepare_call_type_call_code() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut vm,
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
        should_transfer: false,
        read_only: false
    };

    let call_args = vm.prepare_call(@CallType::CallCode).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}

#[test]
fn test_prepare_call_type_static_call() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    let (
        mut vm,
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
        should_transfer: false,
        read_only: true
    };

    let call_args = vm.prepare_call(@CallType::StaticCall).unwrap();

    assert!(call_args == expected_call_args, "wrong calls_args prepared");
}
#[test]
#[ignore]
fn test_generic_call() {
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    set_contract_address(kakarot_core.contract_address);

    let caller_address = caller();
    let caller_address = Address {
        evm: caller_address, starknet: kakarot_core.compute_starknet_address(caller_address)
    };

    let mut vm = VMBuilderTrait::new_with_presets().with_caller(caller_address).build();

    let gas: u128 = 1000;
    let target_address = other_evm_address();
    let value = 100;
    let ret_offset: usize = 15;
    let ret_size: usize = 20;
    let target = Address {
        evm: target_address, starknet: kakarot_core.compute_starknet_address(target_address)
    };

    let call_args = CallArgs {
        caller: caller_address,
        code_address: target,
        to: target,
        gas,
        value,
        calldata: array![0x0].span(),
        ret_offset,
        ret_size,
        should_transfer: true,
        read_only: false
    };

    let sender_eoa = kakarot_core.deploy_eoa(caller_address.evm);
    fund_account_with_native_token(sender_eoa, native_token, 1000);

    let receiver_eoa = kakarot_core.deploy_eoa(target.evm);

    let sender_balance_prev = vm.env.state.get_account(caller_address.evm).balance;
    let receiver_balance_prev = vm.env.state.get_account(target.evm).balance;

    //     machine.init_call_sub_ctx(call_args, machine.call_ctx().read_only).unwrap();

    let sender_balance_after = vm.env.state.get_account(caller_address.evm).balance;
    let receiver_balance_after = vm.env.state.get_account(target.evm).balance;

    assert_eq!(vm.stack.peek().expect('stack empty'), 1);

    // No return data for calls to EOAs - only value transfers
    assert_eq!(vm.return_data().len(), 0);
    assert_eq!(sender_balance_prev - sender_balance_after, 100);
    assert_eq!(receiver_balance_after - receiver_balance_prev, 100);
}

