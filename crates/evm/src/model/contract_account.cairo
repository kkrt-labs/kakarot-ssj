//! Contract Account related functions to interact with the storage of a
//! contract account.  The storage of a contract account is embedded in
//! KakarotCore's storage.

use alexandria_storage::list::{List, ListTrait};
use contracts::contract_account::interface::{
    IContractAccountDispatcher, IContractAccountDispatcherTrait, IContractAccount,
    IContractAccountSafeDispatcher, IContractAccountSafeDispatcherTrait
};
use contracts::kakarot_core::kakarot::StoredAccountType;
use contracts::kakarot_core::{
    KakarotCore, IKakarotCore, KakarotCore::ContractStateEventEmitter,
    KakarotCore::ContractAccountDeployed
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


/// Wrapper struct around an evm_address corresponding to a ContractAccount
#[derive(Copy, Drop, PartialEq)]
struct ContractAccount {
    evm_address: EthAddress,
    starknet_address: ContractAddress
}


#[generate_trait]
impl ContractAccountImpl of ContractAccountTrait {
    /// Deploys a contract account by setting up the storage associated to a
    /// contract account for a particular EVM address, setting the nonce to 1,
    /// storing the contract bytecode and emitting a ContractAccountDeployed
    /// event.
    /// # Arguments
    /// * `origin` - The EVM address of the transaction sender
    /// * `evm_address` - The EVM address of the contract account
    /// * `bytecode` - The deploy bytecode
    /// # Returns
    /// * The evm_address and starknet_address the CA is deployed at - which is KakarotCore
    /// # Errors
    /// * `ACCOUNT_EXISTS` - If a contract account already exists at the given `evm_address`
    fn deploy(evm_address: EthAddress, bytecode: Span<u8>) -> Result<ContractAccount, EVMError> {
        let mut maybe_acc = AccountTrait::account_type_at(evm_address)?;
        if maybe_acc.is_some() {
            return Result::Err(EVMError::DeployError(CONTRACT_ACCOUNT_EXISTS));
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
                Result::Ok(ContractAccount { evm_address, starknet_address })
            },
            Result::Err(err) => panic(err)
        }
    }

    #[inline(always)]
    fn address(self: @ContractAccount) -> Address {
        Address { evm: *self.evm_address, starknet: *self.starknet_address }
    }

    #[inline(always)]
    fn selfdestruct(self: @ContractAccount) -> Result<(), EVMError> {
        let contract_account = IContractAccountSafeDispatcher {
            contract_address: *self.starknet_address
        };
        contract_account.selfdestruct().map_err(EVMError::SyscallFailed(CONTRACT_SYSCALL_FAILED))
    }

    /// Returns a ContractAccount instance from the given `evm_address`.
    #[inline(always)]
    fn at(evm_address: EthAddress) -> Result<Option<ContractAccount>, EVMError> {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let account = kakarot_state.address_registry(evm_address);

        match account {
            StoredAccountType::UninitializedAccount => Result::Ok(Option::None),
            StoredAccountType::EOA(_) => Result::Ok(Option::None),
            StoredAccountType::ContractAccount(ca_starknet_address) => Result::Ok(
                Option::Some(ContractAccount { evm_address, starknet_address: ca_starknet_address })
            ),
        }
    }

    /// Retrieves the contract account content stored at address `evm_address`.
    /// # Arguments
    /// * `evm_address` - The EVM address of the contract account
    /// # Returns
    /// * The corresponding Account instance
    fn fetch(self: @ContractAccount) -> Result<Account, EVMError> {
        Result::Ok(
            Account {
                account_type: AccountType::ContractAccount(*self),
                code: self.load_bytecode()?,
                nonce: self.nonce()?,
                selfdestruct: false
            }
        )
    }

    /// Returns the nonce of a contract account.
    /// # Arguments
    /// * `self` - The contract account instance
    #[inline(always)]
    fn nonce(self: @ContractAccount) -> Result<u64, EVMError> {
        let contract_account = IContractAccountDispatcher {
            contract_address: *self.starknet_address
        };
        Result::Ok(contract_account.nonce())
    }

    #[inline(always)]
    fn starknet_address(self: @ContractAccount) -> ContractAddress {
        *self.starknet_address
    }


    #[inline(always)]
    fn evm_address(self: @ContractAccount) -> EthAddress {
        *self.evm_address
    }

    /// Sets the nonce of a contract account.
    /// The new nonce is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_nonce"), evm_address), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The contract account instance
    #[inline(always)]
    fn set_nonce(ref self: ContractAccount, nonce: u64) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.starknet_address
        };
        contract_account.set_nonce(nonce);
        Result::Ok(())
    }

    /// Increments the nonce of a contract account.
    /// The new nonce is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_nonce"), evm_address), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The contract account instance
    #[inline(always)]
    fn increment_nonce(ref self: ContractAccount) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.starknet_address
        };
        contract_account.increment_nonce();
        Result::Ok(())
    }

    /// Returns the balance of a contract account.
    /// * `self` - The contract account instance
    #[inline(always)]
    fn balance(self: @ContractAccount) -> Result<u256, EVMError> {
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

    /// Returns the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    #[inline(always)]
    fn storage_at(self: @ContractAccount, key: u256) -> Result<u256, EVMError> {
        let contract_account = IContractAccountDispatcher {
            contract_address: *self.starknet_address
        };
        Result::Ok(contract_account.storage_at(key))
    }

    /// Sets the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The contract account instance
    /// * `key` - The key to set
    /// * `value` - The value to set
    #[inline(always)]
    fn set_storage_at(ref self: ContractAccount, key: u256, value: u256) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.starknet_address
        };
        contract_account.set_storage_at(key, value);
        Result::Ok(())
    }

    /// Stores the EVM bytecode of a contract account in Kakarot Core's contract storage.  The bytecode is first packed
    /// into a ByteArray and then stored in the contract storage.
    /// # Arguments
    /// * `evm_address` - The EVM address of the contract account
    /// * `bytecode` - The bytecode to store
    fn store_bytecode(ref self: ContractAccount, bytecode: Span<u8>) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.starknet_address
        };
        contract_account.set_bytecode(bytecode);
        Result::Ok(())
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a ByteArray.
    /// # Arguments
    /// * `self` - The Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    fn load_bytecode(self: @ContractAccount) -> Result<Span<u8>, EVMError> {
        let contract_account = IContractAccountDispatcher {
            contract_address: *self.starknet_address
        };
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
    fn is_false_positive_jumpdest(self: @ContractAccount, offset: usize) -> Result<bool, EVMError> {
        let contract_account = IContractAccountDispatcher {
            contract_address: *self.starknet_address
        };
        let is_false_jumpdest = contract_account.is_false_jumpdest(offset);
        Result::Ok(is_false_jumpdest)
    }

    /// Sets the given `offset` as a valid jump destination in the bytecode.
    /// The valid jump destinations are stored in Kakarot Core's contract storage.
    /// # Arguments
    /// * `self` - The ContractAccount
    /// * `offset` - The offset to set as a valid jump destination
    #[inline(always)]
    fn set_false_positive_jumpdest(
        ref self: ContractAccount, offset: usize
    ) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.starknet_address
        };
        contract_account.set_false_positive_jumpdest(offset);
        Result::Ok(())
    }
}
