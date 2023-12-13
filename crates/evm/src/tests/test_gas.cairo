use core::option::OptionTrait;

use evm::gas::calculate_intrinsic_gas_cost;
use starknet::EthAddress;
use utils::eth_transaction::{EthereumTransaction, LegacyTransaction, EthereumTransactionTrait};
use utils::helpers::U256Trait;

#[test]
fn test_calculate_intrinsic_gas_cost() {
    // TODO(gas): handle access_list_cost
    // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
    // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
    //   16      16      16       16      16      16      16      4        4      16
    //   + 21000
    //   + 0
    //   ---------------------------
    //   = 21136
    let rlp_encoded: u256 = 0xc981f781808184000012;

    let calldata = rlp_encoded.to_bytes();
    let destination: Option<EthAddress> = 'vitalik.eth'.try_into();

    let tx: EthereumTransaction = EthereumTransaction::LegacyTransaction(
        LegacyTransaction {
            nonce: 0,
            gas_price: 50,
            gas_limit: 433926,
            destination: destination,
            amount: 1,
            calldata: calldata,
            chain_id: 0x1
        }
    );

    let expected_cost: u128 = 21136;
    let out_cost: u128 = calculate_intrinsic_gas_cost(tx.destination(), tx.calldata());

    assert(out_cost == expected_cost, 'wrong cost');
}

#[test]
fn test_calculate_intrinsic_gas_cost_without_destination() {
    // TODO(gas): handle access_list_cost
    // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
    // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
    //   16      16      16       16      16      16      16      4        4      16
    //   + 21000
    //   + (32000 + 2)
    //   ---------------------------
    //   = 53138
    let rlp_encoded: u256 = 0xc981f781808184000012;

    let calldata = rlp_encoded.to_bytes();

    let tx: EthereumTransaction = EthereumTransaction::LegacyTransaction(
        LegacyTransaction {
            nonce: 0,
            gas_price: 50,
            gas_limit: 433926,
            destination: Option::None(()),
            amount: 1,
            calldata: calldata,
            chain_id: 0x1
        }
    );

    let expected_cost: u128 = 53138;
    let out_cost: u128 = calculate_intrinsic_gas_cost(tx.destination(), tx.calldata());

    assert(out_cost == expected_cost, 'wrong cost');
}
