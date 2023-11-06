use contracts::tests::test_upgradeable::{
    IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait,
    MockContractUpgradeableV1
};

use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
};
use contracts::uninitialized_account::UninitializedAccount;
use evm::tests::test_utils::{kakarot_address, eoa_address};
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::testing::{set_caller_address, set_contract_address};
use starknet::{
    deploy_syscall, ContractAddress, ClassHash, get_contract_address, contract_address_const,
    EthAddress
};

fn deploy_account() -> IUninitializedAccountDispatcher {
    let calldata: Span<felt252> = array![kakarot_address().into(), eoa_address().into()].span();

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
fn test_account_upgrade() {
    let account = deploy_account();
    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();

    set_contract_address(kakarot_address());

    account.initialize(new_class_hash);

    let version = IMockContractUpgradeableDispatcher { contract_address: account.contract_address }
        .version();
    assert(version == 1, 'version is not 1');
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not Kakarot Core address', 'ENTRYPOINT_FAILED'))]
fn test_eoa_upgrade_from_nonkakarot() {
    let account = deploy_account();
    let new_class_hash: ClassHash = MockContractUpgradeableV1::TEST_CLASS_HASH.try_into().unwrap();

    account.initialize(new_class_hash);
}
