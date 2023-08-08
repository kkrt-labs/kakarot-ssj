use starknet::{contract_address_try_from_felt252, ContractAddress, EthAddress};
use traits::{Into, TryInto};
use option::OptionTrait;

mod test_helpers;

fn starknet_address() -> ContractAddress {
    'starknet_address'.try_into().unwrap()
}

fn evm_address() -> EthAddress {
    'evm_address'.try_into().unwrap()
}

fn zero_address() -> ContractAddress {
    0.try_into().unwrap()
}
