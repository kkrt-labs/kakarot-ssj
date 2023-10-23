use contracts::kakarot_core::{IKakarotCore, KakarotCore};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use openzeppelin::token::erc20::interface::{
    IERC20CamelSafeDispatcher, IERC20CamelSafeDispatcherTrait
};
use starknet::{EthAddress, ContractAddress};
use utils::helpers::ResultExTrait;

#[derive(Copy, Drop)]
struct EOA {
    evm_address: EthAddress,
    starknet_address: ContractAddress
}

#[generate_trait]
impl EOAImpl of EOATrait {
    ///TODO implement methods for EOA
    fn balance(self: @EOA) -> Result<u256, EVMError> {
        //TODO: read directly from the contract state instead of getting explicit kakarot state
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token_address = kakarot_state.native_token();
        // TODO: make sure this part of the codebase is upgradable
        // As native_token might become a snake_case implementation
        // instead of camelCase
        let native_token = IERC20CamelSafeDispatcher { contract_address: native_token_address };
        //Note: Starknet OS doesn't allow error management of failed syscalls yet.
        // If this call fails, the entire transaction will revert.
        native_token
            .balanceOf(*self.starknet_address)
            .map_err(EVMError::SyscallFailed(CONTRACT_SYSCALL_FAILED))
    }
}
