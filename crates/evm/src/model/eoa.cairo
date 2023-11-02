use contracts::kakarot_core::kakarot::KakarotCore::{ContractStateEventEmitter, EOADeployed};
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{IKakarotCore, KakarotCore};
use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED, EOA_EXISTS};
use evm::model::account::{Account, AccountTrait};
use evm::model::{AccountType};
use integer::BoundedInt;
use openzeppelin::token::erc20::interface::{
    IERC20CamelSafeDispatcher, IERC20CamelSafeDispatcherTrait
};
use starknet::{EthAddress, ContractAddress, get_contract_address, deploy_syscall};
use utils::helpers::ResultExTrait;


#[derive(Copy, Drop, PartialEq)]
struct EOA {
    evm_address: EthAddress,
    starknet_address: ContractAddress
}

#[generate_trait]
impl EOAImpl of EOATrait {
    /// Deploys a new EOA contract.
    fn deploy(evm_address: EthAddress) -> Result<EOA, EVMError> {
        let mut maybe_acc = AccountTrait::account_type_at(evm_address)?;
        if maybe_acc.is_some() {
            return Result::Err(EVMError::DeployError(EOA_EXISTS));
        }

        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let account_class_hash = kakarot_state.account_class_hash();
        let kakarot_address = get_contract_address();
        let calldata: Span<felt252> = array![kakarot_address.into(), evm_address.into()].span();

        let maybe_address = deploy_syscall(account_class_hash, evm_address.into(), calldata, false);
        let maybe_address = deploy_syscall(account_class_hash, evm_address.into(), calldata, false);
        // Panic with err as syscall failure can't be caught, so we can't manage
        // the error
        match maybe_address {
            Result::Ok((
                starknet_address, _
            )) => {
                let account = IUninitializedAccountDispatcher {
                    contract_address: starknet_address
                };
                account.initialize(kakarot_state.eoa_class_hash());
                kakarot_state
                    .set_address_registry(evm_address, StoredAccountType::EOA(starknet_address));
                kakarot_state.emit(EOADeployed { evm_address, starknet_address });
                Result::Ok(EOA { evm_address, starknet_address })
            },
            Result::Err(err) => panic(err)
        }
    }

    /// Retrieves the EOA content stored at address `evm_address`.
    /// There is no way to access the nonce of an EOA currently But putting 1
    /// shouldn't have any impact and is safer than 0 since has_code_or_nonce is
    /// used in some places to trigger collision
    /// # Arguments
    /// * `evm_address` - The EVM address of the eoa
    /// # Returns
    /// * The corresponding Account instance
    fn fetch(self: @EOA) -> Result<Account, EVMError> {
        Result::Ok(
            Account {
                account_type: AccountType::EOA(*self),
                code: Default::default().span(),
                nonce: 1,
                selfdestruct: false
            }
        )
    }

    /// Returns an EOA instance from the given `evm_address`.
    fn at(evm_address: EthAddress) -> Result<Option<EOA>, EVMError> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let account = kakarot_state.address_registry(evm_address);
        match account {
            StoredAccountType::UninitializedAccount => Result::Ok(Option::None),
            StoredAccountType::EOA(eoa_starknet_address) => Result::Ok(
                Option::Some(EOA { evm_address, starknet_address: eoa_starknet_address })
            ),
            StoredAccountType::ContractAccount(_) => Result::Ok(Option::None),
        }
    }


    fn balance(self: @EOA) -> Result<u256, EVMError> {
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

    fn evm_address(self: @EOA) -> EthAddress {
        *self.evm_address
    }

    fn starknet_address(self: @EOA) -> ContractAddress {
        *self.starknet_address
    }
}
