use core::starknet::{ContractAddress, EthAddress, ClassHash};

const INVOKE_ETH_CALL_FORBIDDEN: felt252 = 'KKT: Cannot invoke eth_call';


#[starknet::contract]
pub mod KakarotCore {
    use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
    use contracts::components::ownable::{ownable_component};
    use contracts::components::upgradeable::{IUpgradeable, upgradeable_component};
    use contracts::kakarot_core::interface::IKakarotCore;
    use core::num::traits::{Zero, CheckedAdd, CheckedSub, CheckedMul};
    use core::starknet::SyscallResultTrait;
    use core::starknet::event::EventEmitter;
    use core::starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use evm::backend::starknet_backend;
    use evm::errors::{EVMError, ensure, EVMErrorTrait,};
    use evm::gas;
    use evm::interpreter::{EVMTrait};
    use evm::model::account::{Account, AccountTrait};
    use evm::model::{
        Transfer, Message, Environment, TransactionResult, TransactionResultTrait, ExecutionSummary,
        ExecutionSummaryTrait, Address, AddressTrait
    };
    use evm::state::{State, StateTrait};
    use core::starknet::syscalls::deploy_syscall;
    use core::starknet::{
        EthAddress, ContractAddress, ClassHash, get_tx_info, get_contract_address,
        get_caller_address
    };
    use super::{INVOKE_ETH_CALL_FORBIDDEN};
    use utils::address::compute_contract_address;
    use utils::constants;
    use utils::eth_transaction::AccessListItemTrait;
    use utils::eth_transaction::{EthereumTransaction, EthereumTransactionTrait, AccessListItem};
    use utils::helpers::{compute_starknet_address, EthAddressExTrait};
    use utils::rlp::RLPTrait;
    use utils::set::{Set, SetTrait};

    component!(path: ownable_component, storage: ownable, event: OwnableEvent);
    component!(path: upgradeable_component, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::Ownable<ContractState>;

    impl OwnableInternalImpl = ownable_component::InternalImpl<ContractState>;

    impl UpgradeableImpl = upgradeable_component::Upgradeable<ContractState>;


    #[storage]
    pub struct Storage {
        Kakarot_evm_to_starknet_address: Map::<EthAddress, ContractAddress>,
        Kakarot_uninitialized_account_class_hash: ClassHash,
        Kakarot_account_contract_class_hash: ClassHash,
        Kakarot_native_token_address: ContractAddress,
        Kakarot_coinbase: EthAddress,
        Kakarot_base_fee: u128,
        Kakarot_prev_randao: u256,
        Kakarot_block_gas_limit: u128,
        // Components
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnableEvent: ownable_component::Event,
        UpgradeableEvent: upgradeable_component::Event,
        AccountDeployed: AccountDeployed,
        AccountClassHashChange: AccountClassHashChange,
        EOAClassHashChange: EOAClassHashChange,
    }

    #[derive(Drop, starknet::Event)]
    struct AccountDeployed {
        #[key]
        evm_address: EthAddress,
        #[key]
        starknet_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AccountClassHashChange {
        old_class_hash: ClassHash,
        new_class_hash: ClassHash,
    }


    #[derive(Drop, starknet::Event)]
    struct EOAClassHashChange {
        old_class_hash: ClassHash,
        new_class_hash: ClassHash,
    }


    // TODO: add ability to pass Span<EthAddress>, which should be deployed along with Kakarot
    // this can be done once https://github.com/starkware-libs/cairo/issues/4488 is resolved
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        native_token: ContractAddress,
        account_contract_class_hash: ClassHash,
        uninitialized_account_class_hash: ClassHash,
        coinbase: EthAddress,
        block_gas_limit: u128,
        mut eoas_to_deploy: Span<EthAddress>,
    ) {
        self.ownable.initializer(owner);
        self.Kakarot_native_token_address.write(native_token);
        self.Kakarot_account_contract_class_hash.write(account_contract_class_hash);
        self.Kakarot_uninitialized_account_class_hash.write(uninitialized_account_class_hash);
        self.Kakarot_coinbase.write(coinbase);
        self.Kakarot_block_gas_limit.write(block_gas_limit);
        for eoa_address in eoas_to_deploy {
            self.deploy_externally_owned_account(*eoa_address);
        };
    }

    #[abi(embed_v0)]
    impl KakarotCoreImpl of IKakarotCore<ContractState> {
        fn set_native_token(ref self: ContractState, native_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.Kakarot_native_token_address.write(native_token);
        }

        fn get_native_token(self: @ContractState) -> ContractAddress {
            self.Kakarot_native_token_address.read()
        }

        fn compute_starknet_address(
            self: @ContractState, evm_address: EthAddress
        ) -> ContractAddress {
            let kakarot_address = get_contract_address();
            compute_starknet_address(
                kakarot_address, evm_address, self.Kakarot_uninitialized_account_class_hash.read()
            )
        }

        fn address_registry(self: @ContractState, evm_address: EthAddress) -> ContractAddress {
            self.Kakarot_evm_to_starknet_address.read(evm_address)
        }

        fn deploy_externally_owned_account(
            ref self: ContractState, evm_address: EthAddress
        ) -> ContractAddress {
            starknet_backend::deploy(evm_address).expect('EOA Deployment failed').starknet
        }

        fn eth_call(
            self: @ContractState, origin: EthAddress, tx: EthereumTransaction
        ) -> (bool, Span<u8>, u128) {
            if !self.is_view() {
                core::panic_with_felt252('fn must be called, not invoked');
            };

            let origin = Address { evm: origin, starknet: self.compute_starknet_address(origin) };

            let TransactionResult { success, return_data, gas_used, state: _ } = self
                .process_transaction(origin, tx);

            (success, return_data, gas_used)
        }

        fn eth_send_transaction(
            ref self: ContractState, tx: EthereumTransaction
        ) -> (bool, Span<u8>, u128) {
            let starknet_caller_address = get_caller_address();
            let account = IAccountDispatcher { contract_address: starknet_caller_address };
            let origin = Address {
                evm: account.get_evm_address(), starknet: starknet_caller_address
            };

            let TransactionResult { success, return_data, gas_used, mut state } = self
                .process_transaction(origin, tx);
            starknet_backend::commit(ref state).expect('Committing state failed');
            (success, return_data, gas_used)
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade_contract(new_class_hash);
        }

        fn get_account_contract_class_hash(self: @ContractState) -> ClassHash {
            self.Kakarot_account_contract_class_hash.read()
        }

        fn set_account_contract_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.Kakarot_account_contract_class_hash.read();
            self.Kakarot_account_contract_class_hash.write(new_class_hash);
            self.emit(EOAClassHashChange { old_class_hash, new_class_hash });
        }

        fn uninitialized_account_class_hash(self: @ContractState) -> ClassHash {
            self.Kakarot_uninitialized_account_class_hash.read()
        }

        fn set_account_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.Kakarot_uninitialized_account_class_hash.read();
            self.Kakarot_uninitialized_account_class_hash.write(new_class_hash);
            self.emit(AccountClassHashChange { old_class_hash, new_class_hash });
        }

