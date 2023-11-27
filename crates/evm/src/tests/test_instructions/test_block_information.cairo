use contracts::kakarot_core::interface::{
    IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
};

use contracts::tests::test_utils::{
    setup_contracts_for_testing, fund_account_with_native_token, deploy_contract_account
};
use evm::instructions::BlockInformationTrait;
use evm::model::contract_account::ContractAccountTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{evm_address, MachineBuilderTestTrait};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::{set_block_timestamp, set_block_number, set_contract_address};

/// 0x40 - BLOCKHASH
#[test]
#[available_gas(20000000)]
fn test_exec_blockhash_below_bounds() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    set_block_number(500);

    // When
    machine.stack.push(243).unwrap();
    machine.exec_blockhash();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_blockhash_above_bounds() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    set_block_number(500);

    // When
    machine.stack.push(491).unwrap();
    machine.exec_blockhash();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'stack top should be 0');
}

// TODO: implement exec_blockhash testing for block number within bounds
// https://github.com/starkware-libs/cairo/blob/77a7e7bc36aa1c317bb8dd5f6f7a7e6eef0ab4f3/crates/cairo-lang-starknet/cairo_level_tests/interoperability.cairo#L173
#[test]
#[available_gas(20000000)]
fn test_exec_blockhash_within_bounds() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    set_block_number(500);

    // When
    machine.stack.push(244).unwrap();

    //TODO the CASM runner used in tests doesn't implement
    //`get_block_hash_syscall` yet. As such, this test should fail no if the
    //queried block is within bounds
    assert(machine.exec_blockhash().is_err(), 'CASM Runner cant blockhash');
// Then
// assert(machine.stack.peek().unwrap() == 0xF, 'stack top should be 0xF');
}


#[test]
#[available_gas(20000000)]
fn test_block_timestamp_set_to_1692873993() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();
    // 24/08/2023 12h46 33s
    // If not set the default timestamp is 0.
    set_block_timestamp(1692873993);
    // When
    machine.exec_timestamp();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 1692873993, 'stack top should be 1692873993');
}

#[test]
#[available_gas(20000000)]
fn test_block_number_set_to_32() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();
    // If not set the default block number is 0.
    set_block_number(32);
    // When
    machine.exec_number();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 32, 'stack top should be 32');
}

#[test]
#[available_gas(20000000)]
fn test_gaslimit() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();
    // When
    machine.exec_gaslimit();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    // This value is set in [new_with_presets].
    assert(machine.stack.peek().unwrap() == 0xffffff, 'stack top should be 0xffffff');
}

// *************************************************************************
// 0x47: SELFBALANCE
// *************************************************************************
#[test]
#[available_gas(5000000)]
fn test_exec_selfbalance_eoa() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let eoa = kakarot_core.deploy_eoa(evm_address());

    fund_account_with_native_token(eoa, native_token, 0x1);

    // And
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_selfbalance();

    // Then
    assert(machine.stack.peek().unwrap() == native_token.balanceOf(eoa), 'wrong balance');
}

#[test]
#[available_gas(5000000)]
fn test_exec_selfbalance_zero() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    // And
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_selfbalance();

    // Then
    assert(machine.stack.peek().unwrap() == 0x00, 'wrong balance');
}

#[test]
#[available_gas(5000000)]
fn test_exec_selfbalance_contract_account() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let mut ca_address = deploy_contract_account(evm_address(), array![].span());

    fund_account_with_native_token(ca_address.starknet, native_token, 0x1);
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_selfbalance();

    // Then
    assert(machine.stack.peek().unwrap() == 0x1, 'wrong balance');
}


#[test]
#[available_gas(20000000)]
fn test_basefee() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();
    // When
    machine.exec_basefee();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 0xaaaaaa, 'stack top should be 0xaaaaaa');
}

#[test]
#[available_gas(20000000)]
fn test_chainid_should_push_chain_id_to_stack() {
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let chain_id: u256 = IExtendedKakarotCoreDispatcher {
        contract_address: kakarot_core.contract_address
    }
        .chain_id()
        .into();

    // When
    machine.exec_chainid();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(result == chain_id, 'stack should have chain id');
}


#[test]
#[available_gas(20000000)]
fn test_randao_should_push_zero_to_stack() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    machine.exec_prevrandao().unwrap();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(result == 0x00, 'stack top should be zero');
}
