use core::option::OptionTrait;

use evm::gas::{
    calculate_intrinsic_gas_cost, calculate_memory_gas_cost, ACCESS_LIST_ADDRESS,
    ACCESS_LIST_STORAGE_KEY
};
use evm::tests::test_utils::evm_address;
use starknet::EthAddress;
use utils::eth_transaction::{
    EthereumTransaction, LegacyTransaction, AccessListTransaction, EthereumTransactionTrait,
    AccessListItem
};
use utils::helpers::{U256Trait, ToBytes};

#[test]
fn test_calculate_intrinsic_gas_cost() {
    // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
    // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
    //   16      16      16       16      16      16      16      4        4      16
    //   + 21000
    //   + 0
    //   ---------------------------
    //   = 21136
    let rlp_encoded: u256 = 0xc981f781808184000012;

    let calldata = rlp_encoded.to_be_bytes();
    let destination: Option<EthAddress> = 'vitalik.eth'.try_into();

    let tx: EthereumTransaction = EthereumTransaction::LegacyTransaction(
        LegacyTransaction {
            nonce: 0,
            gas_price: 50,
            gas_limit: 433926,
            destination,
            amount: 1,
            calldata,
            chain_id: 0x1
        }
    );

    let expected_cost: u128 = 21136;
    let out_cost: u128 = calculate_intrinsic_gas_cost(@tx);

    assert_eq!(out_cost, expected_cost, "wrong cost");
}

#[test]
fn test_calculate_intrinsic_gas_cost_with_access_list() {
    // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
    // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
    //   16      16      16       16      16      16      16      4        4      16
    //   + 21000
    //   + 0
    //   ---------------------------
    //   = 21136
    let rlp_encoded: u256 = 0xc981f781808184000012;

    let calldata = rlp_encoded.to_be_bytes();
    let destination: Option<EthAddress> = 'vitalik.eth'.try_into();

    let access_list = array![
        AccessListItem {
            ethereum_address: evm_address(), storage_keys: array![1, 2, 3, 4, 5].span()
        }
    ]
        .span();

    let tx: EthereumTransaction = EthereumTransaction::AccessListTransaction(
        AccessListTransaction {
            nonce: 0,
            gas_price: 50,
            gas_limit: 433926,
            destination,
            amount: 1,
            calldata,
            chain_id: 0x1,
            access_list
        }
    );

    let expected_cost: u128 = 21136 + ACCESS_LIST_ADDRESS + 5 * ACCESS_LIST_STORAGE_KEY;
    let out_cost: u128 = calculate_intrinsic_gas_cost(@tx);

    assert_eq!(out_cost, expected_cost, "wrong cost");
}


#[test]
fn test_calculate_intrinsic_gas_cost_without_destination() {
    // RLP decoded value: (https://toolkit.abdk.consulting/ethereum#rlp,transaction)
    // ["0xc9", "0x81", "0xf7", "0x81", "0x80", "0x81", "0x84", "0x00", "0x00", "0x12"]
    //   16      16      16       16      16      16      16      4        4      16
    //   + 21000
    //   + (32000 + 2)
    //   ---------------------------
    //   = 53138
    let rlp_encoded: u256 = 0xc981f781808184000012;

    let calldata = rlp_encoded.to_be_bytes();

    let tx: EthereumTransaction = EthereumTransaction::LegacyTransaction(
        LegacyTransaction {
            nonce: 0,
            gas_price: 50,
            gas_limit: 433926,
            destination: Option::None(()),
            amount: 1,
            calldata,
            chain_id: 0x1
        }
    );

    let expected_cost: u128 = 53138;
    let out_cost: u128 = calculate_intrinsic_gas_cost(@tx);

    assert_eq!(out_cost, expected_cost, "wrong cost");
}

#[test]
fn test_calculate_memory_allocation_cost() {
    let size_in_bytes: usize = 10018613;
    let expected_cost: u128 = 192385220;
    let out_cost: u128 = calculate_memory_gas_cost(size_in_bytes);
    assert_eq!(out_cost, expected_cost, "wrong cost");
}
