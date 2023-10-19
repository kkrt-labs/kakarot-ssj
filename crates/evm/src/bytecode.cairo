use contracts::kakarot_core::interface::{IKakarotCore};
use contracts::kakarot_core::{ContractAccountStorage, KakarotCore};
use starknet::EthAddress;

/// Returns the bytecode of the EVM account (EOA or CA)
fn bytecode(evm_address: EthAddress) -> Span<u8> {
    // Get access to Kakarot State locally
    let kakarot_state = KakarotCore::unsafe_new_contract_state();

    let eoa_starknet_address = kakarot_state.eoa_starknet_address(evm_address);

    // Case 1: EOA is deployed
    if !eoa_starknet_address.is_zero() {
        return Default::default().span();
    }

    // Case 2: EOA is not deployed and CA is deployed
    let ca_storage = kakarot_state.contract_account_storage(evm_address);
    // Once bytecode is implemented: return ca_storage.bytecode;
    return Default::default().span();
}

