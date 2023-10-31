use starknet::{ContractAddress, EthAddress, ClassHash};

const INVOKE_ETH_CALL_FORBIDDEN: felt252 = 'KKT: Cannot invoke eth_call';


// Local enum to differentiate EOA and CA in storage
// TODO: remove distinction between EOA and CA as EVM accounts
// As soon as EOA::nonce can be handled at the application level
#[derive(Drop, starknet::Store, Serde, PartialEq, Default)]
enum StoredAccountType {
    #[default]
    UninitializedAccount,
    EOA: ContractAddress,
    ContractAccount: ContractAddress,
}

#[starknet::contract]
mod KakarotCore {
    use contracts::components::ownable::{ownable_component};
    use contracts::components::upgradeable::{IUpgradeable, upgradeable_component};
    use contracts::kakarot_core::interface::IKakarotCore;
    use contracts::kakarot_core::interface;
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::option::OptionTrait;
    use core::pedersen::{HashState, PedersenTrait};
    use core::starknet::SyscallResultTrait;
    use core::zeroable::Zeroable;
    use evm::context::Status;
    use evm::errors::{EVMError, EVMErrorTrait};
    use evm::execution::execute;
    use evm::model::ExecutionResult;
    use evm::model::account::{Account, AccountTrait};
    use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
    use evm::model::eoa::{EOA, EOATrait};
    use starknet::{
        EthAddress, ContractAddress, ClassHash, get_tx_info, get_contract_address, deploy_syscall
    };
    use super::{INVOKE_ETH_CALL_FORBIDDEN};
    use super::{StoredAccountType};
    use utils::constants::{CONTRACT_ADDRESS_PREFIX, MAX_ADDRESS};
    use utils::traits::{U256TryIntoContractAddress, ByteArraySerde};

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

    #[external(v0)]
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

            // pedersen(a1, a2, a3) is defined as:
            // pedersen(pedersen(pedersen(a1, a2), a3), len([a1, a2, a3]))
            // https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/hash_state.py#L6
            // https://github.com/xJonathanLEI/starknet-rs/blob/master/starknet-core/src/crypto.rs#L49
            // Constructor Calldata
            // For an Account, the constructor calldata is:
            // [kakarot_address, evm_address]
            let constructor_calldata_hash = PedersenTrait::new(0)
                .update_with(deployer)
                .update_with(evm_address)
                .update(2)
                .finalize();

            let hash = PedersenTrait::new(0)
                .update_with(CONTRACT_ADDRESS_PREFIX)
                .update_with(deployer)
                .update_with(evm_address)
                .update_with(self.account_class_hash.read())
                .update_with(constructor_calldata_hash)
                .update(5)
                .finalize();

            let normalized_address: ContractAddress = (hash.into() & MAX_ADDRESS)
                .try_into()
                .unwrap();
            // We know this unwrap is safe, because of the above bitwise AND on 2 ** 251
            normalized_address
        }

        fn address_registry(self: @ContractState, evm_address: EthAddress) -> StoredAccountType {
            self.address_registry.read(evm_address)
        }

        fn set_address_registry(
            ref self: ContractState, evm_address: EthAddress, account: StoredAccountType
        ) {
            self.address_registry.write(evm_address, account);
        }

        fn contract_account_nonce(self: @ContractState, evm_address: EthAddress) -> u64 {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.nonce().unwrap()
        }

        fn account_balance(self: @ContractState, evm_address: EthAddress) -> u256 {
            let maybe_account = AccountTrait::account_type_at(evm_address).unwrap();
            match maybe_account {
                Option::Some(account) => account.balance().unwrap(),
                Option::None => 0
            }
        }

        fn contract_account_storage_at(
            self: @ContractState, evm_address: EthAddress, key: u256
        ) -> u256 {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.storage_at(key).unwrap()
        }

        fn contract_account_bytecode(self: @ContractState, evm_address: EthAddress) -> Span<u8> {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.load_bytecode().unwrap()
        }

        fn contract_account_false_positive_jumpdest(
            self: @ContractState, evm_address: EthAddress, offset: usize
        ) -> bool {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.is_false_positive_jumpdest(offset).unwrap()
        }

        fn deploy_eoa(ref self: ContractState, evm_address: EthAddress) -> ContractAddress {
            EOATrait::deploy(evm_address).unwrap().starknet_address
        }

        fn deploy_ca(
            ref self: ContractState, evm_address: EthAddress, bytecode: Span<u8>
        ) -> ContractAddress {
            ContractAccountTrait::deploy(evm_address, bytecode).unwrap().starknet_address
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
            to: EthAddress,
            gas_limit: u128,
            gas_price: u128,
            value: u256,
            data: Span<u8>
        ) -> Span<u8> {
            array![].span()
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade_contract(new_class_hash);
        }

        fn eoa_class_hash(self: @ContractState) -> ClassHash {
            self.eoa_class_hash.read()
        }

        fn set_eoa_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            let old_class_hash = self.eoa_class_hash.read();
            self.eoa_class_hash.write(new_class_hash);
            self.emit(EOAClassHashChange { old_class_hash, new_class_hash });
        }

        fn ca_class_hash(self: @ContractState) -> ClassHash {
            self.ca_class_hash.read()
        }

        fn set_ca_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            let old_class_hash = self.ca_class_hash.read();
            self.ca_class_hash.write(new_class_hash);
            self.emit(CAClassHashChange { old_class_hash, new_class_hash });
        }

        fn account_class_hash(self: @ContractState) -> ClassHash {
            self.account_class_hash.read()
        }

        fn set_account_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
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

        fn handle_call(
            self: @ContractState,
            from: EthAddress,
            to: Option<EthAddress>,
            gas_limit: u128,
            gas_price: u128,
            value: u256,
            data: Span<u8>
        ) -> Result<ExecutionResult, EVMError> {
            match to {
                Option::Some(to) => {
                    let bytecode = match AccountTrait::account_type_at(to)? {
                        Option::Some(account) => account.bytecode()?,
                        Option::None => Default::default().span(),
                    };
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
                    let bytecode = data;
                    // TODO: compute_evm_address
                    // HASH(RLP(deployer_address, deployer_nonce))[0..20]
                    panic_with_felt252('unimplemented')
                },
            }
        }
    }
}
