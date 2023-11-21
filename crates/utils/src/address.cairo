use core::traits::TryInto;
use core::array::ArrayTrait;
use evm::errors::EVMError;
use starknet::EthAddress;
use utils::errors::RLPErrorTrait;
use utils::helpers::{U8SpanExTrait, U64Trait, U256Trait, EthAddressExTrait, ArrayExtTrait};
use utils::rlp::{RLPTrait, RLPItem};
use utils::traits::{TryIntoResult, U256TryIntoEthAddress};
use utils::math::WrappingBitshift;

use debug::PrintTrait;
/// Computes the address of the new account that needs to be created.
///
/// # Arguments
///
/// * `sender_address`: The address of the account that wants to create the new account.
/// * `sender_nonce`: The transaction count of the account that wants to create the new account.
///
/// # Returns
///
/// The computed address of the new account.
fn compute_contract_address(sender_address: EthAddress, sender_nonce: u64) -> EthAddress {
    let mut sender_address: RLPItem = RLPItem::String(sender_address.to_bytes().span());
    let sender_nonce: RLPItem = RLPItem::String(sender_nonce.to_bytes().span());
    let computed_address = U8SpanExTrait::compute_keccak256_hash(RLPTrait::encode_sequence(array![sender_address, sender_nonce].span()));
    let canonical_address = computed_address & 0xffffffffffffffffffffffffffffffffffffffff;
    canonical_address.try_into().unwrap()
}


/// Computes the address of the new account that needs to be created, which is
/// based on the sender address, salt, and the call data.
///
/// # Parameters
///
/// * `sender_address`: The address of the account that wants to create the new account.
/// * `salt`: Address generation salt.
/// * `bytecode`: The code of the new account to be created.
///
/// # Returns
///
/// The computed address of the new account.
fn compute_create2_contract_address(
    sender_address: EthAddress, salt: u256, bytecode: Span<u8>
) -> Result<EthAddress, EVMError> {
    let hash = bytecode.compute_keccak256_hash().to_bytes();

    let sender_address = sender_address.to_bytes().span();

    let salt = salt.to_bytes();

    let mut preimage: Array<u8> = array![];

    preimage.append_span(array![0xff].span());
    preimage.append_span(sender_address);
    preimage.append_span(salt);
    preimage.append_span(hash);

    let address_hash = preimage.span().compute_keccak256_hash().to_bytes();

    let address: EthAddress = address_hash.slice(12, 20).try_into_result()?;

    Result::Ok(address)
}