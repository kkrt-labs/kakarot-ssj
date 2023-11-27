use contracts::tests::test_data::counter_evm_bytecode;
use starknet::EthAddress;
use utils::address::{compute_contract_address, compute_create2_contract_address};

#[test]
#[available_gas(3_000_000_000_000)]
fn test_compute_create2_contract_address() {
    let bytecode = counter_evm_bytecode();
    let salt = 0xbeef;
    let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        .try_into()
        .expect('Wrong Eth address');

    let address = compute_create2_contract_address(from, salt, bytecode)
        .expect('create2_contract_address fail');

    // TODO
    // add SNJS script for:
    // import { getContractAddress } from 'viem'
    // const address = getContractAddress({
    //   bytecode: '0x608060405234801561000f575f80fd5b506004361061004a575f3560e01c806306661abd1461004e578063371303c01461006c5780636d4ce63c14610076578063b3bcfa8214610094575b5f80fd5b61005661009e565b60405161006391906100f7565b60405180910390f35b6100746100a3565b005b61007e6100bd565b60405161008b91906100f7565b60405180910390f35b61009c6100c5565b005b5f5481565b60015f808282546100b4919061013d565b92505081905550565b5f8054905090565b60015f808282546100d69190610170565b92505081905550565b5f819050919050565b6100f1816100df565b82525050565b5f60208201905061010a5f8301846100e8565b92915050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f610147826100df565b9150610152836100df565b925082820190508082111561016a57610169610110565b5b92915050565b5f61017a826100df565b9150610185836100df565b925082820390508181111561019d5761019c610110565b5b9291505056fea26469706673582212207e792fcff28a4bf0bad8675c5bc2288b07835aebaa90b8dc5e0df19183fb72cf64736f6c63430008160033',
    //   from: '0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266',
    //   opcode: 'CREATE2',
    //   salt: '0xbeef',
    // });

    // console.log(address)
    assert(
        address == 0x088a44D7CdD8DEA4d1Db6E3F4059c70c405a0C97
            .try_into()
            .expect('Wrong Eth Address'),
        'wrong create2 address'
    );
}

#[test]
#[available_gas(3_000_000_000_000)]
fn test_compute_contract_address() {
    let nonce = 420;
    let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        .try_into()
        .expect('Wrong Eth address');

    let address = compute_contract_address(from, nonce);
    assert(address.into() == 0x40A633EeF249F21D95C8803b7144f19AAfeEF7ae, 'wrong create address');
}
