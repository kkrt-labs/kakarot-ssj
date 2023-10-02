use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::context::CallContextTrait;
use evm::tests::test_utils::{
    evm_address, setup_machine_with_bytecode, setup_machine, starknet_address
};


#[test]
#[available_gas(20000000)]
fn test_machine_default() {
    let mut machine: Machine = Default::default();

    assert(machine.ctx_count == 1, 'wrong ctx_count');
    assert(machine.pc() == 0, 'wrong current ctx pc');
    assert(!machine.reverted(), 'ctx should not be reverted');
    assert(!machine.stopped(), 'ctx should not be stopped');
}

#[test]
#[available_gas(20000000)]
fn test_set_pc() {
    let mut machine: Machine = Default::default();

    let new_pc = 42;
    machine.set_pc(new_pc);

    assert(machine.pc() == new_pc, 'wrong pc');
}

#[test]
#[available_gas(20000000)]
fn test_revert() {
    let mut machine = Default::default();

    machine.revert(array![0xde, 0xbf].span());

    assert(machine.reverted(), 'ctx should be reverted');
    assert(machine.stopped(), 'ctx should be stopped');
}

#[test]
#[available_gas(20000000)]
fn test_stop() {
    let mut machine = Default::default();

    machine.stop();

    assert(!machine.reverted(), 'ctx should not be reverted');
    assert(machine.stopped(), 'ctx should be stopped');
}

#[test]
#[available_gas(20000000)]
fn test_read_code() {
    // Given a machine with some bytecode in the call context

    let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    // When we read a code slice
    let read_code = machine.read_code(3);

    // Then the read code should be the expected slice and the PC should be updated
    assert(read_code == array![0x01, 0x02, 0x03].span(), 'wrong bytecode read');
    // Read Code should not modify PC
    assert(machine.pc() == 0, 'wrong pc');
}

#[test]
#[available_gas(20000000)]
fn test_is_root() {
    let mut machine: Machine = Default::default();

    assert(machine.is_root(), 'current_ctx should be root');
}


#[test]
#[available_gas(20000000)]
fn test_call_context_properties() {
    let bytecode = array![0x01, 0x02, 0x03, 0x04, 0x05].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    let call_context = machine.call_context();
    assert(call_context.read_only() == false, 'wrong read_only');
    assert(call_context.gas_limit() == 0xffffff, 'wrong gas_limit');
    assert(call_context.gas_price() == 0xaaaaaa, 'wrong gas_price');
    assert(call_context.value() == 123456789, 'wrong value');
    assert(call_context.bytecode() == bytecode, 'wrong bytecode');
    assert(call_context.calldata() == array![4, 5, 6].span(), 'wrong calldata');
}

#[test]
#[available_gas(20000000)]
fn test_addresses() {
    let evm_address_expected = evm_address();
    let mut machine: Machine = setup_machine();

    let evm_address = machine.evm_address();
    assert(evm_address == evm_address_expected, 'wrong evm address');

    let starknet_address = machine.starknet_address();
    let starknet_address_expected = starknet_address();
    assert(starknet_address == starknet_address_expected, 'wrong starknet address');
}

#[test]
#[available_gas(20000000)]
fn test_destroyed_contracts() {
    let mut machine: Machine = Default::default();
    let destroyed_contracts = machine.destroyed_contracts();
    assert(destroyed_contracts.len() == 0, 'wrong length');
}

#[test]
#[available_gas(20000000)]
fn test_events() {
    let mut machine: Machine = Default::default();

    let events = machine.events();
    assert(events.len() == 0, 'wrong length');
}

#[test]
#[available_gas(20000000)]
fn test_create_addresses() {
    let mut machine: Machine = Default::default();

    let create_addresses = machine.create_addresses();
    assert(create_addresses.len() == 0, 'wrong length');
}

#[test]
#[available_gas(20000000)]
fn test_return_data() {
    let mut machine: Machine = Default::default();

    let return_data = machine.return_data();
    assert(return_data.len() == 0, 'wrong length');
}
