use core::starknet::account::{Call};
//! The generic account that is deployed by Kakarot Core before being "specialized" into an
//! Externally Owned Account or a Contract Account This aims at having only one class hash for all
//! the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth
//! Address <=> Starknet Address

use core::starknet::{ContractAddress, EthAddress, ClassHash};

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn initialize(
        ref self: TContractState,
        kakarot_address: ContractAddress,
        evm_address: EthAddress,
        implementation_class: ClassHash
    );
    fn get_implementation(self: @TContractState) -> ClassHash;
    fn get_evm_address(self: @TContractState) -> EthAddress;
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
}

#[starknet::contract(account)]
pub mod AccountContract {
    use contracts::components::ownable::IOwnable;
    use contracts::components::ownable::ownable_component::InternalTrait;
    use contracts::components::ownable::ownable_component;
    use contracts::errors::{
        BYTECODE_READ_ERROR, BYTECODE_WRITE_ERROR, STORAGE_READ_ERROR, STORAGE_WRITE_ERROR,
        NONCE_READ_ERROR, NONCE_WRITE_ERROR, KAKAROT_VALIDATION_FAILED
    };
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use contracts::storage::StorageBytecode;
    use core::integer;
    use core::num::traits::Bounded;
    use core::num::traits::zero::Zero;
    use core::panic_with_felt252;
    use core::starknet::SyscallResultTrait;
    use core::starknet::account::{Call};
    use core::starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use core::starknet::storage_access::{storage_base_address_from_felt252, StorageBaseAddress};
    use core::starknet::syscalls::{replace_class_syscall};
    use core::starknet::{
        ContractAddress, EthAddress, ClassHash, VALIDATED, get_caller_address, get_contract_address,
        get_tx_info, Store
    };
    use core::traits::TryInto;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use super::{IAccountLibraryDispatcher, IAccountDispatcherTrait};
    use utils::constants::{POW_2_32};
    use utils::eth_transaction::EthereumTransactionTrait;
    use utils::eth_transaction::{EthTransactionTrait, TransactionMetadata};
    use utils::helpers::SpanExtTrait;
    use utils::helpers::{ByteArrayExTrait, ResultExTrait};
    use utils::math::OverflowingMul;
    use utils::serialization::{deserialize_signature, deserialize_bytes, serialize_bytes};

    // Add ownable component
    component!(path: ownable_component, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::Ownable<ContractState>;

    impl OwnableInternal = ownable_component::InternalImpl<ContractState>;


    const VERSION: u32 = 000_001_000;


    #[storage]
    pub(crate) struct Storage {
        Account_bytecode: StorageBytecode,
        pub(crate) Account_bytecode_len: u32,
        Account_storage: Map<u256, u256>,
        Account_is_initialized: bool,
        Account_nonce: u64,
        Account_implementation: ClassHash,
        Account_evm_address: EthAddress,
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        transaction_executed: TransactionExecuted,
        OwnableEvent: ownable_component::Event
    }

    #[derive(Drop, starknet::Event, Debug)]
    struct TransactionExecuted {
        response: Span<felt252>,
        success: bool,
        gas_used: u128
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        panic!("Accounts cannot be created directly");
    }

    #[abi(embed_v0)]
    impl Account of super::IAccount<ContractState> {
        fn initialize(
            ref self: ContractState,
            kakarot_address: ContractAddress,
            evm_address: EthAddress,
            implementation_class: ClassHash
        ) {
            assert(!self.Account_is_initialized.read(), 'Account already initialized');
            self.Account_is_initialized.write(true);
            self.ownable.initializer(kakarot_address);
            self.Account_evm_address.write(evm_address);
            self.Account_implementation.write(implementation_class);

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

            let chain_id: u128 = tx_info.chain_id.try_into().unwrap() % POW_2_32;
            let signature = deserialize_signature(tx_info.signature, chain_id)
                .expect('EOA: invalid signature');

            let tx_metadata = TransactionMetadata {
                address: self.Account_evm_address.read(),
                chain_id,
                account_nonce: tx_info.nonce.try_into().unwrap(),
                signature
            };

            let encoded_tx = deserialize_bytes(*call.calldata)
                .expect('conversion to Span<u8> failed');
            let validation_result = EthTransactionTrait::validate_eth_tx(
                tx_metadata, encoded_tx.span()
            )
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
            let encoded_tx = deserialize_bytes(*call.calldata).expect('conversion failed').span();

            let tx = EthTransactionTrait::decode(encoded_tx).expect('rlp decoding of tx failed');

            let is_valid = match tx.try_into_fee_market_transaction() {
                Option::Some(tx_fee_infos) => { self.validate_eip1559_tx(@tx, tx_fee_infos) },
                Option::None => true
            };

            let (success, return_data, gas_used) = if is_valid {
                kakarot.eth_send_transaction(tx)
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
    }

    #[generate_trait]
    impl Eip1559TransactionImpl of Eip1559TransactionTrait {
        fn validate_eip1559_tx(
            ref self: ContractState,
            tx: @utils::eth_transaction::EthereumTransaction,
            tx_fee_infos: utils::eth_transaction::FeeMarketTransaction
        ) -> bool {
            let kakarot = IKakarotCoreDispatcher { contract_address: self.ownable.owner() };
            let block_gas_limit = kakarot.get_block_gas_limit();

            if tx.gas_limit() >= block_gas_limit {
                return false;
            }

            let base_fee = kakarot.get_base_fee();
            let native_token = kakarot.get_native_token();
            let balance = IERC20CamelDispatcher { contract_address: native_token }
                .balanceOf(get_contract_address());

            let max_fee_per_gas = tx_fee_infos.max_fee_per_gas;
            let max_priority_fee_per_gas = tx_fee_infos.max_priority_fee_per_gas;

            // ensure that the user was willing to at least pay the base fee
            if base_fee >= max_fee_per_gas {
                return false;
            }

            // ensure that the max priority fee per gas is not greater than the max fee per gas
            if max_priority_fee_per_gas >= max_fee_per_gas {
                return false;
            }

            let max_gas_fee = tx.gas_limit() * max_fee_per_gas;
            let tx_cost = max_gas_fee.into() + tx_fee_infos.amount;

            if tx_cost >= balance {
                return false;
            }

            // priority fee is capped because the base fee is filled first
            let possible_priority_fee = max_fee_per_gas - base_fee;

            if max_priority_fee_per_gas >= possible_priority_fee {
                return false;
            }

            return true;
        }
    }
}
