//! Contract Account related functions to interact with the storage of a
//! contract account.  The storage of a contract account is embedded in
//! KakarotCore's storage.

use alexandria_storage::list::{List, ListTrait};
use contracts::contract_account::{
    IContractAccountDispatcher, IContractAccountDispatcherTrait, IContractAccount,
    IContractAccountSafeDispatcher, IContractAccountSafeDispatcherTrait
};
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{
    KakarotCore, IKakarotCore, KakarotCore::ContractStateEventEmitter,
    KakarotCore::ContractAccountDeployed, KakarotCore::KakarotCoreInternal
};
use contracts::uninitialized_account::{
    IUninitializedAccountDispatcher, IUninitializedAccountDispatcherTrait
};
use evm::context::Status;
use evm::errors::{
    EVMError, READ_SYSCALL_FAILED, WRITE_SYSCALL_FAILED, ACCOUNT_EXISTS, DEPLOYMENT_FAILED,
    CONTRACT_ACCOUNT_EXISTS, CONTRACT_SYSCALL_FAILED
};
use evm::execution::execute;
use evm::model::account::{Address, Account, AccountTrait};
use evm::model::{AccountType};
use hash::{HashStateTrait, HashStateExTrait};
use openzeppelin::token::erc20::interface::{
    IERC20CamelSafeDispatcher, IERC20CamelSafeDispatcherTrait
};
use poseidon::PoseidonTrait;
use starknet::{
    deploy_syscall, StorageBaseAddress, storage_base_address_from_felt252, Store, EthAddress,
    SyscallResult, get_contract_address, ContractAddress
};
use utils::helpers::{ByteArrayExTrait, ResultExTrait};
use utils::storage::{compute_storage_base_address};
use utils::traits::{StorageBaseAddressIntoFelt252, StoreBytes31};


#[generate_trait]
impl ContractAccountImpl of ContractAccountTrait {
    /// Deploys a contract account by setting up the storage associated to a
    /// contract account for a particular EVM address, setting the nonce to 1,
    /// storing the contract bytecode and emitting a ContractAccountDeployed
    /// event.
    ///
    /// `deploy` is only called when commiting a transaction. We already
    /// checked that no account exists at this address prealably.
    /// # Arguments
    /// * `origin` - The EVM address of the transaction sender
    /// * `evm_address` - The EVM address of the contract account
    /// * `bytecode` - The deploy bytecode
    /// # Returns
    /// * The evm_address and starknet_address the CA is deployed at - which is KakarotCore
    /// # Errors
    /// * `ACCOUNT_EXISTS` - If a contract account already exists at the given `evm_address`
    fn deploy(evm_address: EthAddress, bytecode: Span<u8>) -> Result<Address, EVMError> {
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
                IUninitializedAccountDispatcher { contract_address: starknet_address }
                    .initialize(kakarot_state.ca_class_hash());

                // Initialize the account
                let account = IContractAccountDispatcher { contract_address: starknet_address };
                account.set_nonce(1);
                account.set_bytecode(bytecode);

                // Kakarot Core logic
                kakarot_state
                    .set_address_registry(
                        evm_address, StoredAccountType::ContractAccount(starknet_address)
                    );
                kakarot_state.emit(ContractAccountDeployed { evm_address, starknet_address });
                Result::Ok(Address { evm: evm_address, starknet: starknet_address })
            },
            Result::Err(err) => panic(err)
        }
    }

    #[inline(always)]
    fn selfdestruct(self: @Address) -> Result<(), EVMError> {
        let contract_account = IContractAccountSafeDispatcher { contract_address: *self.starknet };
        contract_account.selfdestruct().map_err(EVMError::SyscallFailed(CONTRACT_SYSCALL_FAILED))
    }

    /// Returns the addresses of a CA at the given `evm_address`.
    #[inline(always)]
    fn at(evm_address: EthAddress) -> Result<Option<Address>, EVMError> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let maybe_account = kakarot_state.address_registry(evm_address);
        match maybe_account {
            Option::Some((
                account, sn_address
            )) => {
                match account {
                    AccountType::EOA => Result::Ok(Option::None),
                    AccountType::ContractAccount => Result::Ok(
                        Option::Some(Address { evm: evm_address, starknet: sn_address })
                    ),
                    AccountType::Unknown => Result::Ok(Option::None)
                }
            },
            Option::None => Result::Ok(Option::None)
        }
    }

    /// Returns the nonce of a contract account.
    /// # Arguments
    /// * `self` - The address of the Contract Account
    #[inline(always)]
    fn fetch_nonce(self: @Address) -> Result<u64, EVMError> {
        let contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        Result::Ok(contract_account.nonce())
    }

    /// Sets the nonce of a contract account.
    /// The new nonce is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_nonce"), evm_address), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The address of the Contract Account
    #[inline(always)]
    fn store_nonce(self: @Address, nonce: u64) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        contract_account.set_nonce(nonce);
        Result::Ok(())
    }

    /// Returns the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    #[inline(always)]
    fn fetch_storage(self: @Address, key: u256) -> Result<u256, EVMError> {
        let contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        Result::Ok(contract_account.storage_at(key))
    }

    /// Sets the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The address of the Contract Account
    /// * `key` - The key to set
    /// * `value` - The value to set
    #[inline(always)]
    fn store_storage(self: @Address, key: u256, value: u256) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        contract_account.set_storage_at(key, value);
        Result::Ok(())
    }

    /// Stores the EVM bytecode of a contract account in Kakarot Core's contract storage.  The bytecode is first packed
    /// into a ByteArray and then stored in the contract storage.
    /// # Arguments
    /// * `evm_address` - The EVM address of the contract account
    /// * `bytecode` - The bytecode to store
    fn store_bytecode(self: @Address, bytecode: Span<u8>) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        contract_account.set_bytecode(bytecode);
        Result::Ok(())
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a ByteArray.
    /// # Arguments
    /// * `self` - The address of the Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    fn fetch_bytecode(self: @Address) -> Result<Span<u8>, EVMError> {
        let contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        let bytecode = contract_account.bytecode();
        Result::Ok(bytecode)
    }

    /// Returns true if the given `offset` is a valid jump destination in the bytecode.
    /// The valid jump destinations are stored in Kakarot Core's contract storage first.
    /// # Arguments
    /// * `offset` - The offset to check
    /// # Returns
    /// * `true` - If the offset is a valid jump destination
    /// * `false` - Otherwise
    #[inline(always)]
    fn is_false_positive_jumpdest(self: @Address, offset: usize) -> Result<bool, EVMError> {
        let contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        let is_false_jumpdest = contract_account.is_false_jumpdest(offset);
        Result::Ok(is_false_jumpdest)
    }

    /// Sets the given `offset` as a valid jump destination in the bytecode.
    /// The valid jump destinations are stored in Kakarot Core's contract storage.
    /// # Arguments
    /// * `self` - The address of the ContractAccount
    /// * `offset` - The offset to set as a valid jump destination
    #[inline(always)]
    fn set_false_positive_jumpdest(self: @Address, offset: usize) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher { contract_address: *self.starknet };
        contract_account.set_false_positive_jumpdest(offset);
        Result::Ok(())
    }
}
