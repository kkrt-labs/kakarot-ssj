use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{KakarotCore, KakarotCore::KakarotCoreImpl};
use evm::errors::{ensure, EVMError, EOA_EXISTS};
use evm::model::{Address, AddressTrait, Environment};
use evm::state::{State, StateTrait};
use starknet::{
    EthAddress, get_contract_address, deploy_syscall, get_tx_info, get_block_info,
    SyscallResultTrait
};
use utils::constants;


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
    // Unlike CAs, there is not check for the existence of an EOA prealably to calling `EOATrait::deploy` - therefore, we need to check that there is no collision.
    let mut is_deployed = evm_address.is_deployed();
    ensure(!is_deployed, EVMError::DeployError(EOA_EXISTS))?;

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    let account_class_hash = kakarot_state.account_class_hash();
    let kakarot_address = get_contract_address();
    let calldata: Span<felt252> = array![kakarot_address.into(), evm_address.into()].span();

    let (starknet_address, _) = deploy_syscall(
        account_class_hash, evm_address.into(), calldata, true
    )
        .unwrap_syscall();

    Result::Ok(Address { evm: evm_address, starknet: starknet_address })
}

fn get_bytecode(evm_address: EthAddress) -> Span<u8> {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    match kakarot_state.address_registry(evm_address) {
        Option::Some((
            acc_type, starknet_address
        )) => {
            let account = IAccountDispatcher { contract_address: starknet_address };
            account.bytecode()
        },
        Option::None => { array![].span() }
    }
}

fn get_env(origin: EthAddress, gas_price: u128) -> Environment {
    let block_info = get_block_info().unbox();
    //TODO(optimization): the coinbase account is deployed from a specific `evm_address` which is specified upon deployment
    // and specific to the chain. Rather than reading from a contract, we could directly use this constant.
    let coinbase = IAccountDispatcher { contract_address: block_info.sequencer_address }
        .get_evm_address();

    // tx.gas_price and env.gas_price have the same values here
    // - this is not always true in EVM transactions
    Environment {
        origin: origin,
        gas_price,
        chain_id: get_tx_info().unbox().chain_id.try_into().unwrap(),
        prevrandao: 0,
        block_number: block_info.block_number,
        block_timestamp: block_info.block_timestamp,
        block_gas_limit: constants::BLOCK_GAS_LIMIT,
        coinbase,
        state: Default::default(),
    }
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
    use super::{State, StateTrait};
    use utils::constants::BURN_ADDRESS;
    use utils::set::{Set, SetTrait};


    fn commit_accounts(ref state: State) -> Result<(), EVMError> {
        let mut account_keys = state.accounts.keyset.to_span();
        loop {
            match account_keys.pop_front() {
                Option::Some(evm_address) => {
                    let account = state.accounts.changes.get(*evm_address).deref();
                    commit(@account, ref state);
                },
                Option::None => { break Result::Ok(()); }
            };
        }
    }

    /// Commits the account to Starknet by updating the account state if it
    /// exists, or deploying a new account if it doesn't.
    ///
    /// Only Contract Accounts can be modified.
    ///
    /// # Arguments
    /// * `self` - The account to commit
    ///
    /// # Returns
    ///
    /// `Ok(())` if the commit was successful, otherwise an `EVMError`.
    //TODO: move state out in starknet backend
    fn commit(self: @Account, ref state: State) {
        let is_deployed = self.evm_address().is_deployed();

        if self.is_precompile() {
            return;
        }

        // Case new account
        if !is_deployed {
            // If SELFDESTRUCT, deploy empty SN account
            self.deploy();

            let has_code_or_nonce = self.has_code_or_nonce();
            if !has_code_or_nonce {
                // Nothing to commit
                return;
            }

            // If SELFDESTRUCT, leave the account empty after deploying it - including
            // burning any leftover balance.
            if (self.is_selfdestruct()) {
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let starknet_address = kakarot_state
                    .compute_starknet_address(BURN_ADDRESS.try_into().unwrap());
                let burn_address = Address {
                    starknet: starknet_address, evm: BURN_ADDRESS.try_into().unwrap()
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

            let account = IAccountDispatcher { contract_address: self.starknet_address() };
            account.write_bytecode(self.bytecode());
            account.set_nonce(*self.nonce);

            //TODO: storage commits are done in the State commitment
            //Storage is handled outside of the account and must be committed after all accounts are committed.
            return;
        };

        // If the account was not scheduled for deployment - then update it if it's deployed.

        let is_created_selfdestructed = self.is_selfdestruct() && self.is_created();
        if is_created_selfdestructed {
            // If the account was created and selfdestructed in the same transaction, we don't need to commit it.
            return;
        }

        let account = IAccountDispatcher { contract_address: self.starknet_address() };

        account.set_nonce(*self.nonce);
        //TODO: handle storage commitment

        // Update bytecode if required (SELFDESTRUCTed contract committed and redeployed)
        //TODO: add bytecode_len entrypoint for optimization
        let bytecode_len = account.bytecode().len();
        if bytecode_len != self.bytecode().len() {
            account.write_bytecode(self.bytecode());
        }
    }

    /// Iterates through the list of pending transfer and triggers them
    fn transfer_native_token(ref self: State) -> Result<(), EVMError> {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token = kakarot_state.native_token();
        loop {
            match self.transfers.pop_front() {
                Option::Some(transfer) => {
                    IERC20CamelDispatcher { contract_address: native_token }
                        .transferFrom(
                            transfer.sender.starknet, transfer.recipient.starknet, transfer.amount
                        );
                },
                Option::None => { break; }
            }
        };
        Result::Ok(())
    }

    /// Iterates through the list of events and emits them.
    fn emit_events(ref self: State) -> Result<(), EVMError> {
        loop {
            match self.events.pop_front() {
                Option::Some(event) => {
                    let mut keys = Default::default();
                    let mut data = Default::default();
                    Serde::<Array<u256>>::serialize(@event.keys, ref keys);
                    Serde::<Array<u8>>::serialize(@event.data, ref data);
                    emit_event_syscall(keys.span(), data.span()).unwrap_syscall();
                },
                Option::None => { break Result::Ok(()); }
            }
        }
    }

    /// Commits storage changes to the KakarotCore contract by writing pending
    /// state changes to Starknet Storage.
    /// commit_storage MUST be called after commit_accounts.
    fn commit_storage(ref self: State) -> Result<(), EVMError> {
        let mut storage_keys = self.accounts_storage.keyset.to_span();
        let result = loop {
            match storage_keys.pop_front() {
                Option::Some(state_key) => {
                    let (evm_address, key, value) = self
                        .accounts_storage
                        .changes
                        .get(*state_key)
                        .deref();
                    let mut account = self.get_account(evm_address);
                    account.commit_storage(key, value);
                },
                Option::None => { break Result::Ok(()); }
            }
        };
        result
    }
}
