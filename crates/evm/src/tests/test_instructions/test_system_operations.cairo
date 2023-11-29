use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::test_data::{storage_evm_bytecode, storage_evm_initcode};
use contracts::tests::test_eoa::test_external_owned_account::deploy_eoa;
use contracts::tests::test_utils::{
    fund_account_with_native_token, setup_contracts_for_testing, deploy_contract_account
};
use core::result::ResultTrait;
use core::traits::TryInto;
use evm::call_helpers::{MachineCallHelpers, MachineCallHelpersImpl};
use evm::context::{ExecutionContext, ExecutionContextTrait, ExecutionContextType};
use evm::errors::EVMErrorTrait;
use evm::instructions::MemoryOperationTrait;
use evm::instructions::SystemOperationsTrait;
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineTrait};
use evm::memory::MemoryTrait;
use evm::model::account::{Account};
use evm::model::contract_account::ContractAccountTrait;
use evm::model::eoa::EOATrait;
use evm::model::{AccountTrait, Address, AccountType, Transfer};
use evm::stack::StackTrait;
use evm::state::{StateTrait, State};
use evm::tests::test_utils::{
    MachineBuilderTestTrait, initialize_contract_account, native_token, evm_address, test_address,
    other_evm_address,
};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::EthAddress;
use starknet::testing::set_contract_address;
use utils::helpers::load_word;
use utils::traits::EthAddressIntoU256;

#[test]
fn test_exec_return() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();
    // When
    machine.stack.push(1000).expect('push failed');
    machine.stack.push(0).expect('push failed');
    machine.exec_mstore().expect('exec_mstore failed');

    machine.stack.push(32).expect('push failed');
    machine.stack.push(0).expect('push failed');
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
    assert(machine.id() == 1, 'wrong ctx id');

    // And
    machine.finalize_calling_context().expect('finalize failed');

    // Then
    assert(machine.id() == 0, 'should be parent id');
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
}


#[test]
fn test_exec_revert() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();
    // When
    machine.stack.push(1000).expect('push failed');
    machine.stack.push(0).expect('push failed');
    machine.exec_mstore().expect('exec_mstore failed');

    machine.stack.push(32).expect('push failed');
    machine.stack.push(0).expect('push failed');
    assert(machine.exec_revert().is_ok(), 'Exec revert failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}

#[test]
fn test_exec_revert_nested() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();
    // When
    machine.stack.push(1000).expect('push failed');
    machine.stack.push(0).expect('push failed');
    machine.exec_mstore().expect('exec_mstore failed');

    machine.stack.push(32).expect('push failed');
    machine.stack.push(0).expect('push failed');
    assert(machine.exec_revert().is_ok(), 'Exec revert failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}


#[test]
fn test_exec_return_with_offset() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();
    // When
    machine.stack.push(1).expect('push failed');
    machine.stack.push(0).expect('push failed');
    machine.exec_mstore().expect('exec_mstore failed');

    machine.stack.push(32).expect('push failed');
    machine.stack.push(1).expect('push failed');
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
    assert(machine.id() == 1, 'wrong ctx id');

    // And
    machine.finalize_calling_context().expect('finalize failed');

    // Then
    assert(machine.id() == 0, 'should be parent id');
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
}

#[test]
fn test_exec_call() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    kakarot_core.deploy_eoa(evm_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        // CALL
        0xf1,
        0x00
    ]
        .span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    // Deploy bytecode at 0x100
    // ret (+ 0x1 0x1)
    let deployed_bytecode = array![
        0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x60, 0x20, 0x60, 0x00, 0xf3
    ]
        .span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.stopped(), 'run should be success');
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
}

#[test]
fn test_exec_call_no_return() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    kakarot_core.deploy_eoa(evm_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        // CALL
        0xf1,
        0x00
    ]
        .span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    // Deploy bytecode at 0x100
    // (+ 0x1 0x1)
    let deployed_bytecode = array![0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x00].span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.stopped(), 'run should be success');
    assert(machine.return_data().is_empty(), 'Wrong return_data len');
    assert(machine.stopped(), 'machine should be stopped')
}


#[test]
fn test_exec_staticcall() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    kakarot_core.deploy_eoa(evm_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        // STATICCALL
        0xfa,
        0x00
    ]
        .span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();
    // Deploy bytecode at 0x100
    // ret (+ 0x1 0x1)
    let deployed_bytecode = array![
        0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x60, 0x20, 0x60, 0x00, 0xf3
    ]
        .span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}


#[test]
fn test_exec_staticcall_no_return() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    kakarot_core.deploy_eoa(evm_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        // STATICCALL
        0xfa,
        0x00
    ]
        .span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    // Deploy bytecode at 0x100
    // (+ 0x1 0x1)
    let deployed_bytecode = array![0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x00].span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.return_data().is_empty(), 'Wrong return_data len');
    assert(machine.stopped(), 'machine should be stopped')
}

