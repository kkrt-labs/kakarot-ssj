use contracts::contract_account::{ContractAccount, ContractAccountTrait};
use contracts::kakarot_core::{KakarotCore};
use contracts::kakarot_core::interface::{IKakarotCore};
use evm::errors::{EVMError};
use starknet::EthAddress;

/// Returns the bytecode of the EVM account (EOA or CA)
fn bytecode(evm_address: EthAddress) -> Result<Span<u8>, EVMError> {
    // Get access to Kakarot State locally
    let kakarot_state = KakarotCore::unsafe_new_contract_state();

    let eoa_starknet_address = kakarot_state.eoa_starknet_address(evm_address);

    // Case 1: EOA is deployed
    if !eoa_starknet_address.is_zero() {
        return Result::Ok(Default::default().span());
    }

    // Case 2: EOA is not deployed and CA is deployed
    let ca = ContractAccountTrait::new(evm_address);
    return Result::Ok(Default::default().span());
}

