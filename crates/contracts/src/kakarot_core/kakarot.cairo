use starknet::{ContractAddress, EthAddress, ClassHash};

const INVOKE_ETH_CALL_FORBIDDEN: felt252 = 'KKT: Cannot invoke eth_call';


#[derive(Copy, Drop, Serde, starknet::Store)]
struct ContractAccountStorage {
    nonce: u64,
    balance: u256,
// TODO: add bytecode as a field for ContractAccountStorage
// bytecode: List

//TODO: add valid jumps as a field for ContractAccountStorage
// valid_jumps: LegacyMap<usize, bool>
}


#[starknet::contract]
mod KakarotCore {
    use contracts::components::ownable::ownable_component::InternalTrait;
    use contracts::components::ownable::{ownable_component};
    use contracts::kakarot_core::interface::IKakarotCore;
    use contracts::kakarot_core::interface;
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::pedersen::{HashState, PedersenTrait};
    use core::starknet::SyscallResultTrait;
    use core::zeroable::Zeroable;
    use evm::context::Status;
    use evm::errors::EVMError;
    use evm::execution::execute;
    use starknet::{
        EthAddress, ContractAddress, ClassHash, get_tx_info, get_contract_address, deploy_syscall
    };
    use super::ContractAccountStorage;
    use super::INVOKE_ETH_CALL_FORBIDDEN;
    use utils::constants::{CONTRACT_ADDRESS_PREFIX, MAX_ADDRESS};
    use utils::traits::U256TryIntoContractAddress;

    component!(path: ownable_component, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::Ownable<ContractState>;

    impl OwnableInternalImpl = ownable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        /// Kakarot storage for accounts: Externally Owned Accounts (EOA) and Contract Accounts (CA)
        /// CAs:
        /// Map EVM address of a CA and the corresponding Kakarot Core storage ->
        /// - nonce (note that this nonce is not the same as the Starknet protocol nonce)
        /// - current balance in native token (CAs can use this balance as an allowance to spend native Starknet token through Kakarot Core)
        /// - bytecode of the CA
        /// Storage of CAs in EVM is defined as a mapping of key (bytes32) - value (bytes32) pairs
        ///
        /// EOAs:
        /// Map their EVM address and their Starknet address
        /// - starknet_address: the deterministic starknet address (31 bytes) computed given an EVM address (20 bytes)
        contract_account_storage: LegacyMap::<EthAddress, ContractAccountStorage>,
        eoa_address_registry: LegacyMap::<EthAddress, ContractAddress>,
        eoa_class_hash: ClassHash,
        // Utility storage
        native_token: ContractAddress,
        deploy_fee: u128,
        chain_id: u128,
        // Components
        #[substorage(v0)]
        ownable: ownable_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnableEvent: ownable_component::Event,
        EOADeployed: EOADeployed,
    }

    #[derive(Drop, starknet::Event)]
    struct EOADeployed {
        #[key]
        evm_address: EthAddress,
        #[key]
        starknet_address: ContractAddress,
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

        /// Gets the storage associated to a contract account
        fn contract_account_storage(
            self: @ContractState, evm_address: EthAddress
        ) -> ContractAccountStorage {
            self.contract_account_storage.read(evm_address)
        }

        /// Deploys an EOA for a particular EVM address
        fn deploy_eoa(ref self: ContractState, evm_address: EthAddress) -> ContractAddress {
            // First let's check that the EOA is not already deployed
            let eoa_starknet_address = self.eoa_address_registry.read(evm_address);
            if eoa_starknet_address.is_non_zero() {
                panic_with_felt252('EOA already deployed');
            }

            // Get the class hash of the EOA to deploy it
            let eoa_class_hash = self.eoa_class_hash.read();

            // Prepare the deployments arguments
            // Salt
            let salt: felt252 = evm_address.into();
            // Constructor calldata
            let constructor_calldata: Span<felt252> = array![
                get_contract_address().into(), evm_address.into()
            ]
                .span();

            // We do not want to deploy from zero, but with Kakarot Core as deployer
            let deploy_from_zero = false;

            // The syscall should only return an error for unexpected problems
            // As we've previously checked that the EOA is not deployed yet
            let (starknet_address, _) = deploy_syscall(
                eoa_class_hash, salt, constructor_calldata, deploy_from_zero
            )
                .unwrap_syscall();

            // We write in the eoa address mapping the address of the EOA
            // This enables Kakarot to be aware that this EOA was already deployed
            self.eoa_address_registry.write(evm_address, starknet_address);

            // Emit an event
            self.emit(EOADeployed { evm_address, starknet_address });

            starknet_address
        }

        /// View entrypoint into the EVM
        /// Performs view calls into the blockchain
        /// It cannot modify the state of the chain
        fn eth_call(
            self: @ContractState,
            from: EthAddress,
            to: EthAddress,
            gas_limit: u128,
            gas_price: u128,
            value: u128,
            data: Span<u8>
        ) -> Span<u8> {
            self.assert_view();
            array![].span()
        }

        /// Transaction entrypoint into the EVM
        /// Executes an EVM transaction and possibly modifies the state
        fn eth_send_transaction(
            ref self: ContractState,
            to: EthAddress,
            gas_limit: u128,
            gas_price: u128,
            value: u128,
            data: Span<u8>
        ) -> Span<u8> {
            array![].span()
        }

        /// Upgrade the KakarotCore smart contract
        /// Using replace_class_syscall
        fn upgrade(
            ref self: ContractState, new_class_hash: ClassHash
        ) { //TODO: implement upgrade logic
        }
    }

    #[generate_trait]
    impl KakarotCoreInternalImpl of KakarotCoreInternal {
        fn assert_view(self: @ContractState) -> Result<(), EVMError> {
            let tx_info = get_tx_info().unbox();

            // If the account that originated the transaction is not zero, this means we
            // are in an invoke transaction instead of a call; therefore, `eth_call` is being wrongly called
            // For invoke transactions, `eth_send_transaction` must be used
            if tx_info.account_contract_address.is_zero() {
                return Result::Err(EVMError::WriteInStaticContext(INVOKE_ETH_CALL_FORBIDDEN));
            }
            Result::Ok(())
        }


        /// Deploys a contract account for a particular EVM address
        fn deploy_contract_account(
            ref self: ContractState, evm_address: EthAddress, value: u256, bytecode: Span<u8>
        ) -> bool {
            let (ret_status, ret_data) = execute(
                :evm_address,
                :bytecode,
                calldata: array![].span(),
                :value,
                gas_price: 0,
                gas_limit: 0,
            );
            //TODO gas params
            if ret_status != Status::Reverted {
                //TODO store_bytecode
                return true;
            }
            return false;
        }
    }
}

