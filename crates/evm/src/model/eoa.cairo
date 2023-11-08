use contracts::kakarot_core::kakarot::KakarotCore::{ContractStateEventEmitter, EOADeployed};
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{IKakarotCore, KakarotCore, KakarotCore::KakarotCoreInternal};
use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED, EOA_EXISTS};
use evm::model::account::{Account, AccountTrait};
use evm::model::{AccountType, Address};
use integer::BoundedInt;
use starknet::{EthAddress, ContractAddress, get_contract_address, deploy_syscall};

#[generate_trait]
impl EOAImpl of EOATrait {
    /// Deploys a new EOA contract.
    ///
    /// # Arguments
    ///
    /// * `evm_address` - The EVM address of the EOA to deploy.
    fn deploy(evm_address: EthAddress) -> Result<Address, EVMError> {
        // Unlike CAs, there is not check for the existence of an EOA prealably to calling `EOATrait::deploy` - therefore, we need to check that there is no collision.
        let mut is_deployed = AccountTrait::is_deployed(evm_address);
        if is_deployed {
            return Result::Err(EVMError::DeployError(EOA_EXISTS));
        }

        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let account_class_hash = kakarot_state.account_class_hash();
        let kakarot_address = get_contract_address();
        let calldata: Span<felt252> = array![kakarot_address.into(), evm_address.into()].span();

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
                Result::Ok(Address { evm: evm_address, starknet: starknet_address })
            },
            Result::Err(err) => panic(err)
        }
    }
}
