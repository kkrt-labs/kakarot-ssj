use starknet::{ContractAddress, EthAddress, ClassHash};

const INVOKE_ETH_CALL_FORBIDDEN: felt252 = 'KKT: Cannot invoke eth_call';

// Local enum to differentiate EOA and CA in storage
// TODO: remove distinction between EOA and CA as EVM accounts
// As soon as EOA::nonce can be handled at the application level
#[derive(Drop, starknet::Store, Serde, PartialEq, Default)]
enum StoredAccountType {
    #[default]
    UnexistingAccount,
    EOA: ContractAddress,
    ContractAccount: ContractAddress,
}

#[starknet::contract]
mod KakarotCore {
    use contracts::components::ownable::{ownable_component};
    use contracts::components::upgradeable::{IUpgradeable, upgradeable_component};
    use contracts::contract_account::{IContractAccountDispatcher, IContractAccountDispatcherTrait};
    use contracts::eoa::{IExternallyOwnedAccountDispatcher, IExternallyOwnedAccountDispatcherTrait};
    use contracts::kakarot_core::interface::IKakarotCore;
    use core::array::SpanTrait;
    use core::starknet::SyscallResultTrait;

    use evm::errors::{EVMError, ensure, EVMErrorTrait,};
    use evm::gas;
    use evm::interpreter::{EVMTrait};
    use evm::model::account::{Account, AccountType, AccountTrait};
    use evm::model::contract_account::{ContractAccountTrait};
    use evm::model::eoa::{EOATrait};
    use evm::model::{ExecutionSummary, ExecutionSummaryTrait, Address, AddressTrait};
    use evm::model::{Message, Environment};
    use evm::state::{State, StateTrait};
    use starknet::{
        EthAddress, ContractAddress, ClassHash, get_tx_info, get_contract_address, deploy_syscall,
        get_caller_address
    };
    use super::{INVOKE_ETH_CALL_FORBIDDEN};
    use super::{StoredAccountType};
    use utils::address::compute_contract_address;
    use utils::checked_math::CheckedMath;
    use utils::constants;
    use utils::eth_transaction::AccessListItemTrait;
    use utils::eth_transaction::{EthereumTransaction, EthereumTransactionTrait, AccessListItem};
    use utils::fmt::EthAddressDebug;
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
    struct Storage {
        /// Kakarot storage for accounts: Externally Owned Accounts (EOA) and Contract Accounts (CA)
        /// Map their EVM address and their Starknet address
        /// - starknet_address: the deterministic starknet address (31 bytes) computed given an EVM address (20 bytes)
        address_registry: LegacyMap::<EthAddress, StoredAccountType>,
        account_class_hash: ClassHash,
        eoa_class_hash: ClassHash,
        ca_class_hash: ClassHash,
        // Utility storage
        native_token: ContractAddress,
        deploy_fee: u128,
        chain_id: u128,
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
        EOADeployed: EOADeployed,
        ContractAccountDeployed: ContractAccountDeployed,
        AccountClassHashChange: AccountClassHashChange,
        EOAClassHashChange: EOAClassHashChange,
        CAClassHashChange: CAClassHashChange,
    }

