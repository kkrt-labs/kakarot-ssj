use evm::machine::{Machine, MachineCurrentContext};
use evm::context::CallContextTrait;
use evm::tests::test_utils::{
    evm_address, setup_machine_with_bytecode, setup_machine, starknet_address
};


#[test]
#[available_gas(20000000)]
fn test_machine_default() {
    let mut machine: Machine = Default::default();

    assert(machine.ctx_count == 1, 'wrong ctx_count');
    assert(machine.current_ctx_pc() == 0, 'wrong current ctx pc');
    assert(!machine.current_ctx_reverted(), 'ctx should not be reverted');
    assert(!machine.current_ctx_stopped(), 'ctx should not be stopped');
}

#[test]
#[available_gas(20000000)]
fn test_set_pc_current_ctx() {
    let mut machine: Machine = Default::default();

    let new_pc = 42;
    machine.set_pc_current_ctx(new_pc);

    assert(machine.current_ctx_pc() == new_pc, 'wrong pc');
}

#[test]
#[available_gas(20000000)]
fn test_revert_current_ctx() {
    let mut machine = Default::default();

    machine.revert_current_ctx(array![0xde, 0xbf].span());

    assert(machine.current_ctx_reverted(), 'ctx should be reverted');
    assert(!machine.current_ctx_stopped(), 'ctx should not be stopped');
}

#[test]
#[available_gas(20000000)]
fn test_stop_current_ctx() {
    let mut machine = Default::default();

    machine.stop_current_ctx();

    assert(!machine.current_ctx_reverted(), 'ctx should not be reverted');
    assert(machine.current_ctx_stopped(), 'ctx should be stopped');
}

#[test]
#[available_gas(20000000)]
fn test_read_code_current_ctx() {
    // Given a machine with some bytecode in the call context

    let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    // When we read a code slice
    let read_code = machine.read_code_current_ctx(3);

    // Then the read code should be the expected slice and the PC should be updated
    assert(read_code == array![0x01, 0x02, 0x03].span(), 'wrong bytecode read');
    assert(machine.current_ctx_pc() == 3, 'wrong pc');
}

#[test]
#[available_gas(20000000)]
fn test_current_ctx_is_root() {
    let mut machine: Machine = Default::default();

    assert(machine.current_ctx_is_root(), 'current_ctx should be root');
}


#[test]
#[available_gas(20000000)]
fn test_current_ctx_call_context_properties() {
    let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    let call_context = machine.current_ctx_call_context();
    assert(call_context.read_only() == false, 'wrong read_only');
    assert(call_context.gas_limit() == 0xffffff, 'wrong gas_limit');
    assert(call_context.gas_price() == 0xaaaaaa, 'wrong gas_price');
    assert(call_context.value() == 123456789, 'wrong value');
    assert(call_context.bytecode() == bytecode, 'wrong bytecode');
    assert(call_context.calldata() == array![4, 5, 6].span(), 'wrong calldata');
}

#[test]
#[available_gas(20000000)]
fn test_current_ctx_addresses() {
    let evm_address_expected = evm_address();
    let mut machine: Machine = setup_machine();

    let evm_address = machine.current_ctx_evm_address();
    assert(evm_address == evm_address_expected, 'wrong evm address');

    let starknet_address = machine.current_ctx_starknet_address();
    let starknet_address_expected = starknet_address();
    assert(starknet_address == starknet_address_expected, 'wrong starknet address');
}

#[test]
#[available_gas(20000000)]
fn test_current_ctx_destroyed_contracts() {
    let mut machine: Machine = Default::default();
    let destroyed_contracts = machine.current_ctx_destroyed_contracts();
    assert(destroyed_contracts.len() == 0, 'wrong length');
}

#[test]
#[available_gas(20000000)]
fn test_current_ctx_events() {
    let mut machine: Machine = Default::default();

    let events = machine.current_ctx_events();
    assert(events.len() == 0, 'wrong length');
}

#[test]
#[available_gas(20000000)]
fn test_current_ctx_create_addresses() {
    let mut machine: Machine = Default::default();

    let create_addresses = machine.current_ctx_create_addresses();
    assert(create_addresses.len() == 0, 'wrong length');
}

#[test]
#[available_gas(20000000)]
fn test_current_ctx_return_data() {
    let mut machine: Machine = Default::default();

    let return_data = machine.current_ctx_return_data();
    assert(return_data.len() == 0, 'wrong length');
}
