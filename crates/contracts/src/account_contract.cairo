//! The generic account that is deployed by Kakarot Core before being "specialized" into an
//! Externally Owned Account or a Contract Account This aims at having only one class hash for all
//! the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth
//! Address <=> Starknet Address

use core::starknet::account::{Call};
use core::starknet::{EthAddress, ClassHash, ContractAddress};

#[derive(Copy, Drop, Serde, Debug)]
pub struct OutsideExecution {
    pub caller: ContractAddress,
    pub nonce: u64,
    pub execute_after: u64,
    pub execute_before: u64,
    pub calls: Span<Call>
}

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn initialize(
        ref self: TContractState, evm_address: EthAddress, implementation_class: ClassHash
    );
    fn get_implementation(self: @TContractState) -> ClassHash;
    fn get_evm_address(self: @TContractState) -> EthAddress;
    fn get_code_hash(self: @TContractState) -> u256;
    fn set_code_hash(ref self: TContractState, code_hash: u256);
    fn is_initialized(self: @TContractState) -> bool;

    // EOA functions
    fn __validate__(ref self: TContractState, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @TContractState, class_hash: felt252) -> felt252;
    fn __execute__(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;

    // CA functions
    fn write_bytecode(ref self: TContractState, bytecode: Span<u8>);
    fn bytecode(self: @TContractState) -> Span<u8>;
    fn write_storage(ref self: TContractState, key: u256, value: u256);
    fn storage(self: @TContractState, key: u256) -> u256;
    fn get_nonce(self: @TContractState) -> u64;
    fn set_nonce(ref self: TContractState, nonce: u64);
    fn execute_starknet_call(ref self: TContractState, call: Call) -> (bool, Span<felt252>);
    fn execute_from_outside(
        ref self: TContractState, outside_execution: OutsideExecution, signature: Span<felt252>,
    ) -> Array<Span<felt252>>;
}

#[starknet::contract(account)]
pub mod AccountContract {
    use contracts::components::ownable::IOwnable;
    use contracts::components::ownable::ownable_component::InternalTrait;
    use contracts::components::ownable::ownable_component;
    use contracts::errors::{KAKAROT_VALIDATION_FAILED, KAKAROT_REENTRANCY};
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use contracts::storage::StorageBytecode;
    use core::num::traits::Bounded;
    use core::num::traits::zero::Zero;
    use core::panic_with_felt252;
    use core::starknet::SyscallResultTrait;
    use core::starknet::account::{Call};
    use core::starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use core::starknet::syscalls::{call_contract_syscall, replace_class_syscall};
    use core::starknet::{
        EthAddress, ClassHash, VALIDATED, get_caller_address, get_tx_info, get_block_timestamp
    };
    use core::traits::TryInto;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use super::{IAccountLibraryDispatcher, IAccountDispatcherTrait, OutsideExecution};
    use utils::constants::{POW_2_32};
    use utils::eth_transaction::transaction::{TransactionUnsignedTrait, Transaction};
    use utils::eth_transaction::validation::validate_eth_tx;
    use utils::eth_transaction::{TransactionMetadata};
    use utils::serialization::{deserialize_signature, deserialize_bytes, serialize_bytes};
    use utils::traits::DefaultSignature;

