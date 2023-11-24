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
    use contracts::kakarot_core::interface;
    use core::starknet::SyscallResultTrait;
    use core::zeroable::Zeroable;

    use evm::context::Status;
    use evm::errors::{EVMError, EVMErrorTrait, CALLING_FROM_CA, CALLING_FROM_UNDEPLOYED_ACCOUNT};
    use evm::execution::execute;
    use evm::model::account::{Account, AccountType, AccountTrait};
    use evm::model::contract_account::{ContractAccountTrait};
    use evm::model::eoa::{EOATrait};
    use evm::model::{ExecutionResult, Address, AddressTrait};
    use evm::state::StateTrait;
    use starknet::{
        EthAddress, ContractAddress, ClassHash, get_tx_info, get_contract_address, deploy_syscall,
        get_caller_address
    };
    use super::{INVOKE_ETH_CALL_FORBIDDEN};
    use super::{StoredAccountType};
    use utils::helpers::{compute_starknet_address, EthAddressExTrait};
    use utils::rlp::RLPTrait;

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
    impl KakarotCoreImpl of interface::IKakarotCore<ContractState> {
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
            let ca_address = ContractAccountTrait::at(evm_address)
                .expect('Fetching CA failed')
                .expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.nonce()
        }

        fn account_balance(self: @ContractState, evm_address: EthAddress) -> u256 {
            let address = Address {
                evm: evm_address, starknet: self.compute_starknet_address(evm_address)
            };
            address.balance().unwrap()
        }

        fn contract_account_storage_at(
            self: @ContractState, evm_address: EthAddress, key: u256
        ) -> u256 {
            let ca_address = ContractAccountTrait::at(evm_address)
                .expect('Fetching CA failed')
                .expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.storage_at(key)
        }

        fn contract_account_bytecode(self: @ContractState, evm_address: EthAddress) -> Span<u8> {
            let ca_address = ContractAccountTrait::at(evm_address)
                .expect('Fetching CA failed')
                .expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.bytecode()
        }

        fn contract_account_false_positive_jumpdest(
            self: @ContractState, evm_address: EthAddress, offset: usize
        ) -> bool {
            let ca_address = ContractAccountTrait::at(evm_address)
                .expect('Fetching CA failed')
                .expect('No CA found');
            let contract_account = IContractAccountDispatcher {
                contract_address: ca_address.starknet
            };
            contract_account.is_false_positive_jumpdest(offset)
        }

        fn deploy_eoa(ref self: ContractState, evm_address: EthAddress) -> ContractAddress {
            EOATrait::deploy(evm_address).expect('EOA Deployment failed').starknet
        }

        fn eth_call(
            self: @ContractState,
            from: EthAddress,
            to: Option<EthAddress>,
            gas_limit: u128,
            gas_price: u128,
            value: u256,
            data: Span<u8>
        ) -> Span<u8> {
            if !self.is_view() {
                panic_with_felt252('fn must be called, not invoked');
            };

            let from = Address { evm: from, starknet: self.compute_starknet_address(from) };

            let result = self.handle_call(:from, :to, :gas_limit, :gas_price, :value, :data);
            match result {
                Result::Ok(result) => result.return_data,
                // TODO: Return the error message as Bytes in the response
                // Eliminate all paths of possible panic in logic with relations to the EVM itself.
                Result::Err(err) => panic_with_felt252(err.to_string()),
            }
        }

        fn eth_send_transaction(
            ref self: ContractState,
            to: Option<EthAddress>,
            gas_limit: u128,
            gas_price: u128,
            value: u256,
            data: Span<u8>
        ) -> Span<u8> {
            let starknet_caller_address = get_caller_address();
            let account = IExternallyOwnedAccountDispatcher {
                contract_address: starknet_caller_address
            };
            let from = Address { evm: account.evm_address(), starknet: starknet_caller_address };

            // Invariant:
            // We want to make sure the caller is part of the Kakarot address_registry
            // and is an EOA. Contracts are added to the registry ONLY if there are
            // part of the Kakarot system and thus deployed by the main Kakarot contract
            // itself.

            let (caller_account_type, caller_starknet_address) = self
                .address_registry(from.evm)
                .expect('Fetching EOA failed');
            assert(caller_account_type == AccountType::EOA, 'Caller is not an EOA');

            let mut result = self.handle_call(:from, :to, :gas_limit, :gas_price, :value, :data);
            match result {
                Result::Ok(result) => {
                    let mut state = result.state;
                    state.commit_state();
                    result.return_data
                },
                // TODO: Return the error message as Bytes in the response
                // Eliminate all paths of possible panic in logic with relations to the EVM itself.
                Result::Err(err) => panic_with_felt252(err.to_string()),
            }
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
        /// Triggerred when deployment of an EOA or CA is successful
        fn set_address_registry(
            ref self: ContractState, evm_address: EthAddress, account: StoredAccountType
        ) {
            self.address_registry.write(evm_address, account);
        }

        fn handle_call(
            self: @ContractState,
            from: Address,
            to: Option<EthAddress>,
            gas_limit: u128,
            gas_price: u128,
            value: u256,
            data: Span<u8>
        ) -> Result<ExecutionResult, EVMError> {
            match to {
                //TODO we can optimize this by doing this one step later, when we load the account from the state. This way we can avoid loading the account bytecode twice.
                Option::Some(to) => {
                    let bytecode = AccountTrait::fetch_or_create(to)?.code;

                    let target_starknet_address = self.compute_starknet_address(to);
                    let to = Address { evm: to, starknet: target_starknet_address };

                    let execution_result = execute(
                        from,
                        to,
                        :bytecode,
                        calldata: data,
                        :value,
                        :gas_price,
                        :gas_limit,
                        read_only: false,
                    );
                    return Result::Ok(execution_result);
                },
                Option::None => {
                    // Deploy tx case.
                    // HASH(RLP(deployer_address, deployer_nonce))[0..20]
                    //TODO manually set target account type to CA in state
                    panic_with_felt252('deploy tx flow unimplemented')
                },
            }
        }
    }
}