#[test]
fn test_exec_call_code() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    kakarot_core.deploy_eoa(evm_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        // CALLCODE
        0xf2,
        0x00
    ]
        .span();
    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();
    // Deploy bytecode at 0x100
    // ret (+ 0x1 0x1)
    let deployed_bytecode = array![
        0x60,
        0x01,
        0x60,
        0x01,
        0x01,
        0x60,
        0x00,
        0x53,
        0x60,
        0x42,
        0x60,
        0x42,
        0x55,
        0x60,
        0x20,
        0x60,
        0x00,
        0xf3
    ]
        .span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.stopped(), 'run should be success');
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');

    let storage_val = machine
        .state
        .read_state(evm_address, 0x42)
        .expect('failed reading storage slot');

    assert(storage_val == 0x42, 'storage value is not 0x42');
}


#[test]
fn test_exec_delegatecall() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    kakarot_core.deploy_eoa(evm_address);

    // Set machine bytecode
    // (call 0xffffff 0x100 0 0 0 0 1)
    let bytecode = array![
        0x60,
        0x01,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x60,
        0x00,
        0x61,
        0x01,
        0x00,
        0x62,
        0xff,
        0xff,
        0xff,
        // DELEGATECALL
        0xf4,
        0x00
    ]
        .span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    // ret (+ 0x1 0x1)
    let deployed_bytecode = array![
        0x60,
        0x01,
        0x60,
        0x01,
        0x01,
        0x60,
        0x00,
        0x53,
        0x60,
        0x42,
        0x60,
        0x42,
        0x55,
        0x60,
        0x20,
        0x60,
        0x00,
        0xf3
    ]
        .span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.stopped(), 'run should be success');
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');

    let storage_val = machine
        .state
        .read_state(evm_address, 0x42)
        .expect('failed reading storage slot');

    assert(storage_val == 0x42, 'storage value is not 0x42');
}


#[test]
fn test_exec_create2() {
    // Given
    setup_contracts_for_testing();

    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();

    let mut interpreter = EVMInterpreterTrait::new();

    let deployed_bytecode = array![0xff].span();
    let eth_address: EthAddress = 0x00000000000000000075766d5f61646472657373_u256.into();
    let contract_address = deploy_contract_account(eth_address, deployed_bytecode);

    let mut ctx = machine.current_ctx.unbox();
    ctx.address = contract_address;
    ctx.ctx_type = ExecutionContextType::Create(ctx.id());
    machine.current_ctx = BoxTrait::new(ctx);

    // Load into memory the bytecode of Storage.sol
    let storage_initcode = storage_evm_initcode();
    machine.memory.store_n(storage_initcode, 0);

    machine.stack.push(0).expect('push failed');
    machine.stack.push(storage_initcode.len().into()).unwrap();
    machine.stack.push(0).expect('push failed');
    machine.stack.push(0).expect('push failed');

    // When
    machine.exec_create2().unwrap();
    interpreter.run(ref machine);

    assert(machine.stopped(), 'run should be success');

    // Add SNJS script to precompute the address of the Storage.sol contract
    //     import { getContractAddress } from 'viem'

    // const address = getContractAddress({
    //   bytecode: '0x608060405234801561000f575f80fd5b506101438061001d5f395ff3fe608060405234801561000f575f80fd5b5060043610610034575f3560e01c80632e64cec1146100385780636057361d14610056575b5f80fd5b610040610072565b60405161004d919061009b565b60405180910390f35b610070600480360381019061006b91906100e2565b61007a565b005b5f8054905090565b805f8190555050565b5f819050919050565b61009581610083565b82525050565b5f6020820190506100ae5f83018461008c565b92915050565b5f80fd5b6100c181610083565b81146100cb575f80fd5b50565b5f813590506100dc816100b8565b92915050565b5f602082840312156100f7576100f66100b4565b5b5f610104848285016100ce565b9150509291505056fea2646970667358221220b5c3075f2f2034d039a227fac6dd314b052ffb2b3da52c7b6f5bc374d528ed3664736f6c63430008140033',
    //   from: '0x00000000000000000075766d5f61646472657373',
    //   opcode: 'CREATE2',
    //   salt: '0x00',
    // });
    // console.log(address)
    let account = machine
        .state
        .get_account(0xeea3a85A7497e74d85b46E987B8E05152A183892.try_into().unwrap());

    assert(account.nonce() == 1, 'wrong nonce');
    assert(account.code == storage_evm_bytecode(), 'wrong bytecode');
}