    #[derive(Drop, starknet::Event)]
    struct EOADeployed {
        #[key]
        evm_address: EthAddress,
        #[key]
        starknet_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractAccountDeployed {
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

    #[derive(Drop, starknet::Event)]
    struct CAClassHashChange {
        old_class_hash: ClassHash,
        new_class_hash: ClassHash,
    }

    // TODO: add ability to pass Span<EthAddress>, which should be deployed along with Kakarot
    // this can be done once https://github.com/starkware-libs/cairo/issues/4488 is resolved
    #[constructor]
    fn constructor(
        ref self: ContractState,
        native_token: ContractAddress,
        deploy_fee: u128,
        account_class_hash: ClassHash,
        eoa_class_hash: ClassHash,
        ca_class_hash: ClassHash,
        owner: ContractAddress,
        chain_id: u128,
    ) {
        self.native_token.write(native_token);
        self.deploy_fee.write(deploy_fee);
        self.account_class_hash.write(account_class_hash);
        self.eoa_class_hash.write(eoa_class_hash);
        self.ca_class_hash.write(ca_class_hash);
        self.ownable.initializer(owner);
        self.chain_id.write(chain_id);
    }

    #[abi(embed_v0)]
    impl KakarotCoreImpl of IKakarotCore<ContractState> {
        fn set_native_token(ref self: ContractState, native_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.native_token.write(native_token);
        }

        fn native_token(self: @ContractState) -> ContractAddress {
            self.native_token.read()
        }

        fn set_deploy_fee(ref self: ContractState, deploy_fee: u128) {
            self.ownable.assert_only_owner();
            self.deploy_fee.write(deploy_fee);
        }

        fn deploy_fee(self: @ContractState) -> u128 {
            self.deploy_fee.read()
        }

        fn chain_id(self: @ContractState) -> u128 {
            self.chain_id.read()
        }

        fn compute_starknet_address(
            self: @ContractState, evm_address: EthAddress
        ) -> ContractAddress {
            // Deployer is always Kakarot Core
            let deployer = get_contract_address();
            compute_starknet_address(deployer, evm_address, self.account_class_hash.read())
        }

        fn address_registry(
            self: @ContractState, evm_address: EthAddress
        ) -> Option<(AccountType, ContractAddress)> {
            match self.address_registry.read(evm_address) {
                StoredAccountType::UnexistingAccount => Option::None,
                StoredAccountType::EOA(starknet_address) => Option::Some(
                    (AccountType::EOA, starknet_address)
                ),
                StoredAccountType::ContractAccount(starknet_address) => Option::Some(
                    (AccountType::ContractAccount, starknet_address)
                ),
            }
        }

        fn contract_account_nonce(self: @ContractState, evm_address: EthAddress) -> u64 {
            let ca_address = ContractAccountTrait::at(evm_address).expect('Fetching CA failed');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.nonce()
        }

        fn account_balance(self: @ContractState, evm_address: EthAddress) -> u256 {
            let address = Address {
                evm: evm_address, starknet: self.compute_starknet_address(evm_address)
            };
            address.fetch_balance()
        }

        fn contract_account_storage_at(
            self: @ContractState, evm_address: EthAddress, key: u256
        ) -> u256 {
            let ca_address = ContractAccountTrait::at(evm_address).expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.storage_at(key)
        }

        fn contract_account_bytecode(self: @ContractState, evm_address: EthAddress) -> Span<u8> {
            let ca_address = ContractAccountTrait::at(evm_address).expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.bytecode()
        }

        fn contract_account_false_positive_jumpdest(
            self: @ContractState, evm_address: EthAddress, offset: usize
        ) -> bool {
            let ca_address = ContractAccountTrait::at(evm_address).expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.is_false_positive_jumpdest(offset)
        }

        fn deploy_eoa(ref self: ContractState, evm_address: EthAddress) -> ContractAddress {
            EOATrait::deploy(evm_address).expect('EOA Deployment failed').starknet
        }

        fn eth_call(
            self: @ContractState, origin: EthAddress, tx: EthereumTransaction
        ) -> (bool, Span<u8>) {
            if !self.is_view() {
                panic_with_felt252('fn must be called, not invoked');
            };

            let origin = Address { evm: origin, starknet: self.compute_starknet_address(origin) };

            let ExecutionSummary{success, return_data, gas_left: _, state: _, } = self
                .process_transaction(origin, tx);

            (success, return_data)
        }

        fn eth_send_transaction(
            ref self: ContractState, tx: EthereumTransaction
        ) -> (bool, Span<u8>) {
            let starknet_caller_address = get_caller_address();
            let account = IExternallyOwnedAccountDispatcher {
                contract_address: starknet_caller_address
            };
            let origin = Address { evm: account.evm_address(), starknet: starknet_caller_address };

            // Invariant:
            // We want to make sure the caller is part of the Kakarot address_registry
            // and is an EOA. Contracts are added to the registry ONLY if there are
            // part of the Kakarot system and thus deployed by the main Kakarot contract
            // itself.

            let (caller_account_type, _) = self
                .address_registry(origin.evm)
                .expect('Fetching EOA failed');
            assert(caller_account_type == AccountType::EOA, 'Caller is not an EOA');

            let ExecutionSummary{success, return_data, gas_left: _, mut state } = self
                .process_transaction(origin, tx);
            state.commit_state().expect('Committing state failed');
            (success, return_data)
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade_contract(new_class_hash);
        }

        fn eoa_class_hash(self: @ContractState) -> ClassHash {
            self.eoa_class_hash.read()
        }

        fn set_eoa_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.eoa_class_hash.read();
            self.eoa_class_hash.write(new_class_hash);
            self.emit(EOAClassHashChange { old_class_hash, new_class_hash });
        }

        fn ca_class_hash(self: @ContractState) -> ClassHash {
            self.ca_class_hash.read()
        }

        fn set_ca_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.ca_class_hash.read();
            self.ca_class_hash.write(new_class_hash);
            self.emit(CAClassHashChange { old_class_hash, new_class_hash });
        }

