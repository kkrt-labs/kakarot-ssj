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
use core::array::ArrayTrait;
use debug::PrintTrait;
use evm::context::Status;
use evm::errors::{
    EVMError, READ_SYSCALL_FAILED, WRITE_SYSCALL_FAILED, ACCOUNT_EXISTS, DEPLOYMENT_FAILED,
    CONTRACT_ACCOUNT_EXISTS, CONTRACT_SYSCALL_FAILED
};
use evm::execution::execute;
use evm::model::{Address, Account, AccountType, AccountTrait};
use hash::{HashStateTrait, HashStateExTrait};
use openzeppelin::token::erc20::interface::{
    IERC20CamelSafeDispatcher, IERC20CamelSafeDispatcherTrait
};
use poseidon::PoseidonTrait;
use starknet::{
    deploy_syscall, StorageBaseAddress, storage_base_address_from_felt252, Store, EthAddress,
    SyscallResult, get_contract_address, ContractAddress
};
use utils::helpers::ArrayExtTrait;
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
    fn deploy(
        evm_address: EthAddress, bytecode: Span<u8>, false_positive_jumpdests: Span<usize>
    ) -> Result<Address, EVMError> {
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
                account.set_false_positive_jumpdests(false_positive_jumpdests);
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
    fn selfdestruct(self: @Account) -> Result<(), EVMError> {
        let contract_account = IContractAccountSafeDispatcher {
            contract_address: self.address().starknet
        };
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

    /// Sets the nonce of a contract account.
    /// The new nonce is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_nonce"), evm_address), where `h` is the poseidon hash function.
    /// # Arguments
    /// * `self` - The address of the Contract Account
    #[inline(always)]
    fn store_nonce(self: @Account, nonce: u64) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.address().starknet
        };
        contract_account.set_nonce(nonce);
        Result::Ok(())
    }

    /// Returns the value stored at a `u256` key inside the Contract Account storage.
    /// The new value is written in Kakarot Core's contract storage.
    /// The storage address used is h(sn_keccak("contract_account_storage_keys"), evm_address, key), where `h` is the poseidon hash function.
    #[inline(always)]
    fn fetch_storage(self: @Account, key: u256) -> Result<u256, EVMError> {
        let contract_account = IContractAccountDispatcher {
            contract_address: self.address().starknet
        };
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
    fn store_storage(self: @Account, key: u256, value: u256) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.address().starknet
        };
        contract_account.set_storage_at(key, value);
        Result::Ok(())
    }

    /// Stores the EVM bytecode of a contract account in Kakarot Core's contract storage.  The bytecode is first packed
    /// into a ByteArray and then stored in the contract storage.
    /// # Arguments
    /// * `evm_address` - The EVM address of the contract account
    /// * `bytecode` - The bytecode to store
    fn store_bytecode(self: @Account, bytecode: Span<u8>) -> Result<(), EVMError> {
        let mut contract_account = IContractAccountDispatcher {
            contract_address: self.address().starknet
        };
        contract_account.set_bytecode(bytecode);
        Result::Ok(())
    }


    /// Returns true if the given `offset` is a valid jump destination in the bytecode.
    /// The valid jump destinations are stored in Kakarot Core's contract storage first.
    /// # Arguments
    /// * `offset` - The offset to check
    /// # Returns
    /// * `true` - If the offset is a valid jump destination
    /// * `false` - Otherwise
    #[inline(always)]
    fn is_false_positive_jumpdest(self: @Account, offset: usize) -> Result<bool, EVMError> {
        let contract_account = IContractAccountDispatcher {
            contract_address: self.address().starknet
        };
        let is_false_positive_jumpdest = contract_account.is_false_positive_jumpdest(offset);
        Result::Ok(is_false_positive_jumpdest)
    }


    ///  This function is used to find all the false positive JUMPDESTs in a given bytecode.
    ///  It iterates over the bytecode, opcode by opcode.
    ///  If the opcode is not a PUSH operation, it simply moves to the next opcode.
    ///  If the opcode is a PUSH operation, it checks the bytes being pushed for equality with the JUMPDEST opcode (0x5b).
    ///  If value `0x5b` is found within the bytes being pushed, it is considered a false positive.
    ///  The offset of this false positive JUMPDEST is then added to the `offsets` array.
    ///  The function returns the index of the next opcode to be checked.
    fn find_false_positive_jumpdests(bytecode: Span<u8>) -> Span<usize> {
        let mut offsets = array![];
        let mut current_bytecode_index = 0;
        loop {
            if current_bytecode_index >= bytecode.len() {
                break;
            }
            let opcode = *bytecode[current_bytecode_index];
            if opcode < 0x60 || opcode > 0x7f {
                current_bytecode_index += 1;
            } else {
                let remaining_length = bytecode.len() - current_bytecode_index;
                let pushed_bytes = bytecode
                    .slice(
                        current_bytecode_index + 1,
                        // We need this min because of some optimisations that the compiler does
                        // that sometimes leaves a PUSH_X with X > remaining_length at the end of the bytecode
                        cmp::min(opcode.into() - 0x5f, remaining_length - 1)
                    );

                let mut counter = 0;
                loop {
                    if counter == pushed_bytes.len() {
                        break;
                    }
                    let byte = *pushed_bytes[counter];
                    if byte == 0x5b {
                        offsets.append(current_bytecode_index + 1 + counter);
                    }
                    counter += 1;
                };
                current_bytecode_index += 1 + opcode.into() - 0x5f;
            }
        };
        offsets.span()
    }
}
