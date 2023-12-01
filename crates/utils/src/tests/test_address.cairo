use contracts::tests::test_data::counter_evm_bytecode;
use starknet::EthAddress;
use utils::address::{compute_contract_address, compute_create2_contract_address};

#[test]
fn test_compute_create2_contract_address() {
    let bytecode = counter_evm_bytecode();
    let salt = 0xbeef;
    let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        .try_into()
        .expect('Wrong Eth address');

    let address = compute_create2_contract_address(from, salt, bytecode)
        .expect('create2_contract_address fail');

    assert(
        address == 0x088a44D7CdD8DEA4d1Db6E3F4059c70c405a0C97
            .try_into()
            .expect('Wrong Eth Address'),
        'wrong create2 address'
    );
}

#[test]
fn test_compute_contract_address() {
    let nonce = 420;
    let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        .try_into()
        .expect('Wrong Eth address');

    let address = compute_contract_address(from, nonce);
    assert(address.into() == 0x40A633EeF249F21D95C8803b7144f19AAfeEF7ae, 'wrong create address');
}
