use contracts::tests::test_data::counter_evm_bytecode;
use contracts::tests::test_utils as contract_utils;
use evm::execution::execute;
use evm::model::Transfer;
use evm::model::eoa::EOATrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{ca_address, evm_address, other_evm_address};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::testing::{set_caller_address, set_contract_address};
#[test]
#[available_gas(20000000)]
fn test_execute_value_transfer() {
    let native_token = contract_utils::deploy_native_token();
    // Transfer native tokens to sender
    let kakarot_core = contract_utils::deploy_kakarot_core(native_token.contract_address);
    set_contract_address(kakarot_core.contract_address);
    let sender = EOATrait::deploy(evm_address()).expect('sender deploy failed');
    let recipient = EOATrait::deploy(other_evm_address()).expect('recipient deploy failed');
    // Transfer native tokens to sender
    contract_utils::fund_account_with_native_token(sender.starknet_address, native_token, 10000);
    // When
    let mut exec_result = execute(
        origin: sender.evm_address,
        target: recipient.evm_address,
        bytecode: Default::default().span(),
        calldata: Default::default().span(),
        value: 2000,
        gas_price: 0,
        gas_limit: 0,
        read_only: false,
    );
    // `commit_state` is applied in `eth_send_tx` only - to test that `execute` worked correctly, we manually apply it here.
    exec_result.state.commit_state();

    let sender_balance = native_token.balanceOf(sender.starknet_address);
    let recipient_balance = native_token.balanceOf(recipient.starknet_address);

    assert(sender_balance == 8000, 'wrong sender balance');
    assert(recipient_balance == 2000, 'wrong recipient balance');
}
