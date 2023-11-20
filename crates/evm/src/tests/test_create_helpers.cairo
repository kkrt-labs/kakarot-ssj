use contracts::tests::test_data::counter_evm_bytecode;
use evm::create_helpers::MachineCreateHelpers;
use evm::tests::test_utils::setup_machine;
use starknet::EthAddress;

#[test]
#[available_gas(3_000_000_000_000)]
fn test_compute_create2_contract_address() {
    let machine = setup_machine();
    let bytecode = counter_evm_bytecode();
    let salt = 0xbeef;
    let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        .try_into()
        .expect('Wrong Eth address');

    let address = machine
        .compute_create2_contract_address(from, salt, bytecode)
        .expect('compute_create2_contract_address fail');

    // TODO
    // add SNJS script for:
    // import { getContractAddress } from 'viem'
    // const address = getContractAddress({
    //   bytecode: '0x6080604052348015600f57600080fd5b506004361060465760003560e01c806306661abd14604b578063371303c01460655780636d4ce63c14606d578063b3bcfa82146074575b600080fd5b605360005481565b60405190815260200160405180910390f35b606b607a565b005b6000546053565b606b6091565b6001600080828254608a919060b7565b9091555050565b6001600080828254608a919060cd565b634e487b7160e01b600052601160045260246000fd5b8082018082111560c75760c760a1565b92915050565b8181038181111560c75760c760a156fea2646970667358221220f379b9089b70e8e00da8545f9a86f648441fdf27ece9ade2c71653b12fb80c7964736f6c63430008120033',
    //   from: '0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266',
    //   opcode: 'CREATE2',
    //   salt: '0xbeef',
    // });

    // console.log(address)
    assert(
        address == 0xaE6b9c5FD4C9037511100FFb6813D0f607a49f3A
            .try_into()
            .expect('Wrong Eth Address'),
        'wrong create2 address'
    );
}
