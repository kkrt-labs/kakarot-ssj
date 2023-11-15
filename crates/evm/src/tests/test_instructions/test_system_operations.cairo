use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::test_data::{storage_evm_bytecode, storage_evm_initcode};
use contracts::tests::test_utils::setup_contracts_for_testing;
use debug::PrintTrait;
use evm::call_helpers::{MachineCallHelpers, MachineCallHelpersImpl};
use evm::context::{ExecutionContext, ExecutionContextTrait, ExecutionContextType};
use evm::instructions::MemoryOperationTrait;
use evm::instructions::SystemOperationsTrait;
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::contract_account::ContractAccountTrait;
use evm::model::{AccountTrait, Address, AccountType};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{
    setup_machine_with_nested_execution_context, setup_machine, setup_machine_with_bytecode,
    initialize_contract_account, native_token, evm_address
};
use starknet::EthAddress;
use utils::helpers::load_word;
use utils::traits::EthAddressIntoU256;

#[test]
#[available_gas(20000000)]
fn test_exec_return() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
    assert(machine.id() == 1, 'wrong ctx id');

    // And
    machine.finalize_calling_context();

    // Then
    assert(machine.id() == 0, 'should be parent id');
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
}


#[test]
#[available_gas(20000000)]
fn test_exec_revert() {
    // Given
    let mut machine = setup_machine();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_revert().is_ok(), 'Exec revert failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}

#[test]
#[available_gas(20000000)]
fn test_exec_revert_nested() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
    // When
    machine.stack.push(1000);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(0);
    assert(machine.exec_revert().is_ok(), 'Exec revert failed');

    // Then
    assert(1000 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped')
}


#[test]
#[available_gas(20000000)]
fn test_exec_return_with_offset() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
    // When
    machine.stack.push(1);
    machine.stack.push(0);
    machine.exec_mstore();

    machine.stack.push(32);
    machine.stack.push(1);
    assert(machine.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
    assert(machine.id() == 1, 'wrong ctx id');

    // And
    machine.finalize_calling_context();

    // Then
    assert(machine.id() == 0, 'should be parent id');
    assert(256 == load_word(32, machine.return_data()), 'Wrong return_data');
}

#[test]
#[available_gas(4_000_000_000)]
fn test_exec_call() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

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
    let mut machine = setup_machine_with_bytecode(bytecode);
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
    assert(machine.error.is_none(), 'run should be success');
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
}

#[test]
#[available_gas(50000000)]
fn test_exec_call_no_return() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

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
    let mut machine = setup_machine_with_bytecode(bytecode);

    // Deploy bytecode at 0x100
    // (+ 0x1 0x1)
    let deployed_bytecode = array![0x60, 0x01, 0x60, 0x01, 0x01, 0x60, 0x00, 0x53, 0x00].span();
    let eth_address: EthAddress = 0x100_u256.into();
    initialize_contract_account(eth_address, deployed_bytecode, Default::default().span())
        .expect('set code failed');

    // When
    interpreter.run(ref machine);

    // Then
    assert(machine.error.is_none(), 'run should be success');
    assert(machine.return_data().is_empty(), 'Wrong return_data len');
    assert(machine.stopped(), 'machine should be stopped')
}


#[test]
#[available_gas(400000000)]
fn test_exec_staticcall() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

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
    let mut machine = setup_machine_with_bytecode(bytecode);

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
#[available_gas(50000000)]
fn test_exec_staticcall_no_return() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

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
    let mut machine = setup_machine_with_bytecode(bytecode);

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
#[available_gas(4_000_000_000)]
fn test_exec_delegatecall() {
    // Given
    let mut interpreter = EVMInterpreterTrait::new();
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    let evm_address = evm_address();
    let eoa = kakarot_core.deploy_eoa(evm_address);

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
    let mut machine = setup_machine_with_bytecode(bytecode);
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
    assert(machine.error.is_none(), 'run should be success');
    assert(2 == load_word(1, machine.return_data()), 'Wrong return_data');
    assert(machine.stopped(), 'machine should be stopped');
}


#[test]
#[available_gas(4_000_000_000)]
fn test_exec_create2() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();

    let mut machine = setup_machine_with_nested_execution_context();
    let mut interpreter = EVMInterpreterTrait::new();

    let deployed_bytecode = array![0xff].span();
    let eth_address: EthAddress = 0x00000000000000000075766d5f61646472657373_u256.into();
    let contract_address = ContractAccountTrait::deploy(
        eth_address, deployed_bytecode, Default::default().span()
    )
        .expect('failed deploying CA');

    let mut ctx = machine.current_ctx.unbox();
    ctx.address = contract_address;
    ctx.ctx_type = ExecutionContextType::Create(ctx.id());
    machine.current_ctx = BoxTrait::new(ctx);

    // Load into memory the bytecode of Storage.sol
    let storage_initcode = storage_evm_initcode();
    machine.memory.store_n(storage_initcode, 0);

    machine.stack.push(0).unwrap();
    machine.stack.push(storage_initcode.len().into()).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();

    // When
    machine.exec_create2().unwrap();
    assert(machine.bytecode() == storage_initcode, 'wrong bytecode');
    'EVM ADDRESS:'.print();
    machine.address().evm.print();
    interpreter.run(ref machine);

    assert(machine.error.is_none(), 'run should be success');

    // Add SNJS script to precompute the address of the Storage.sol contract
    //     import { getContractAddress } from 'viem'

    // const address = getContractAddress({
    //   bytecode: '0x6080604052348015600f57600080fd5b5060ac8061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060325760003560e01c80632e64cec11460375780636057361d14604c575b600080fd5b60005460405190815260200160405180910390f35b605c6057366004605e565b600055565b005b600060208284031215606f57600080fd5b503591905056fea26469706673582212206757b185bacf99a4e559a82662511d555a86d906179b16109ef465b43399608764736f6c63430008130033',
    //   from: '0x00000000000000000075766d5f61646472657373',
    //   opcode: 'CREATE2',
    //   salt: '0x00',
    // });
    // console.log(address)
    let account = machine
        .state
        .get_account(0xbD5653e9332571c4f8b76924EDa0dd242d2ccC29.try_into().unwrap())
        .expect('cannot retrieve account');

    assert(account.bytecode() == storage_evm_bytecode(), 'wrong bytecode');
    assert(account.account_type == AccountType::ContractAccount, 'wrong account type');
    assert(account.nonce() == 1, 'wrong nonce');
    assert(account.code == storage_evm_bytecode(), 'wrong bytecode');
}
