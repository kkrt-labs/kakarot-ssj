use contracts::contract_account::{ContractAccount, ContractAccountTrait};
use contracts::kakarot_core::interface::{IKakarotCore};
use contracts::kakarot_core::{KakarotCore};
use evm::errors::EVMError;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::EthAddress;


/// Returns the balance in native token for a given EVM account (EOA or CA)
/// This is equivalent to checking the balance in native coin, i.e. ETHER of an account in Ethereum
fn balance(evm_address: EthAddress) -> Result<u256, EVMError> {
    // Get access to Kakarot State locally
    let kakarot_state = KakarotCore::unsafe_new_contract_state();

    let eoa_starknet_address = kakarot_state.eoa_starknet_address(evm_address);

    // Case 1: EOA is deployed
    // BALANCE is the EOA's native_token.balanceOf(eoa_starknet_address)
    if !eoa_starknet_address.is_zero() {
        let native_token_address = kakarot_state.native_token();
        // TODO: make sure this part of the codebase is upgradable
        // As native_token might become a snake_case implementation
        // instead of camelCase
        let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
        return Result::Ok(native_token.balanceOf(eoa_starknet_address));
    }

    // Case 2: EOA is not deployed and CA is deployed
    // We check if a contract account is initialized at evm_address
    // A good condition to check is nonce > 0, as deploying a contract account
    // will set its nonce to 1
    let ca = ContractAccountTrait::new(evm_address);
    let nonce = ca.nonce()?;
    if nonce != 0 {
        return ca.balance();
    }

    // Case 3: No EOA nor CA are deployed at `evm_address`
    // Return 0
    Result::Ok(0)
}
