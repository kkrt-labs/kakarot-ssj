use starknet::{ContractAddress, EthAddress, ClassHash};

const INVOKE_ETH_CALL_FORBIDDEN: felt252 = 'KKT: Cannot invoke eth_call';


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
    use evm::model::account::{Account, AccountTrait};
    use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
    use evm::model::eoa::{EOA, EOATrait};
    use starknet::{
        EthAddress, ContractAddress, ClassHash, get_tx_info, get_contract_address, deploy_syscall
    };
    use super::INVOKE_ETH_CALL_FORBIDDEN;
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
        /// CAs storage is handled outside of the Storage struct (see contract_account.cairo)
        /// It maps the EVM address of a CA and the corresponding Kakarot Core storage ->
        /// - nonce (note that this nonce is not the same as the Starknet protocol nonce)
        /// - current balance in native token (CAs can use this balance as an allowance to spend native Starknet token through Kakarot Core)
        /// - bytecode of the CA
        /// Storage of CAs in EVM is defined as a mapping of key (bytes32) - value (bytes32) pairs
        ///
        /// EOAs:
        /// Map their EVM address and their Starknet address
        /// - starknet_address: the deterministic starknet address (31 bytes) computed given an EVM address (20 bytes)
        eoa_address_registry: LegacyMap::<EthAddress, ContractAddress>,
        eoa_class_hash: ClassHash,
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
        ContractAccountDeployed: ContractAccountDeployed
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
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        native_token: ContractAddress,
        deploy_fee: u128,
        eoa_class_hash: ClassHash,
        owner: ContractAddress,
        chain_id: u128,
    ) {
        self.native_token.write(native_token);
        self.deploy_fee.write(deploy_fee);
        self.eoa_class_hash.write(eoa_class_hash);
        self.ownable.initializer(owner);
        self.chain_id.write(chain_id);
    }

    #[external(v0)]
    impl KakarotCoreImpl of interface::IKakarotCore<ContractState> {
        fn set_native_token(ref self: ContractState, native_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.native_token.write(native_token);
        }

        /// Gets the native token used by the Kakarot smart contract
        fn native_token(self: @ContractState) -> ContractAddress {
            self.native_token.read()
        }

        /// Sets the deploy fee for an EOA
        /// Currently, the Kakarot RPC can trigger an EOA deployment,
        /// and optimistically fund it.
        /// Then, the KakarotCore smart contract is able to levy this fee retroactively from the EOA
        /// And reimburse the RPC's smart wallet.
        fn set_deploy_fee(ref self: ContractState, deploy_fee: u128) {
            self.ownable.assert_only_owner();
            self.deploy_fee.write(deploy_fee);
        }

        /// Get the deploy fee
        fn deploy_fee(self: @ContractState) -> u128 {
            self.deploy_fee.read()
        }

        /// Get the chain id
        fn chain_id(self: @ContractState) -> u128 {
            self.chain_id.read()
        }

        /// Deterministically computes a Starknet address for an given EVM address
        /// The address is computed as the Starknet address corresponding to the deployment of an EOA,
        /// Using its EVM address as salt, and KakarotCore as deployer.
        /// https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/core/os/contract_address/contract_address.cairo#L2
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
            // For an EOA, the constructor calldata is:
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
                .update_with(self.eoa_class_hash.read())
                .update_with(constructor_calldata_hash)
                .update(5)
                .finalize();

            let normalized_address: ContractAddress = (hash.into() & MAX_ADDRESS)
                .try_into()
                .unwrap();
            // We know this unwrap is safe, because of the above bitwise AND on 2 ** 251
            normalized_address
        }

        /// Checks into KakarotCore storage if an EOA has been deployed for a
        /// particular EVM address and if so, returns its corresponding Starknet Address
        /// Otherwise, returns 0
        fn eoa_starknet_address(self: @ContractState, evm_address: EthAddress) -> ContractAddress {
            self.eoa_address_registry.read(evm_address)
        }

        /// Gets the nonce associated to a contract account
        fn contract_account_nonce(self: @ContractState, evm_address: EthAddress) -> u64 {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.nonce().unwrap()
        }

        /// Gets the balance associated to a contract account
        fn account_balance(self: @ContractState, evm_address: EthAddress) -> u256 {
            let maybe_account = AccountTrait::account_type_at(evm_address).unwrap();
            match maybe_account {
                Option::Some(account) => account.balance().unwrap(),
                Option::None => 0
            }
        }

        /// Gets the value associated to a key in the contract account storage
        fn contract_account_storage_at(
            self: @ContractState, evm_address: EthAddress, key: u256
        ) -> u256 {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.storage_at(key).unwrap()
        }


        /// Gets the bytecode associated to a contract account
        fn contract_account_bytecode(self: @ContractState, evm_address: EthAddress) -> ByteArray {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.load_bytecode().unwrap()
        }

        /// Returns true if the given `offset` is a valid jump destination in the bytecode of a contract account.
        fn contract_account_valid_jump(
            self: @ContractState, evm_address: EthAddress, offset: usize
        ) -> bool {
            let ca = ContractAccountTrait::at(evm_address).unwrap().unwrap();
            ca.is_valid_jump(offset).unwrap()
        }

        /// Deploys an EOA for a particular EVM address
        fn deploy_eoa(ref self: ContractState, evm_address: EthAddress) -> ContractAddress {
            EOATrait::deploy(evm_address).unwrap().starknet_address
        }

        /// View entrypoint into the EVM
        /// Performs view calls into the blockchain
        /// It cannot modify the state of the chain
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

        /// Transaction entrypoint into the EVM
        /// Executes an EVM transaction and possibly modifies the state
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

        /// Upgrade the KakarotCore smart contract
        /// Using replace_class_syscall
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade_contract(new_class_hash);
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
                    let bytecode = match AccountTrait::account_at(to)? {
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