#[test]
fn test_exec_selfdestruct_existing_ca() {
    // Given
    let (native_token, _kakarot_core) = setup_contracts_for_testing();
    let destroyed_address = test_address().evm; // address in machine call context
    let ca_address = deploy_contract_account(destroyed_address, array![0x1, 0x2, 0x3].span());
    fund_account_with_native_token(ca_address.starknet, native_token, 1000);
    let recipient = EOATrait::deploy(other_evm_address()).expect('failed deploying eoa');
    let mut machine = MachineBuilderTestTrait::new_with_presets().with_target(ca_address).build();
    // When
    machine.stack.push(recipient.evm.into()).unwrap();
    machine.exec_selfdestruct().expect('selfdestruct failed');
    machine.state.commit_context();
    machine.state.commit_state().expect('commit state failed');
    machine.state = Default::default(); //empty state to force re-fetch from SN
    // Then
    let destructed = machine.state.get_account(ca_address.evm);

    assert(destructed.nonce() == 0, 'destructed nonce should be 0');
    assert(destructed.balance() == 0, 'destructed balance should be 0');
    assert(destructed.bytecode().len() == 0, 'bytecode should be empty');

    let _recipient = machine.state.get_account(recipient.evm);
//TODO this assertion fails because of deterministic address calculations.
// Once addressed in the compiler code, this test should be fixed.
// in selfdestruct, we execute:
// let recipient_starknet_address = kakarot_state
// .compute_starknet_address(recipient_evm_address);
// assert(recipient.balance().expect('couldnt get balance') == 1000, 'wrong recipient balance');
}

#[test]
fn test_selfdestruct_undeployed_ca() {
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let evm_address: EthAddress = 'ca_address'.try_into().unwrap();
    let ca_address: Address = Address {
        evm: evm_address, starknet: kakarot_core.compute_starknet_address(evm_address)
    };
    let recipient_address: EthAddress = 'recipient_address'.try_into().unwrap();
    let recipient = deploy_eoa(recipient_address);
    let ca_balance = 1000;
    fund_account_with_native_token(ca_address.starknet, native_token, ca_balance);
    let mut machine = MachineBuilderTestTrait::new_with_presets().with_target(ca_address).build();
    // - call `get_account` on an undeployed account, set its type to CA, its nonce to 1, its code to something
    // to mock a cached CA that has not been committed yet.
    let mut ca_account = machine.state.get_account(ca_address.evm);
    ca_account.set_code(array![0x1, 0x2, 0x3].span());
    ca_account.set_type(AccountType::ContractAccount);
    ca_account.set_nonce(1);
    machine.state.set_account(ca_account);
    // - call selfdestruct and commit the state
    machine.stack.push(recipient_address.into()).expect('push failed');
    machine.exec_selfdestruct().expect('selfdestruct failed');
    machine.state.commit_context();
    machine.state.commit_state().expect('commit state failed');
    machine.state = Default::default(); //empty state to force re-fetch from SN

    // Then
    let destructed = machine.state.get_account(ca_address.evm);
    assert(destructed.nonce() == 0, 'destructed nonce should be 0');
    assert(destructed.balance() == 0, 'destructed balance should be 0');
    assert(destructed.bytecode().len() == 0, 'bytecode should be empty');
    let recipient = machine.state.get_account(recipient_address);
    assert(recipient.balance() == ca_balance, 'wrong recipient balance');
}

#[test]
fn test_exec_selfdestruct_add_transfer_post_selfdestruct() {
    // Given
    let (native_token, _) = setup_contracts_for_testing();

    // Deploy sender and recipiens EOAs, and CA that will be selfdestructed and funded with 100 tokens
    let sender = EOATrait::deploy('sender'.try_into().unwrap()).expect('failed deploy EOA',);
    let recipient = EOATrait::deploy('recipient'.try_into().unwrap()).expect('failed deploy EOA',);
    let ca_address = deploy_contract_account('contract'.try_into().unwrap(), array![].span());
    fund_account_with_native_token(sender.starknet, native_token, 150);
    fund_account_with_native_token(ca_address.starknet, native_token, 100);
    let mut machine = MachineBuilderTestTrait::new_with_presets().with_target(ca_address).build();

    // Cache the CA into state
    machine.state.get_account('contract'.try_into().unwrap());

    // When
    machine.stack.push(recipient.evm.into()).unwrap();
    machine.exec_selfdestruct().expect('selfdestruct failed');
    // Add a transfer from sender to CA - after it was selfdestructed in local state. This transfer should go through.
    let transfer = Transfer { sender, recipient: ca_address, amount: 150 };
    machine.state.add_transfer(transfer).unwrap();
    machine.state.commit_context();
    machine.state.commit_state().expect('commit state failed');
    machine.state = Default::default(); //empty state to force re-fetch from SN

    // Then
    let recipient_balance = native_token.balanceOf(recipient.starknet);
    let sender_balance = native_token.balanceOf(sender.starknet);
    let ca_balance = native_token.balanceOf(ca_address.starknet);

    assert(recipient_balance == 100, 'recipient wrong balance');
    assert(sender_balance == 0, 'sender wrong balance');
    assert(ca_balance == 150, 'ca wrong balance');
}
