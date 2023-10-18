use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::utils::{
    deploy_kakarot_core, deploy_native_token, fund_account_with_native_token
};
use evm::instructions::BlockInformationTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{setup_machine, evm_address};
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::{set_block_timestamp, set_block_number, set_contract_address};
use utils::constants::CHAIN_ID;

/// 0x40 - BLOCKHASH
#[test]
#[available_gas(20000000)]
fn test_block_hash_below_bounds() {
    // Given
    let mut machine = setup_machine();

    set_block_number(500);

    // When
    machine.stack.push(243).unwrap();
    machine.exec_blockhash();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'stack top should be 1692873993');
}

#[test]
#[available_gas(20000000)]
fn test_block_hash_above_bounds() {
    // Given
    let mut machine = setup_machine();

    set_block_number(500);

    // When
    machine.stack.push(491).unwrap();
    machine.exec_blockhash();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'stack top should be 1692873993');
}

// TODO: implement exec_blockhash testing for block number within bounds
// https://github.com/starkware-libs/cairo/blob/77a7e7bc36aa1c317bb8dd5f6f7a7e6eef0ab4f3/crates/cairo-lang-starknet/cairo_level_tests/interoperability.cairo#L173
#[ignore]
#[test]
#[available_gas(20000000)]
fn test_block_hash_within_bounds() {
    // Given
    let mut machine = setup_machine();

    set_block_number(500);

    // When
    machine.stack.push(244).unwrap();
    machine.exec_blockhash();
    // Then
    assert(machine.stack.peek().unwrap() == 0xF, 'stack top should be 0xF');
}


#[test]
#[available_gas(20000000)]
fn test_block_timestamp_set_to_1692873993() {
    // Given
    let mut machine = setup_machine();
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
    let mut machine = setup_machine();
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
    let mut machine = setup_machine();
    // When
    machine.exec_gaslimit();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    // This value is set in [setup_execution_context].
    assert(machine.stack.peek().unwrap() == 0xffffff, 'stack top should be 0xffffff');
}

// *************************************************************************
// 0x47: SELFBALANCE
// *************************************************************************
#[test]
#[available_gas(5000000)]
fn test_exec_selfbalance_eoa() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    let eoa = kakarot_core.deploy_eoa(evm_address());

    fund_account_with_native_token(eoa, native_token);

    // And
    let mut machine = setup_machine();

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
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);

    // And
    let mut machine = setup_machine();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_selfbalance();

    // Then
    assert(machine.stack.peek().unwrap() == 0x00, 'wrong balance');
}

// TODO: implement balance once contracts accounts can be deployed
#[ignore]
#[test]
#[available_gas(5000000)]
fn test_exec_selfbalance_contract_account() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    // TODO: deploy contract account
    // and fund it

    // And
    let mut machine = setup_machine();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_selfbalance();

    // Then
    panic_with_felt252('Not implemented yet');
}


#[test]
#[available_gas(20000000)]
fn test_basefee() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.exec_basefee();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 0xaaaaaa, 'stack top should be 0xaaaaaa');
}

#[test]
#[available_gas(20000000)]
fn test_chainid_should_push_chain_id_to_stack() {
    // Given
    let mut machine = setup_machine();

    // CHAIN_ID = KKRT (0x4b4b5254) in ASCII
    // TODO: Replace the hardcoded value by a value set in kakarot main contract constructor
    let chain_id: u256 = CHAIN_ID;

    // When
    machine.exec_chainid();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(result == chain_id, 'stack should have chain id');
}
