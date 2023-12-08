use evm::gas::calculate_intrinsic_cost;
use utils::eth_transaction::{
    EthTransactionTrait, EncodedTransactionTrait, EncodedTransaction, TransactionMetadata,
    EthTransactionError, EthereumTransaction
};
use utils::tests::test_data::{
    legacy_rlp_encoded_tx, legacy_rlp_encoded_deploy_tx, eip_2930_encoded_tx, eip_1559_encoded_tx
};

#[test]
fn test_calculate_intrinsic_cost() {
    let data = legacy_rlp_encoded_tx();

    let encoded_tx: Option<EncodedTransaction> = data.try_into();
    let encoded_tx: EncodedTransaction = encoded_tx.unwrap();
    let tx: EthereumTransaction = encoded_tx.decode().expect('decode failed');

    let cost: u128 = calculate_intrinsic_cost(@tx);
    assert(cost > 0, 'cant be zero');
}
