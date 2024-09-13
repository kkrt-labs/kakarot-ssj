use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::interface::IKakarotCore;
use contracts::kakarot_core::kakarot::{KakarotCore, KakarotCore::{KakarotCoreState}};
use core::num::traits::Zero;
use core::starknet::get_tx_info;
use core::starknet::{EthAddress, get_caller_address};
use evm::backend::starknet_backend;
use evm::backend::validation::validate_eth_tx;
use evm::model::{TransactionResult, Address};
use evm::{EVMTrait};
use utils::eth_transaction::transaction::{TransactionTrait, Transaction};

#[starknet::interface]
pub trait IEthRPC<T> {
    /// Returns the balance of the specified address.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to get the balance from
    ///
    /// # Returns
    ///
    /// The balance of the address as a u256
    fn eth_get_balance(self: @T, address: EthAddress) -> u256;

    /// Returns the number of transactions sent from the specified address.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to get the transaction count from
    ///
    /// # Returns
    ///
    /// The transaction count of the address as a u64
    fn eth_get_transaction_count(self: @T, address: EthAddress) -> u64;

    /// Returns the current chain ID.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Returns
    ///
    /// The chain ID as a u64
    fn eth_chain_id(self: @T) -> u64;

    /// Executes a new message call immediately without creating a transaction on the block chain.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `origin` - The address the transaction is sent from
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_call(self: @T, origin: EthAddress, tx: Transaction) -> (bool, Span<u8>, u64);

    /// Generates and returns an estimate of how much gas is necessary to allow the transaction to
    /// complete.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `origin` - The address the transaction is sent from
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The estimated gas as a u64
    fn eth_estimate_gas(self: @T, origin: EthAddress, tx: Transaction) -> (bool, Span<u8>, u64);

    //TODO: make this an internal function. The account contract should call
    //eth_send_raw_transaction.
    /// Executes a transaction and possibly modifies the state.
    ///
    /// # Arguments
    ///
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_send_transaction(ref self: T, tx: Transaction) -> (bool, Span<u8>, u64);

    /// Executes an unsigned transaction.
    ///
    /// This is a modified version of the eth_sendRawTransaction function.
    /// Signature validation should be done before calling this function.
    ///
    /// # Arguments
    ///
    /// * `tx_data` - The unsigned transaction data as a Span<u8>
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_send_raw_unsigned_tx(ref self: T, tx_data: Span<u8>) -> (bool, Span<u8>, u64);
}


#[starknet::embeddable]
pub impl EthRPC<
    TContractState, impl KakarotState: KakarotCoreState<TContractState>, +Drop<TContractState>
> of IEthRPC<TContractState> {
    fn eth_get_balance(self: @TContractState, address: EthAddress) -> u256 {
        panic!("unimplemented")
    }

    fn eth_get_transaction_count(self: @TContractState, address: EthAddress) -> u64 {
        panic!("unimplemented")
    }

    fn eth_chain_id(self: @TContractState) -> u64 {
        panic!("unimplemented")
    }

    fn eth_call(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        let mut kakarot_state = KakarotState::get_state();
        if !is_view(@kakarot_state) {
            core::panic_with_felt252('fn must be called, not invoked');
        };

        let origin = Address {
            evm: origin, starknet: kakarot_state.compute_starknet_address(origin)
        };

        let TransactionResult { success, return_data, gas_used, state: _state } =
            EVMTrait::process_transaction(
            ref kakarot_state, origin, tx, tx.effective_gas_price(Option::None), 0
        );

        (success, return_data, gas_used)
    }

    fn eth_estimate_gas(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }

    //TODO: make this one internal, and the eth_send_raw_unsigned_tx one public
    fn eth_send_transaction(
        ref self: TContractState, mut tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        let mut kakarot_state = KakarotState::get_state();
        let (gas_price, intrinsic_gas) = validate_eth_tx(@kakarot_state, tx);

        let starknet_caller_address = get_caller_address();
        let account = IAccountDispatcher { contract_address: starknet_caller_address };
        let origin = Address { evm: account.get_evm_address(), starknet: starknet_caller_address };

        let TransactionResult { success, return_data, gas_used, mut state } =
            EVMTrait::process_transaction(
            ref kakarot_state, origin, tx, gas_price, intrinsic_gas
        );
        starknet_backend::commit(ref state).expect('Committing state failed');
        (success, return_data, gas_used)
    }

    fn eth_send_raw_unsigned_tx(
        ref self: TContractState, tx_data: Span<u8>
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }
}

trait IEthRPCInternal<T> {
    fn eth_send_transaction(
        ref self: T, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64);
}

impl EthRPCInternalImpl<TContractState, +Drop<TContractState>> of IEthRPCInternal<TContractState> {
    fn eth_send_transaction(
        ref self: TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }
}

fn is_view(self: @KakarotCore::ContractState) -> bool {
    let tx_info = get_tx_info().unbox();

    // If the account that originated the transaction is not zero, this means we
    // are in an invoke transaction instead of a call; therefore, `eth_call` is being
    // wrongly called For invoke transactions, `eth_send_transaction` must be used
    if !tx_info.account_contract_address.is_zero() {
        return false;
    }
    true
}
