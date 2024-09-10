use contracts::IKakarotCore;
use starknet::storage::StorageTrait;
use core::ops::SnapshotDeref;
use contracts::kakarot_core::KakarotCore;
use utils::eth_transaction::transaction::{Transaction, TransactionTrait};
use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use core::starknet::{get_caller_address, get_tx_info};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::constants::POW_2_32;
use core::starknet::storage::{StoragePointerReadAccess};
use utils::eth_transaction::get_effective_gas_price;

pub fn validate_eth_tx(kakarot_state: @KakarotCore::ContractState, tx: Transaction){
    let kakarot_storage = kakarot_state.snapshot_deref().storage();
    // Validate transaction

    // Validate chain_id for post eip155
    let tx_chain_id = tx.chain_id();
    let kakarot_chain_id: u64 = get_tx_info()
        .chain_id
        .try_into()
        .unwrap() % POW_2_32
        .try_into()
        .unwrap();
    if (tx_chain_id.is_some()) {
        assert(tx_chain_id.unwrap() == kakarot_chain_id, 'Invalid chain id');
    }

    // Validate nonce
    let starknet_caller_address = get_caller_address();
    let account = IAccountDispatcher { contract_address: starknet_caller_address };
    assert(account.get_nonce() == tx.nonce(), 'Invalid nonce');

    // Validate gas
    assert(tx.gas_limit() <= kakarot_state.get_block_gas_limit(), 'Tx gas > Block gas');
    let block_base_fee = kakarot_storage.Kakarot_base_fee.read();
    assert(tx.max_fee_per_gas() <= block_base_fee.into(), 'Max fee per gas too low');
    assert(
        tx.max_priority_fee_per_gas().unwrap_or(0) <= tx.max_fee_per_gas(),
        'Max prio fee > max fee per gas'
    );

    // Validate balance
    let evm_address = account.get_evm_address();
    let balance = IERC20CamelDispatcher {
        contract_address: kakarot_storage.Kakarot_native_token_address.read()
    }
        .balanceOf(starknet_caller_address);
    let max_gas_fee = tx.gas_limit().into() * tx.max_fee_per_gas();
    let tx_cost = tx.value() + max_gas_fee.into();
    assert(tx_cost <= balance, 'Not enough ETH');

    let effective_gas_price = get_effective_gas_price(
        Option::Some(tx.max_fee_per_gas()),
        tx.max_priority_fee_per_gas(),
        block_base_fee.into()
    );
    assert(effective_gas_price.is_ok(), 'Invalid effective gas price');
}
