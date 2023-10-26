use contracts::kakarot_core::{IKakarotCore, KakarotCore};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED, EOA_EXISTS};
use evm::model::{Account, AccountType};
use integer::BoundedInt;
use openzeppelin::token::erc20::interface::{
    IERC20CamelSafeDispatcher, IERC20CamelSafeDispatcherTrait
};
use starknet::{EthAddress, ContractAddress, get_contract_address, deploy_syscall};
use utils::helpers::ResultExTrait;

#[derive(Copy, Drop)]
struct EOA {
    evm_address: EthAddress,
    starknet_address: ContractAddress
}

const EOA_CLASS_HASH: felt252 = '123';

#[generate_trait]
impl EOAImpl of EOATrait {
    /// Deploys a new EOA contract.
    fn deploy(evm_address: EthAddress) -> Result<EOA, EVMError> {
        //TODO finish in another PR(I started but realised it's out of scope)
        // let maybe_eoa = EOATrait::at(evm_address)?;
        // if maybe_eoa.is_some() {
        //     return Result::Err(EVMError::DeployError(EOA_EXISTS));
        // }

        // let kakarot_address = get_contract_address();
        // let calldata: Span<felt252> = array![kakarot_address.into(), evm_address.into()].span();

        // let maybe_address = deploy_syscall(
        //     EOA_CLASS_HASH.try_into().unwrap(), evm_address.into(), calldata, false
        // );

        // // Panic with err as syscall failure can't be caught, so we can't manage
        // // the error
        // match maybe_address {
        //     Result::Ok((
        //         contract_address, _
        //     )) => {
        //         Result::Ok(EOA { evm_address, starknet_address: contract_address }) },
        //     Result::Err(err) => panic(err)
        // }
        panic_with_felt252('unimplemented')
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
                storage: Default::default(),
                nonce: 1,
                selfdestruct: false
            }
        )
    }

    fn at(evm_address: EthAddress) -> Result<Option<EOA>, EVMError> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let eoa_starknet_address = kakarot_state.eoa_starknet_address(evm_address);
        if !eoa_starknet_address.is_zero() {
            return Result::Ok(
                Option::Some(EOA { evm_address, starknet_address: eoa_starknet_address })
            );
        } else {
            return Result::Ok(Option::None);
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
}