    // Add ownable component
    component!(path: ownable_component, storage: ownable, event: OwnableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::Ownable<ContractState>;
    impl OwnableInternal = ownable_component::InternalImpl<ContractState>;


    const VERSION: u32 = 000_001_000;


    #[storage]
    pub(crate) struct Storage {
        pub(crate) Account_bytecode: StorageBytecode,
        pub(crate) Account_bytecode_len: u32,
        pub(crate) Account_storage: Map<u256, u256>,
        pub(crate) Account_is_initialized: bool,
        pub(crate) Account_nonce: u64,
        pub(crate) Account_implementation: ClassHash,
        pub(crate) Account_evm_address: EthAddress,
        pub(crate) Account_code_hash: u256,
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        transaction_executed: TransactionExecuted,
        OwnableEvent: ownable_component::Event
    }

    #[derive(Drop, starknet::Event, Debug)]
    pub struct TransactionExecuted {
        pub response: Span<felt252>,
        pub success: bool,
        pub gas_used: u64
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        panic!("Accounts cannot be created directly");
    }

    #[abi(embed_v0)]
    impl Account of super::IAccount<ContractState> {
        fn initialize(
            ref self: ContractState, evm_address: EthAddress, implementation_class: ClassHash
        ) {
            assert(!self.Account_is_initialized.read(), 'Account already initialized');
            self.Account_is_initialized.write(true);

            self.Account_evm_address.write(evm_address);
            self.Account_implementation.write(implementation_class);

            let kakarot_address = self.ownable.owner();
            let kakarot = IKakarotCoreDispatcher { contract_address: kakarot_address };
            let native_token = kakarot.get_native_token();
            // To internally perform value transfer of the network's native
            // token (which conforms to the ERC20 standard), we need to give the
            // KakarotCore contract infinite allowance
            IERC20CamelDispatcher { contract_address: native_token }
                .approve(kakarot_address, Bounded::<u256>::MAX);

            kakarot.register_account(evm_address);
        }

        fn get_implementation(self: @ContractState) -> ClassHash {
            self.Account_implementation.read()
        }

        fn get_evm_address(self: @ContractState) -> EthAddress {
            self.Account_evm_address.read()
        }

        fn get_code_hash(self: @ContractState) -> u256 {
            self.Account_code_hash.read()
        }

        fn set_code_hash(ref self: ContractState, code_hash: u256) {
            self.Account_code_hash.write(code_hash);
        }

        fn is_initialized(self: @ContractState) -> bool {
            self.Account_is_initialized.read()
        }

        // EOA functions
        fn __validate__(ref self: ContractState, calls: Array<Call>) -> felt252 {
            let tx_info = get_tx_info().unbox();
            assert(get_caller_address().is_zero(), 'EOA: reentrant call');
            assert(calls.len() == 1, 'EOA: multicall not supported');
            // todo: activate check once using snfoundry
            // assert(tx_info.version.try_into().unwrap() >= 1_u128, 'EOA: deprecated tx version');
            assert(self.Account_bytecode_len.read().is_zero(), 'EOAs: Cannot have code');
            assert(tx_info.signature.len() == 5, 'EOA: invalid signature length');

            let call = calls.at(0);
            assert(*call.to == self.ownable.owner(), 'to is not kakarot core');
            assert!(
                *call.selector == selector!("eth_send_transaction"),
                "Validate: selector must be eth_send_transaction"
            );

            let chain_id: u64 = tx_info.chain_id.try_into().unwrap() % POW_2_32.try_into().unwrap();
            let signature = deserialize_signature(tx_info.signature, chain_id)
                .expect('EOA: invalid signature');

            let tx_metadata = TransactionMetadata {
                address: self.Account_evm_address.read(),
                chain_id,
                account_nonce: tx_info.nonce.try_into().unwrap(),
                signature
            };

            let mut encoded_tx = deserialize_bytes(*call.calldata)
                .expect('conversion to Span<u8> failed')
                .span();
            let unsigned_transaction = TransactionUnsignedTrait::decode_enveloped(ref encoded_tx)
                .expect('EOA: could not decode tx');
            let validation_result = validate_eth_tx(tx_metadata, unsigned_transaction)
                .expect('failed to validate eth tx');

            assert(validation_result, 'transaction validation failed');

            VALIDATED
        }

        /// Validate Declare is not used for Kakarot
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            panic_with_felt252('Cannot Declare EOA')
        }

        fn __execute__(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            let caller = get_caller_address();
            let tx_info = get_tx_info().unbox();
            assert(caller.is_zero(), 'EOA: reentrant call');
            assert(calls.len() == 1, 'EOA: multicall not supported');
            // todo: activate check once using snfoundry
            // assert(tx_info.version.try_into().unwrap() >= 1_u128, 'EOA: deprecated tx version');

            let kakarot = IKakarotCoreDispatcher { contract_address: self.ownable.owner() };
            let latest_class = kakarot.get_account_contract_class_hash();
            let this_class = self.Account_implementation.read();

            if (latest_class != this_class) {
                self.Account_implementation.write(latest_class);
                let response = IAccountLibraryDispatcher { class_hash: latest_class }
                    .__execute__(calls);
                replace_class_syscall(latest_class).unwrap_syscall();
                return response;
            }

            // Increment nonce to match protocol's nonce for EOAs.
            self.Account_nonce.write(tx_info.nonce.try_into().unwrap() + 1);

            let call: @Call = calls[0];
            let _encoded_tx_data = deserialize_bytes(*call.calldata)
                .expect('conversion failed')
                .span();

            let _chain_id: u64 = tx_info
                .chain_id
                .try_into()
                .unwrap() % POW_2_32
                .try_into()
                .unwrap();

            //TODO: add a type for unsigned transaction
            let mut encoded_tx = deserialize_bytes(*call.calldata)
                .expect('conversion to Span<u8> failed')
                .span();
            let unsigned_transaction = TransactionUnsignedTrait::decode_enveloped(ref encoded_tx)
                .expect('EOA: could not decode tx');

            //TODO: validation of EIP-1559 transactions
            // Not done because this endpoint will end up deprecated after EIP-1559
            let is_valid = true;

            let (success, return_data, gas_used) = if is_valid {
                kakarot.eth_send_transaction(unsigned_transaction.transaction)
            } else {
                (false, KAKAROT_VALIDATION_FAILED.span(), 0)
            };
            let return_data = serialize_bytes(return_data).span();

            self.emit(TransactionExecuted { response: return_data, success: success, gas_used });

            array![return_data]
        }

        fn write_bytecode(ref self: ContractState, bytecode: Span<u8>) {
            self.ownable.assert_only_owner();
            self.Account_bytecode.write(StorageBytecode { bytecode });
        }

        fn bytecode(self: @ContractState) -> Span<u8> {
            self.Account_bytecode.read().bytecode
        }

        fn write_storage(ref self: ContractState, key: u256, value: u256) {
            self.ownable.assert_only_owner();
            self.Account_storage.write(key, value);
        }

        fn storage(self: @ContractState, key: u256) -> u256 {
            self.Account_storage.read(key)
        }

        fn get_nonce(self: @ContractState) -> u64 {
            self.Account_nonce.read()
        }

        fn set_nonce(ref self: ContractState, nonce: u64) {
            self.ownable.assert_only_owner();
            self.Account_nonce.write(nonce);
        }

        /// Used to preserve caller in Cairo Precompiles
        /// Reentrency check is done for Kakarot contract, only get_starknet_address is allowed
        /// for Solidity contracts to be able to get the corresponding Starknet address in their
        /// calldata.
        fn execute_starknet_call(ref self: ContractState, call: Call) -> (bool, Span<felt252>) {
            self.ownable.assert_only_owner();
            let kakarot_address = self.ownable.owner();
            if call.to == kakarot_address && call.selector != selector!("get_starknet_address") {
                return (false, KAKAROT_REENTRANCY.span());
            }
            let response = call_contract_syscall(call.to, call.selector, call.calldata);
            if response.is_ok() {
                return (true, response.unwrap().into());
            }
            return (false, response.unwrap_err().into());
        }

        fn execute_from_outside(
            ref self: ContractState, outside_execution: OutsideExecution, signature: Span<felt252>,
        ) -> Array<Span<felt252>> {
            let caller = get_caller_address();
            let tx_info = get_tx_info();

            if (outside_execution.caller.into() != 'ANY_CALLER') {
                assert(caller == outside_execution.caller, 'SNIP9: Invalid caller');
            }

            let block_timestamp = get_block_timestamp();
            assert(block_timestamp > outside_execution.execute_after, 'SNIP9: Too early call');
            assert(block_timestamp < outside_execution.execute_before, 'SNIP9: Too late call');

            assert(outside_execution.calls.len() == 1, 'Multicall not supported');
            assert(self.Account_bytecode_len.read().is_zero(), 'EOAs cannot have code');
            assert(tx_info.version.into() >= 1_u256, 'Deprecated tx version');
            assert(signature.len() == 5, 'Invalid signature length');

            let call = outside_execution.calls.at(0);
            assert(*call.to == self.ownable.owner(), 'to is not kakarot core');
            assert!(
                *call.selector == selector!("eth_send_transaction"),
                "selector must be eth_send_transaction"
            );
            let chain_id: u64 = tx_info.chain_id.try_into().unwrap() % POW_2_32.try_into().unwrap();
            let signature = deserialize_signature(signature, chain_id)
                .expect('EOA: invalid signature');
            let mut encoded_tx_data = deserialize_bytes((*outside_execution.calls[0]).calldata)
                .expect('conversion to Span<u8> failed')
                .span();
            let unsigned_transaction = TransactionUnsignedTrait::decode_enveloped(
                ref encoded_tx_data
            )
                .expect('EOA: could not decode tx');
            // TODO(execute-from-outside): move validation to KakarotCore
            let tx_metadata = TransactionMetadata {
                address: self.Account_evm_address.read(),
                chain_id,
                account_nonce: self.Account_nonce.read().into(),
                signature
            };

            let validation_result = validate_eth_tx(tx_metadata, unsigned_transaction)
                .expect('failed to validate eth tx');

            assert(validation_result, 'transaction validation failed');

            //TODO: validate eip1559 transactions
            // let is_valid = match tx.try_into_fee_market_transaction() {
            //     Option::Some(tx_fee_infos) => { self.validate_eip1559_tx(@tx, tx_fee_infos) },
            //     Option::None => true
            // };
            let is_valid = true;

            let kakarot = IKakarotCoreDispatcher { contract_address: self.ownable.owner() };

            let return_data = if is_valid {
                let (_, return_data, _) = kakarot
                    .eth_send_transaction(unsigned_transaction.transaction);
                return_data
            } else {
                KAKAROT_VALIDATION_FAILED.span()
            };
            let return_data = serialize_bytes(return_data).span();

            array![return_data]
        }
    }