        fn account_class_hash(self: @ContractState) -> ClassHash {
            self.account_class_hash.read()
        }

        fn set_account_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.account_class_hash.read();
            self.account_class_hash.write(new_class_hash);
            self.emit(AccountClassHashChange { old_class_hash, new_class_hash });
        }
    }

    #[generate_trait]
    impl KakarotCoreInternalImpl of KakarotCoreInternal {
        fn is_view(self: @ContractState) -> bool {
            let tx_info = get_tx_info().unbox();

            // If the account that originated the transaction is not zero, this means we
            // are in an invoke transaction instead of a call; therefore, `eth_call` is being wrongly called
            // For invoke transactions, `eth_send_transaction` must be used
            if !tx_info.account_contract_address.is_zero() {
                return false;
            }
            true
        }

        /// Maps an EVM address to a Starknet address
        /// Triggered when deployment of an EOA or CA is successful
        fn set_address_registry(
            ref self: ContractState, evm_address: EthAddress, account: StoredAccountType
        ) {
            self.address_registry.write(evm_address, account);
        }


        fn process_transaction(
            self: @ContractState, origin: Address, tx: EthereumTransaction
        ) -> ExecutionSummary {
            let block_info = starknet::get_block_info().unbox();
            let coinbase = IExternallyOwnedAccountDispatcher {
                contract_address: block_info.sequencer_address
            }
                .evm_address();

            let gas_price = tx.gas_price();
            let gas_limit = tx.gas_limit();

            let mut env = Environment {
                origin: origin.evm,
                gas_price,
                chain_id: get_tx_info().unbox().chain_id.try_into().unwrap(),
                prevrandao: 0,
                block_number: block_info.block_number,
                block_timestamp: block_info.block_timestamp,
                block_gas_limit: constants::BLOCK_GAS_LIMIT,
                coinbase,
                state: Default::default(),
            };

            //TODO(gas) handle FeeMarketTransaction

            // TX Gas
            let gas_fee = gas_limit * gas_price;
            let mut sender_account = env.state.get_account(origin.evm);
            let sender_balance = sender_account.balance();
            match ensure(
                sender_balance >= gas_fee.into() + tx.value(), EVMError::InsufficientBalance
            ) {
                Result::Ok(_) => {},
                Result::Err(err) => {
                    println!("process_transaction: Insufficient balance for fees");
                    return ExecutionSummaryTrait::exceptional_failure(err.to_bytes());
                }
            };
            sender_account.set_balance(sender_balance - gas_fee.into());
            env.state.set_account(sender_account);

            let gas_left = match gas_limit.checked_sub(gas::calculate_intrinsic_gas_cost(@tx)) {
                Option::Some(gas_left) => gas_left,
                Option::None => {
                    println!("process_transaction: Out of gas");
                    return ExecutionSummaryTrait::exceptional_failure(
                        EVMError::OutOfGas.to_bytes()
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
                    let calldata = Default::default().span();
                    (to, true, code, calldata)
                },
            };

            let mut accessed_addresses: Set<EthAddress> = Default::default();
            accessed_addresses.add(env.coinbase);
            accessed_addresses.add(to.evm);
            accessed_addresses.add(origin.evm);
            accessed_addresses.extend(constants::precompile_addresses().spanset());

            let mut accessed_storage_keys: Set<(EthAddress, u256)> = Default::default();

            match tx.try_access_list() {
                Option::Some(mut access_list) => {
                    loop {
                        match access_list.pop_front() {
                            Option::Some(access_list_item) => {
                                let AccessListItem{ethereum_address, storage_keys: _ } =
                                    *access_list_item;
                                let storage_keys = access_list_item.to_storage_keys();

                                accessed_addresses.add(ethereum_address);
                                accessed_storage_keys.extend_from_span(storage_keys);
                            },
                            Option::None => { break; }
                        }
                    }
                },
                Option::None => {}
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

            println!("Initial message: {:?}", message);

            let mut summary = EVMTrait::process_message_call(message, env, is_deploy_tx);

            // Gas refunds
            let gas_used = tx.gas_limit() - summary.gas_left;
            let gas_refund = gas_used
                / 5; //TODO(gas) the refund gas should be min(gas_used//5, refund_counter)
            let gas_refund_amount = (summary.gas_left + gas_refund) * gas_price;
            let mut sender_account = summary.state.get_account(origin.evm);
            let sender_balance_after_refund = sender_account.balance() + gas_refund_amount.into();
            sender_account.set_balance(sender_balance_after_refund);
            summary.state.set_account(sender_account);

            summary
        }
    }
}
