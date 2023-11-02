use contracts::tests::test_upgradeable::{
    IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait,
    MockContractUpgradeableV1
};
use contracts::tests::test_utils::{
    deploy_kakarot_core, deploy_native_token, fund_account_with_native_token
};

use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
};
use contracts::uninitialized_account::UninitializedAccount;
use evm::tests::test_utils::{kakarot_address, eoa_address};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::testing::{set_caller_address, set_contract_address};
use starknet::{
    deploy_syscall, ContractAddress, ClassHash, get_contract_address, contract_address_const,
    EthAddress
};

fn deploy_account(kakarot_core: ContractAddress) -> IUninitializedAccountDispatcher {
    let calldata: Span<felt252> = array![kakarot_core.into(), eoa_address().into()].span();

    let maybe_address = deploy_syscall(
        UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata, false
    );
    match maybe_address {
        Result::Ok((
            contract_address, _
        )) => { IUninitializedAccountDispatcher { contract_address } },
        Result::Err(err) => panic(err)
    }
}

#[test]
#[available_gas(2000000000)]
fn test_account_initialize() {
    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    set_contract_address(kakarot_core.contract_address);
    let account = deploy_account(kakarot_core.contract_address);

    account.initialize(new_class_hash);

    let version = IMockContractUpgradeableDispatcher { contract_address: account.contract_address }
        .version();
    assert(version == 1, 'version is not 1');

    let allowance = IERC20CamelDispatcher { contract_address: native_token.contract_address }
        .allowance(account.contract_address, kakarot_core.contract_address);
    assert(allowance == integer::BoundedInt::<u256>::max(), 'allowance is not max');
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not Kakarot Core address', 'ENTRYPOINT_FAILED'))]
fn test_eoa_upgrade_from_nonkakarot() {
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    let account = deploy_account(kakarot_core.contract_address);
    set_contract_address(kakarot_address());
    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();

    account.initialize(new_class_hash);
}
