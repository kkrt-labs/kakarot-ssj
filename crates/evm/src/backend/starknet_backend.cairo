use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{KakarotCore, KakarotCore::KakarotCoreImpl};
use core::num::traits::zero::Zero;
use core::ops::SnapshotDeref;
use core::starknet::storage::StoragePointerReadAccess;
use core::starknet::syscalls::{deploy_syscall};
use core::starknet::syscalls::{emit_event_syscall};
use core::starknet::{EthAddress, get_tx_info, get_block_info, SyscallResultTrait};
use evm::errors::{ensure, EVMError, EOA_EXISTS};
use evm::model::{Address, AddressTrait, Environment, Account, AccountTrait};
use evm::model::{Transfer};
use evm::state::{State, StateTrait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::constants::BURN_ADDRESS;
use utils::constants;
use utils::set::SetTrait;


/// Commits the state changes to Starknet.
///
/// # Arguments
///
/// * `state` - The state to commit.
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
pub fn commit(ref state: State) -> Result<(), EVMError> {
    commit_accounts(ref state)?;
    transfer_native_token(ref state)?;
    emit_events(ref state)?;
    commit_storage(ref state)
}

/// Deploys a new EOA contract.
///
/// # Arguments
///
/// * `evm_address` - The EVM address of the EOA to deploy.
pub fn deploy(evm_address: EthAddress) -> Result<Address, EVMError> {
    // Unlike CAs, there is not check for the existence of an EOA prealably to calling
    // `EOATrait::deploy` - therefore, we need to check that there is no collision.
    let mut is_deployed = evm_address.is_deployed();
    ensure(!is_deployed, EVMError::DeployError(EOA_EXISTS))?;

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    let uninitialized_account_class_hash = kakarot_state.uninitialized_account_class_hash();
    let calldata: Span<felt252> = [1, evm_address.into()].span();

    let (starknet_address, _) = deploy_syscall(
        uninitialized_account_class_hash,
        contract_address_salt: evm_address.into(),
        calldata: calldata,
        deploy_from_zero: false
    )
        .unwrap_syscall();

    Result::Ok(Address { evm: evm_address, starknet: starknet_address })
}

pub fn get_bytecode(evm_address: EthAddress) -> Span<u8> {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let starknet_address = kakarot_state.address_registry(evm_address);
    if starknet_address.is_non_zero() {
        let account = IAccountDispatcher { contract_address: starknet_address };
        account.bytecode()
    } else {
        [].span()
    }
}

/// Populate an Environment with Starknet syscalls.
pub fn get_env(origin: EthAddress, gas_price: u128) -> Environment {
    let kakarot_state = KakarotCore::unsafe_new_contract_state().snapshot_deref();
    let block_info = get_block_info().unbox();

    // tx.gas_price and env.gas_price have the same values here
    // - this is not always true in EVM transactions
    Environment {
        origin: origin,
        gas_price,
        chain_id: get_tx_info().unbox().chain_id.try_into().unwrap(),
        prevrandao: kakarot_state.Kakarot_prev_randao.read(),
        block_number: block_info.block_number,
        block_gas_limit: constants::BLOCK_GAS_LIMIT,
        block_timestamp: block_info.block_timestamp,
        coinbase: kakarot_state.Kakarot_coinbase.read(),
        base_fee: kakarot_state.Kakarot_base_fee.read(),
        state: Default::default(),
    }
}

/// Fetches the value stored at the given key for the corresponding contract accounts.
/// If the account is not deployed (in case of a create/deploy transaction), returns 0.
/// # Arguments
///
/// * `account` The account to read from.
/// * `key` The key to read.
///
/// # Returns
///
/// A `Result` containing the value stored at the given key or an `EVMError` if there was an error.
pub fn fetch_original_storage(account: @Account, key: u256) -> u256 {
    let is_deployed = account.evm_address().is_deployed();
    if is_deployed {
        return IAccountDispatcher { contract_address: account.starknet_address() }.storage(key);
    }
    0
}

/// Fetches the balance of the given address.
///
/// # Arguments
///
/// * `self` - The address to fetch the balance of.
///
/// # Returns
///
/// The balance of the given address.
pub fn fetch_balance(self: @Address) -> u256 {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let native_token_address = kakarot_state.get_native_token();
    let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
    native_token.balanceOf(*self.starknet)
}


/// Commits the account changes to Starknet.
///
/// # Arguments
///
/// * `state` - The state containing the accounts to commit.
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
fn commit_accounts(ref state: State) -> Result<(), EVMError> {
    let mut account_keys = state.accounts.keyset.to_span();
    while let Option::Some(evm_address) = account_keys.pop_front() {
        let account = state.accounts.changes.get(*evm_address).deref();
        commit_account(@account, ref state);
    };
    return Result::Ok(());
}

/// Commits the account to Starknet by updating the account state if it
/// exists, or deploying a new account if it doesn't.
///
/// # Arguments
/// * `self` - The account to commit
/// * `state` - The state, modified in the case of selfdestruct transfers
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
fn commit_account(self: @Account, ref state: State) {
    if self.evm_address().is_precompile() {
        return;
    }

    // Case new account
    if !self.evm_address().is_deployed() {
        deploy(self.evm_address()).expect('account deployment failed');
    }

    // @dev: EIP-6780 - If selfdestruct on an account created, dont commit data
    // and burn any leftover balance.
    if (self.is_selfdestruct() && self.is_created()) {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let burn_starknet_address = kakarot_state
            .compute_starknet_address(BURN_ADDRESS.try_into().unwrap());
        let burn_address = Address {
            starknet: burn_starknet_address, evm: BURN_ADDRESS.try_into().unwrap()
        };
        state
            .add_transfer(
                Transfer { sender: self.address(), recipient: burn_address, amount: self.balance() }
            )
            .expect('Failed to burn on selfdestruct');
        return;
    }

    if !self.has_code_or_nonce() {
        // Nothing to commit
        return;
    }

    // Write updated nonce and storage
    //TODO: storage commits are done in the State commitment as they're not part of the account
    //model in SSJ
    let starknet_account = IAccountDispatcher { contract_address: self.starknet_address() };
    starknet_account.set_nonce(*self.nonce);

    //Storage is handled outside of the account and must be committed after all accounts are
    //committed.
    if self.is_created() {
        starknet_account.write_bytecode(self.bytecode());
        //TODO: save valid jumpdests https://github.com/kkrt-labs/kakarot-ssj/issues/839
    //TODO: set code hash https://github.com/kkrt-labs/kakarot-ssj/issues/840
    }
    return;
}

/// Iterates through the list of pending transfer and triggers them
fn transfer_native_token(ref self: State) -> Result<(), EVMError> {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let native_token = kakarot_state.get_native_token();
    while let Option::Some(transfer) = self.transfers.pop_front() {
        IERC20CamelDispatcher { contract_address: native_token }
            .transferFrom(transfer.sender.starknet, transfer.recipient.starknet, transfer.amount);
    };
    Result::Ok(())
}

/// Iterates through the list of events and emits them.
fn emit_events(ref self: State) -> Result<(), EVMError> {
    while let Option::Some(event) = self.events.pop_front() {
        let mut keys = Default::default();
        let mut data = Default::default();
        Serde::<Array<u256>>::serialize(@event.keys, ref keys);
        Serde::<Array<u8>>::serialize(@event.data, ref data);
        emit_event_syscall(keys.span(), data.span()).unwrap_syscall();
    };
    return Result::Ok(());
}

/// Commits storage changes to the KakarotCore contract by writing pending
/// state changes to Starknet Storage.
/// commit_storage MUST be called after commit_accounts.
fn commit_storage(ref self: State) -> Result<(), EVMError> {
    let mut storage_keys = self.accounts_storage.keyset.to_span();
    while let Option::Some(state_key) = storage_keys.pop_front() {
        let (evm_address, key, value) = self.accounts_storage.changes.get(*state_key).deref();
        let mut account = self.get_account(evm_address);
        // @dev: EIP-6780 - If selfdestruct on an account created, dont commit data
        if account.is_selfdestruct() {
            continue;
        }
        IAccountDispatcher { contract_address: account.starknet_address() }
            .write_storage(key, value);
    };
    Result::Ok(())
}

#[cfg(test)]
mod tests {
    use core::starknet::ClassHash;
    use evm::backend::starknet_backend;
    use evm::model::Address;
    use evm::model::account::Account;
    use evm::state::{State, StateTrait};
    use evm::test_utils::evm_address;
    use evm::test_utils::{
        setup_test_storages, uninitialized_account, account_contract, register_account
    };
    use snforge_std::{test_address, start_mock_call, get_class_hash};
    use snforge_utils::snforge_utils::{assert_not_called, assert_called};
    use utils::helpers::compute_starknet_address;

    #[test]
    #[ignore]
    //TODO(starknet-fonudry): it's impossible to deploy an un-declared class, nor is it possible to
    //mock_deploy.
    fn test_deploy() {
        // store the classes in the context of the local execution, to be used for deploying the
        // account class
        setup_test_storages();
        let test_address = test_address();

        start_mock_call::<
            ClassHash
        >(test_address, selector!("get_account_contract_class_hash"), account_contract());
        start_mock_call::<()>(test_address, selector!("initialize"), ());
        let eoa_address = starknet_backend::deploy(evm_address())
            .expect('deployment of EOA failed');

        let class_hash = get_class_hash(eoa_address.starknet);
        assert_eq!(class_hash, account_contract());
    }

    #[test]
    #[ignore]
    //TODO(starknet-foundry): it's impossible to deploy an un-declared class, nor is it possible to
    //mock_deploy.
    fn test_account_commit_undeployed_create_should_change_set_all() {
        setup_test_storages();
        let test_address = test_address();
        let evm_address = evm_address();
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );

        let mut state: State = Default::default();

        // When
        let mut account = Account {
            address: Address { evm: evm_address, starknet: starknet_address }, nonce: 420, code: [
                0x1
            ].span(), balance: 0, selfdestruct: false, is_created: true,
        };
        state.set_account(account);

        start_mock_call::<()>(starknet_address, selector!("set_nonce"), ());
        start_mock_call::<
            ClassHash
        >(test_address, selector!("get_account_contract_class_hash"), account_contract());
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then
        //TODO(starknet-foundry): we should be able to assert this has been called with specific
        //data, to pass in mock_call
        assert_called(starknet_address, selector!("set_nonce"));
        assert_not_called(starknet_address, selector!("write_bytecode"));
    }

    #[test]
    fn test_account_commit_deployed_and_created_should_write_code() {
        setup_test_storages();
        let test_address = test_address();
        let evm_address = evm_address();
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );
        register_account(evm_address, starknet_address);

        let mut state: State = Default::default();
        let mut account = Account {
            address: Address { evm: evm_address, starknet: starknet_address }, nonce: 420, code: [
                0x1
            ].span(), balance: 0, selfdestruct: false, is_created: true,
        };
        state.set_account(account);

        start_mock_call::<()>(starknet_address, selector!("write_bytecode"), ());
        start_mock_call::<()>(starknet_address, selector!("set_nonce"), ());
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then the account should have a new code.
        //TODO(starknet-foundry): we should be able to assert this has been called with specific
        //data, to pass in mock_call
        assert_called(starknet_address, selector!("write_bytecode"));
        assert_called(starknet_address, selector!("set_nonce"));
    }

    #[test]
    #[ignore]
    //TODO(starknet-foundry): it's impossible to deploy an un-declared class, nor is it possible to
    //mock_deploy.
    fn test_exec_sstore_finalized() { // // Given
    // setup_test_storages();
    // let mut vm = VMBuilderTrait::new_with_presets().build();
    // let evm_address = vm.message().target.evm;
    // let starknet_address = compute_starknet_address(
    //     test_address(), evm_address, uninitialized_account()
    // );
    // let account = Account {
    //     address: Address { evm: evm_address, starknet: starknet_address },
    //     code: [].span(),
    //     nonce: 1,
    //     balance: 0,
    //     selfdestruct: false,
    //     is_created: false,
    // };
    // let key: u256 = 0x100000000000000000000000000000001;
    // let value: u256 = 0xABDE1E11A5;
    // vm.stack.push(value).expect('push failed');
    // vm.stack.push(key).expect('push failed');

    // // When

    // vm.exec_sstore().expect('exec_sstore failed');
    // starknet_backend::commit(ref vm.env.state).expect('commit storage failed');

    // // Then
    // assert(fetch_original_storage(@account, key) == value, 'wrong committed value')
    }
}
