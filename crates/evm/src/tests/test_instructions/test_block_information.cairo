use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};

use contracts::tests::test_utils::{
    setup_contracts_for_testing, fund_account_with_native_token, deploy_contract_account,
};
use core::clone::Clone;
use core::result::ResultTrait;
use core::traits::TryInto;
use evm::instructions::BlockInformationTrait;
use evm::model::contract_account::ContractAccountTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{evm_address, VMBuilderTrait, gas_limit, gas_price};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::{
    set_block_timestamp, set_block_number, set_contract_address, set_sequencer_address,
    ContractAddress
};

/// 0x40 - BLOCKHASH
#[test]
fn test_exec_blockhash_below_bounds() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    set_block_number(500);

    // When
    vm.stack.push(243).expect('push failed');
    vm.exec_blockhash().unwrap();

    // Then
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
fn test_exec_blockhash_above_bounds() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    set_block_number(500);

    // When
    vm.stack.push(491).expect('push failed');
    vm.exec_blockhash().unwrap();

    // Then
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}

// TODO: implement exec_blockhash testing for block number within bounds
// https://github.com/starkware-libs/cairo/blob/77a7e7bc36aa1c317bb8dd5f6f7a7e6eef0ab4f3/crates/cairo-lang-starknet/cairo_level_tests/interoperability.cairo#L173
#[test]
fn test_exec_blockhash_within_bounds() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    set_block_number(500);

    // When
    vm.stack.push(244).expect('push failed');

    //TODO the CASM runner used in tests doesn't implement
    //`get_block_hash_syscall` yet. As such, this test should fail no if the
    //queried block is within bounds
    assert(vm.exec_blockhash().is_err(), 'CASM Runner cant blockhash');
// Then
// assert(vm.stack.peek().unwrap() == 0xF, 'stack top should be 0xF');
}


#[test]
fn test_block_timestamp_set_to_1692873993() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // 24/08/2023 12h46 33s
    // If not set the default timestamp is 0.
    set_block_timestamp(1692873993);
    // When
    vm.exec_timestamp().unwrap();

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 1692873993, 'stack top should be 1692873993');
}

#[test]
fn test_block_number_set_to_32() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // If not set the default block number is 0.
    set_block_number(32);
    // When
    vm.exec_number().unwrap();

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 32, 'stack top should be 32');
}

#[test]
fn test_gaslimit() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // When
    vm.exec_gaslimit().unwrap();

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    // This value is set in [new_with_presets].
    assert(vm.stack.peek().unwrap() == gas_limit().into(), 'stack top should be gas_limit');
}

// *************************************************************************
// 0x47: SELFBALANCE
// *************************************************************************
#[test]
fn test_exec_selfbalance_eoa() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let eoa = kakarot_core.deploy_eoa(evm_address());

    fund_account_with_native_token(eoa, native_token, 0x1);

    // And
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    set_contract_address(kakarot_core.contract_address);
    vm.exec_selfbalance().unwrap();

    // Then
    assert(vm.stack.peek().unwrap() == native_token.balanceOf(eoa), 'wrong balance');
}

#[test]
fn test_exec_selfbalance_zero() {
    // Given
    let (_, kakarot_core) = setup_contracts_for_testing();

    // And
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    set_contract_address(kakarot_core.contract_address);
    vm.exec_selfbalance().unwrap();

    // Then
    assert(vm.stack.peek().unwrap() == 0x00, 'wrong balance');
}

#[test]
fn test_exec_selfbalance_contract_account() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let mut ca_address = deploy_contract_account(evm_address(), array![].span());

    fund_account_with_native_token(ca_address.starknet, native_token, 0x1);
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    set_contract_address(kakarot_core.contract_address);
    vm.exec_selfbalance().unwrap();

    // Then
    assert(vm.stack.peek().unwrap() == 0x1, 'wrong balance');
}


#[test]
fn test_basefee() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // When
    vm.exec_basefee().unwrap();

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == gas_price().into(), 'stack top should be gas_price');
}

#[test]
fn test_chainid_should_push_chain_id_to_stack() {
    let (_, kakarot_core) = setup_contracts_for_testing();

    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let chain_id: u256 = IExtendedKakarotCoreDispatcher {
        contract_address: kakarot_core.contract_address
    }
        .chain_id()
        .into();

    // When
    vm.exec_chainid().unwrap();

    // Then
    let result = vm.stack.peek().unwrap();
    assert(result == chain_id, 'stack should have chain id');
}


#[test]
fn test_randao_should_push_zero_to_stack() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    vm.exec_prevrandao().unwrap();

    // Then
    let result = vm.stack.peek().unwrap();
    assert(result == 0x00, 'stack top should be zero');
}

// *************************************************************************
// 0x41: COINBASE
// *************************************************************************
#[test]
fn test_exec_coinbase() {
    // Given
    let (_, kakarot_core) = setup_contracts_for_testing();
    let sequencer_eoa = kakarot_core.deploy_eoa(evm_address());

    // And
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    set_sequencer_address(sequencer_eoa);
    vm.exec_coinbase().unwrap();

    let sequencer_address = vm.stack.pop().unwrap();

    // Then
    assert(evm_address().address.into() == sequencer_address, 'wrong sequencer_address');
}
