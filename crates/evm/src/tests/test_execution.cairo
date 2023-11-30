//TODO(migration) - convert to new architecture
// use contracts::tests::test_utils as contract_utils;
// use core::traits::TryInto;
// use evm::errors::{EVMError, EVMErrorTrait, STACK_OVERFLOW};
// use evm::execution::execute;
// use evm::interpreter::{EVMInterpreter, EVMInterpreterTrait};
// use evm::machine::{MachineTrait};
// use evm::model::eoa::EOATrait;
// use evm::stack::StackTrait;
// use evm::state::StateTrait;
// use evm::tests::test_utils::{evm_address, other_evm_address, VMBuilderTrait};
// use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
// use starknet::testing::set_nonce;
// use utils::helpers::U256Trait;
// use utils::traits::EthAddressIntoU256;

// #[test]
// fn test_execute_value_transfer() {
//     let (native_token, _) = contract_utils::setup_contracts_for_testing();
//     // Transfer native tokens to sender
//     let sender = EOATrait::deploy(evm_address()).expect('sender deploy failed');
//     let recipient = EOATrait::deploy(other_evm_address()).expect('recipient deploy failed');
//     // Transfer native tokens to sender
//     contract_utils::fund_account_with_native_token(sender.starknet, native_token, 10000);
//     // When
//     let mut exec_result = execute(
//         origin: sender,
//         target: recipient,
//         calldata: Default::default().span(),
//         value: 2000,
//         gas_price: 0,
//         gas_limit: 0,
//         read_only: false,
//         is_deploy_tx: false,
//     );
//     // `commit_state` is applied in `eth_send_tx` only - to test that `execute` worked correctly, we manually apply it here.
//     exec_result.state.commit_state().expect('commit state failed');

//     let sender_balance = native_token.balanceOf(sender.starknet);
//     let recipient_balance = native_token.balanceOf(recipient.starknet);

//     assert(sender_balance == 8000, 'wrong sender balance');
//     assert(recipient_balance == 2000, 'wrong recipient balance');
// }

// #[test]
// fn test_run_evm_error_revert() {
//     contract_utils::setup_contracts_for_testing();
//     // PUSH1 0x01
//     let mut bytecode = array![0x60, 0x01].span();
//     let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
//     let mut interpreter = EVMInterpreter {};
//     // When - stack already full
//     vm.stack.len.insert(0, 1024);
//     interpreter.run(ref machine);

//     assert_eq!(machine.reverted(), true);
//     let error = machine.return_data();
//     assert(
//         error == Into::<felt252, u256>::into(STACK_OVERFLOW).to_bytes(), 'expected stack overflow',
//     );
// }

// #[test]
// fn test_run_evm_error_revert_subcontext() {
//     let mut interpreter = EVMInterpreter {};
//     contract_utils::setup_contracts_for_testing();
//     // Set machine bytecode
//     // (call 0xffffff 0x100 0 0 0 0 1)
//     let bytecode = array![
//         0x60,
//         0x01,
//         0x60,
//         0x00,
//         0x60,
//         0x00,
//         0x60,
//         0x00,
//         0x60,
//         0x00,
//         0x61,
//         0x01,
//         0x00,
//         0x62,
//         0xff,
//         0xff,
//         0xff,
//         // CALL
//         0xf1,
//         0x60, // PUSH1 0x69 (value)
//         0x01,
//         0x60, // PUSH1 0x01 (key)
//         0x69,
//         0x55, // SSTORE
//         0x00 //STOP
//     ]
//         .span();
//     // we need to deploy this account so that it's usable directly by the machine
//     let mut _caller_account = contract_utils::deploy_contract_account(evm_address(), bytecode);
//     let mut _called_account = contract_utils::deploy_contract_account(
//         other_evm_address(), array![0xFD].span() // REVERT
//     );

//     let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();

//     interpreter.run(ref machine);

//     vm.env.state.commit_state().expect('failed to commit state');
//     assert_eq!(vm.env.state.read_state(evm_address(), 0x69).expect('couldnt read state'), 0x01);
//     let error = machine.return_data();
//     assert_eq!(error.len(), 0);
// }

// #[test]
// fn test_run_evm_opcopde_revert() {
//     contract_utils::setup_contracts_for_testing();
//     let mut interpreter = EVMInterpreter {};

//     // MSTORE 0 1000 - REVERT 0 32
//     let mut bytecode = array![0x52, 0xFD].span();
//     let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(bytecode).build();
//     vm.stack.push(32).expect('push failed');
//     vm.stack.push(0).expect('push failed');
//     vm.stack.push(1000).expect('push failed');
//     vm.stack.push(0).expect('push failed');
//     interpreter.run(ref machine);

//     assert_eq!(machine.reverted(), true);
//     let error = machine.return_data();
//     assert(error == 1000.to_bytes(), 'expected error == 1000',);
// }