    #[generate_trait]
    impl Eip1559TransactionImpl of Eip1559TransactionTrait {
        //TODO: refactor
        fn validate_eip1559_tx(ref self: ContractState, tx: Transaction,) -> bool {
            // let kakarot = IKakarotCoreDispatcher { contract_address: self.ownable.owner() };
            // let block_gas_limit = kakarot.get_block_gas_limit();

            // if tx.gas_limit() >= block_gas_limit {
            //     return false;
            // }

            // let base_fee = kakarot.get_base_fee();
            // let native_token = kakarot.get_native_token();
            // let balance = IERC20CamelDispatcher { contract_address: native_token }
            //     .balanceOf(get_contract_address());

            // let max_fee_per_gas = tx_fee_infos.max_fee_per_gas;
            // let max_priority_fee_per_gas = tx_fee_infos.max_priority_fee_per_gas;

            // // ensure that the user was willing to at least pay the base fee
            // if base_fee >= max_fee_per_gas {
            //     return false;
            // }

            // // ensure that the max priority fee per gas is not greater than the max fee per gas
            // if max_priority_fee_per_gas >= max_fee_per_gas {
            //     return false;
            // }

            // let max_gas_fee = tx.gas_limit() * max_fee_per_gas;
            // let tx_cost = max_gas_fee.into() + tx_fee_infos.amount;

            // if tx_cost >= balance {
            //     return false;
            // }

            // // priority fee is capped because the base fee is filled first
            // let possible_priority_fee = max_fee_per_gas - base_fee;

            // if max_priority_fee_per_gas >= possible_priority_fee {
            //     return false;
            // }

            return true;
        }
    }
}
