use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::tests::test_utils as contract_utils;
use contracts::tests::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
use evm::errors::EVMErrorTrait;
use evm::model::eoa::{EOA, EOATrait};
use evm::tests::test_utils;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
use starknet::testing::set_contract_address;


#[test]
#[available_gas(200000000)]
fn test_eoa_deploy() {
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    contract_utils::drop_event(kakarot_core.contract_address);

    let maybe_eoa = EOATrait::deploy(test_utils::evm_address());
    let eoa = match maybe_eoa {
        Result::Ok(eoa) => eoa,
        Result::Err(err) => panic_with_felt252(err.to_string())
    };

    let event = contract_utils::pop_log::<KakarotCore::EOADeployed>(kakarot_core.contract_address)
        .unwrap();

    assert(event.evm_address == test_utils::evm_address(), 'wrong evm address');
    assert(event.starknet_address.into() == eoa.starknet_address, 'wrong starknet address');
}
