use contracts::tests::test_data::counter_evm_bytecode;
use evm::create_helpers::MachineCreateHelpers;
use evm::tests::test_utils::setup_machine;
use starknet::EthAddress;

#[test]
#[available_gas(3_000_000_000_000)]
fn test_get_create2_address() {
    let machine = setup_machine();
    let bytecode = counter_evm_bytecode();
    let salt = 0xbeef;
    let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        .try_into()
        .expect('Wrong Eth address');

    let address = machine
        .get_create2_address(from, salt, bytecode)
        .expect('get_create2_address fail');

    assert(
        address == 0xaE6b9c5FD4C9037511100FFb6813D0f607a49f3A
            .try_into()
            .expect('Wrong Eth Address'),
        'wrong create2 address'
    );
}