        fn register_account(ref self: ContractState, evm_address: EthAddress) {
            let existing_address = self.Kakarot_evm_to_starknet_address.read(evm_address);
            assert(existing_address.is_zero(), 'Account already exists');

            let starknet_address = self.compute_starknet_address(evm_address);
            //TODO: enable this assertion. Will require changing test runner to snfoundry
            // assert!(starknet_address == caller, "Account must be registered by the caller");

            self.Kakarot_evm_to_starknet_address.write(evm_address, starknet_address);
            self.emit(AccountDeployed { evm_address, starknet_address });
        }

        fn get_block_gas_limit(self: @ContractState) -> u128 {
            self.Kakarot_block_gas_limit.read()
        }


        fn get_base_fee(self: @ContractState) -> u128 {
            self.Kakarot_base_fee.read()
        }
    }

    #[generate_trait]
    impl KakarotCoreInternalImpl of KakarotCoreInternal {
        fn is_view(self: @ContractState) -> bool {
            let tx_info = get_tx_info().unbox();

            // If the account that originated the transaction is not zero, this means we
            // are in an invoke transaction instead of a call; therefore, `eth_call` is being
            // wrongly called For invoke transactions, `eth_send_transaction` must be used
            if !tx_info.account_contract_address.is_zero() {
                return false;
            }
            true
        }

        /// Maps an EVM address to a Starknet address
        /// Triggered when deployment of an EOA or CA is successful
        fn set_address_registry(
            ref self: ContractState, evm_address: EthAddress, starknet_address: ContractAddress
        ) {
            self.Kakarot_evm_to_starknet_address.write(evm_address, starknet_address);
        }


        fn process_transaction(
            self: @ContractState, origin: Address, tx: EthereumTransaction
        ) -> TransactionResult {
            //TODO(gas) handle FeeMarketTransaction
            let gas_price = tx.gas_price();
            let gas_limit = tx.gas_limit();
            let mut env = starknet_backend::get_env(origin.evm, gas_price);

            // TX Gas
            let gas_fee = gas_limit * gas_price;
            let mut sender_account = env.state.get_account(origin.evm);
            let sender_balance = sender_account.balance();
            match ensure(
                sender_balance >= gas_fee.into() + tx.value(), EVMError::InsufficientBalance
            ) {
                Result::Ok(_) => {},
                Result::Err(err) => {
                    return TransactionResultTrait::exceptional_failure(
                        err.to_bytes(), tx.gas_limit()
                    );
                }
            };

            let gas_left = match gas_limit.checked_sub(gas::calculate_intrinsic_gas_cost(@tx)) {
                Option::Some(gas_left) => gas_left,
                Option::None => {
                    return TransactionResultTrait::exceptional_failure(
                        EVMError::OutOfGas.to_bytes(), tx.gas_limit()
                    );
                }
            };

            // Handle deploy/non-deploy transaction cases
            let (to, is_deploy_tx, code, calldata) = match tx.destination() {
                Option::Some(to) => {
                    let target_starknet_address = self.compute_starknet_address(to);
                    let to = Address { evm: to, starknet: target_starknet_address };
                    let code = env.state.get_account(to.evm).code;
                    (to, false, code, tx.calldata())
                },
                Option::None => {
                    // Deploy tx case.
                    let mut origin_nonce: u64 = get_tx_info().unbox().nonce.try_into().unwrap();
                    let to_evm_address = compute_contract_address(origin.evm, origin_nonce);
                    let to_starknet_address = self.compute_starknet_address(to_evm_address);
                    let to = Address { evm: to_evm_address, starknet: to_starknet_address };
                    let code = tx.calldata();
                    let calldata = [].span();
                    (to, true, code, calldata)
                },
            };

            let mut accessed_addresses: Set<EthAddress> = Default::default();
            accessed_addresses.add(env.coinbase);
            accessed_addresses.add(to.evm);
            accessed_addresses.add(origin.evm);
            accessed_addresses.extend(constants::precompile_addresses().spanset());

            let mut accessed_storage_keys: Set<(EthAddress, u256)> = Default::default();

            if let Option::Some(mut access_list) = tx.try_access_list() {
                for access_list_item in access_list {
                    let AccessListItem { ethereum_address, storage_keys: _ } = *access_list_item;
                    let storage_keys = access_list_item.to_storage_keys();
                    accessed_addresses.add(ethereum_address);
                    accessed_storage_keys.extend_from_span(storage_keys);
                }
            };

            let message = Message {
                caller: origin,
                target: to,
                gas_limit: gas_left,
                data: calldata,
                code,
                value: tx.value(),
                should_transfer_value: true,
                depth: 0,
                read_only: false,
                accessed_addresses: accessed_addresses.spanset(),
                accessed_storage_keys: accessed_storage_keys.spanset(),
            };

            let mut summary = EVMTrait::process_message_call(message, env, is_deploy_tx);

            // Gas refunds
            let gas_used = tx.gas_limit() - summary.gas_left;
            let gas_refund = core::cmp::min(gas_used / 5, summary.gas_refund);

            // Charging gas fees to the sender
            // At the end of the tx, the sender must have paid
            // (gas_used - gas_refund) * gas_price to the miner
            // Because tx.gas_price == env.gas_price, and we checked the sender has enough balance
            // to cover the gas fees + the value transfer, this transfer should never fail.
            // We can thus directly charge the sender for the effective gas fees,
            // without pre-emtively charging for the tx gas fee and then refund.
            // This is not true for EIP-1559 transactions - not supported yet.
            let total_gas_used = gas_used - gas_refund;
            let _transaction_fee = total_gas_used * gas_price;

            //TODO(gas): EF-tests doesn't yet support in-EVM gas charging, they assume that the gas
            //charged is always correct for now.
            // As correct gas accounting is not an immediate priority, we can just ignore the gas
            // charging for now.
            // match summary
            //     .state
            //     .add_transfer(
            //         Transfer {
            //             sender: origin,
            //             recipient: Address {
            //                 evm: coinbase, starknet: block_info.sequencer_address,
            //             },
            //             amount: transaction_fee.into()
            //         }
            //     ) {
            //     Result::Ok(_) => {},
            //     Result::Err(err) => {
            //
            //         return TransactionResultTrait::exceptional_failure(
            //             err.to_bytes(), tx.gas_limit()
            //         );
            //     }
            // };

            TransactionResult {
                success: summary.success,
                return_data: summary.return_data,
                gas_used: total_gas_used,
                state: summary.state,
            }
        }
    }
}
