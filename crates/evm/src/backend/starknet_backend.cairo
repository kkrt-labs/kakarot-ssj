use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{KakarotCore, KakarotCore::KakarotCoreImpl};
use core::num::traits::zero::Zero;
use core::ops::deref::SnapshotDeref;
use core::starknet::storage::StoragePointerReadAccess;
use core::starknet::storage::StoragePointerWriteAccess;
use evm::errors::{ensure, EVMError, EOA_EXISTS};
use evm::model::{Address, AddressTrait, Environment, Account, AccountTrait};
use evm::state::{State, StateTrait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{
    EthAddress, get_contract_address, deploy_syscall, get_tx_info, get_block_info,
    SyscallResultTrait
};
use utils::constants;


/// Commits the state changes to Starknet.
///
/// # Arguments
///
/// * `state` - The state to commit.
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
fn commit(ref state: State) -> Result<(), EVMError> {
    internals::commit_accounts(ref state)?;
    internals::transfer_native_token(ref state)?;
    internals::emit_events(ref state)?;
    internals::commit_storage(ref state)
}

/// Deploys a new EOA contract.
///
/// # Arguments
///
/// * `evm_address` - The EVM address of the EOA to deploy.
fn deploy(evm_address: EthAddress) -> Result<Address, EVMError> {
    // Unlike CAs, there is not check for the existence of an EOA prealably to calling
    // `EOATrait::deploy` - therefore, we need to check that there is no collision.
    let mut is_deployed = evm_address.is_deployed();
    ensure(!is_deployed, EVMError::DeployError(EOA_EXISTS))?;

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    let uninitialized_account_class_hash = kakarot_state.uninitialized_account_class_hash();
    let kakarot_address = get_contract_address();
    let calldata: Span<felt252> = array![kakarot_address.into(), evm_address.into()].span();

    let (starknet_address, _) = deploy_syscall(
        uninitialized_account_class_hash, evm_address.into(), calldata, true
    )
        .unwrap_syscall();

    Result::Ok(Address { evm: evm_address, starknet: starknet_address })
}

fn get_bytecode(evm_address: EthAddress) -> Span<u8> {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let starknet_address = kakarot_state.address_registry(evm_address);
    if starknet_address.is_non_zero() {
        let account = IAccountDispatcher { contract_address: starknet_address };
        account.bytecode()
    } else {
        array![].span()
    }
}

/// Populate an Environment with Starknet syscalls.
fn get_env(origin: EthAddress, gas_price: u128) -> Environment {
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
fn fetch_original_storage(account: @Account, key: u256) -> u256 {
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
fn fetch_balance(self: @Address) -> u256 {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let native_token_address = kakarot_state.get_native_token();
    let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
    native_token.balanceOf(*self.starknet)
}


mod internals {
    use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
    use contracts::kakarot_core::{KakarotCore, KakarotCore::KakarotCoreImpl};
    use evm::errors::EVMError;
    use evm::model::account::{Account, AccountTrait};
    use evm::model::{Address, AddressTrait, Transfer};
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::SyscallResultTrait;
    use starknet::syscalls::{emit_event_syscall};
    use super::{State, StateTrait, deploy};
    use utils::constants::BURN_ADDRESS;
    use utils::set::{Set, SetTrait};


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
            commit(@account, ref state);
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
    fn commit(self: @Account, ref state: State) {
        if self.evm_address().is_precompile() {
            return;
        }

        // Case new account
        if !self.evm_address().is_deployed() {
            deploy(self.evm_address()).expect('account deployment failed');

            let has_code_or_nonce = self.has_code_or_nonce();
            if !has_code_or_nonce {
                // Nothing to commit
                return;
            }

            // If SELFDESTRUCT, leave the account empty after deploying it - including
            // burning any leftover balance.
            if (self.is_selfdestruct()) {
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let burn_starknet_address = kakarot_state
                    .compute_starknet_address(BURN_ADDRESS.try_into().unwrap());
                let burn_address = Address {
                    starknet: burn_starknet_address, evm: BURN_ADDRESS.try_into().unwrap()
                };
                state
                    .add_transfer(
                        Transfer {
                            sender: self.address(), recipient: burn_address, amount: self.balance()
                        }
                    )
                    .expect('Failed to burn on selfdestruct');
                return;
            }

            // Write bytecode and set nonce
            let starknet_account = IAccountDispatcher { contract_address: self.starknet_address() };
            starknet_account.write_bytecode(self.bytecode());
            starknet_account.set_nonce(*self.nonce);

            //TODO: storage commits are done in the State commitment
            //Storage is handled outside of the account and must be committed after all accounts are
            //committed.
            return;
        };

        // @dev: EIP-6780 - If selfdestruct on an account created, dont commit data
        let is_created_selfdestructed = self.is_selfdestruct() && self.is_created();
        if is_created_selfdestructed {
            // If the account was created and selfdestructed in the same transaction, we don't need
            // to commit it.
            return;
        }

        let starknet_account = IAccountDispatcher { contract_address: self.starknet_address() };

        starknet_account.set_nonce(*self.nonce);
        //TODO: storage commits are done in the State commitment
        //Storage is handled outside of the account and must be committed after all accounts are
        //committed.

        // Update bytecode if required (SELFDESTRUCTed contract committed and redeployed)
        //TODO: add bytecode_len entrypoint for optimization
        let bytecode_len = starknet_account.bytecode().len();
        if bytecode_len != self.bytecode().len() {
            starknet_account.write_bytecode(self.bytecode());
        }
    }

    /// Iterates through the list of pending transfer and triggers them
    fn transfer_native_token(ref self: State) -> Result<(), EVMError> {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token = kakarot_state.get_native_token();
        while let Option::Some(transfer) = self.transfers.pop_front() {
            IERC20CamelDispatcher { contract_address: native_token }
                .transferFrom(
                    transfer.sender.starknet, transfer.recipient.starknet, transfer.amount
                );
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
            IAccountDispatcher { contract_address: account.starknet_address() }
                .write_storage(key, value);
        };
        Result::Ok(())
    }
}

#[cfg(test)]
mod tests {
    use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
    use contracts::kakarot_core::KakarotCore;
    use contracts::test_utils as contract_utils;
    use contracts::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
    use evm::backend::starknet_backend;
    use evm::errors::EVMErrorTrait;
    use evm::test_utils::{chain_id, evm_address, VMBuilderTrait};
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
    use starknet::testing::{set_contract_address, set_chain_id};


    #[test]
    fn test_account_deploy() {
        let (_, kakarot_core) = setup_contracts_for_testing();

        let eoa_address = starknet_backend::deploy(evm_address())
            .expect('deployment of EOA failed');

        let event = contract_utils::pop_log::<
            KakarotCore::AccountDeployed
        >(kakarot_core.contract_address)
            .unwrap();

        assert(event.evm_address == evm_address(), 'wrong evm address');
        assert(event.starknet_address.into() == eoa_address.starknet, 'wrong starknet address');

        set_chain_id(chain_id().into());

        let eoa = IAccountDispatcher { contract_address: eoa_address.starknet };
        assert!(eoa.is_initialized());
    }
}
