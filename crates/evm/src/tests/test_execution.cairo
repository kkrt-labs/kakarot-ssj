use contracts::tests::test_utils as contract_utils;
use evm::errors::{EVMError, EVMErrorTrait, STACK_OVERFLOW};
use evm::execution::execute;
use evm::interpreter::{EVMInterpreter, EVMInterpreterTrait};
use evm::machine::{MachineTrait};
use evm::model::eoa::EOATrait;
use evm::stack::StackTrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{evm_address, other_evm_address, MachineBuilderTestTrait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::testing::set_nonce;
use utils::helpers::U256Trait;

#[test]
fn test_execute_value_transfer() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
    // Transfer native tokens to sender
    let sender = EOATrait::deploy(evm_address()).expect('sender deploy failed');
    let recipient = EOATrait::deploy(other_evm_address()).expect('recipient deploy failed');
    // Transfer native tokens to sender
    contract_utils::fund_account_with_native_token(sender.starknet, native_token, 10000);
    // When
    let mut exec_result = execute(
        origin: sender,
        target: recipient,
        calldata: Default::default().span(),
        value: 2000,
        gas_price: 0,
        gas_limit: 0,
        read_only: false,
        is_deploy_tx: false,
    );
    // `commit_state` is applied in `eth_send_tx` only - to test that `execute` worked correctly, we manually apply it here.
    exec_result.state.commit_state();

    let sender_balance = native_token.balanceOf(sender.starknet);
    let recipient_balance = native_token.balanceOf(recipient.starknet);

    assert(sender_balance == 8000, 'wrong sender balance');
    assert(recipient_balance == 2000, 'wrong recipient balance');
}

#[test]
fn test_run_evm_error_revert() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
    // Transfer native tokens to sender
    let sender = EOATrait::deploy(evm_address()).expect('sender deploy failed');
    let recipient = EOATrait::deploy(other_evm_address()).expect('recipient deploy failed');
    // Transfer native tokens to sender
    contract_utils::fund_account_with_native_token(sender.starknet, native_token, 10000);
    // PUSH1 0x01
    let mut bytecode = array![0x60, 0x01].span();
    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();
    let mut interpreter = EVMInterpreter {};
    // When - stack already full
    machine.stack.len.insert(0, 1024);
    interpreter.run(ref machine);

    assert_eq!(machine.reverted(), true);
    let error = machine.return_data();
    assert(
        error == Into::<felt252, u256>::into(STACK_OVERFLOW).to_bytes(), 'expected stack overflow',
    );
}


#[test]
fn test_run_evm_opcopde_revert() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();
    // Transfer native tokens to sender
    let sender = EOATrait::deploy(evm_address()).expect('sender deploy failed');
    let recipient = EOATrait::deploy(other_evm_address()).expect('recipient deploy failed');
    // Transfer native tokens to sender
    contract_utils::fund_account_with_native_token(sender.starknet, native_token, 10000);
    let mut interpreter = EVMInterpreter {};

    // MSTORE 0 1000 - REVERT 0 32
    let mut bytecode = array![0x52, 0xFD].span();
    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();
    machine.stack.push(32);
    machine.stack.push(0);
    machine.stack.push(1000);
    machine.stack.push(0);
    interpreter.run(ref machine);

    assert_eq!(machine.reverted(), true);
    let error = machine.return_data();
    assert(error == 1000.to_bytes(), 'expected error == 1000',);
}
