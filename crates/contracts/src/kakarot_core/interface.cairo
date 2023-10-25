use starknet::{ContractAddress, EthAddress, ClassHash};
use utils::traits::ByteArraySerde;

#[starknet::interface]
trait IKakarotCore<TContractState> {
    /// Sets the native token, this token will be considered the native coin in the Ethereum sense
    fn set_native_token(ref self: TContractState, native_token: ContractAddress);

    /// Gets the native token used by the Kakarot smart contract
    fn native_token(self: @TContractState) -> ContractAddress;

    /// Sets the deploy fee for an EOA
    /// Currently, the Kakarot RPC can trigger an EOA deployment,
    /// and optimistically fund it.
    /// Then, the KakarotCore smart contract is able to levy this fee retroactively from the EOA
    /// And reimburse the RPC's smart wallet.
    fn set_deploy_fee(ref self: TContractState, deploy_fee: u128);

    /// Get the deploy fee
    fn deploy_fee(self: @TContractState) -> u128;

    /// Get the chain id
    fn chain_id(self: @TContractState) -> u128;

    /// Deterministically computes a Starknet address for an given EVM address
    /// The address is computed as the Starknet address corresponding to the deployment of an EOA,
    /// Using its EVM address as salt, and KakarotCore as deployer.
    fn compute_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Checks into KakarotCore storage if an EOA has been deployed for a
    /// particular EVM address and if so, returns its corresponding Starknet Address.
    /// Otherwise, returns 0
    fn eoa_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Gets the nonce associated to a contract account
    fn contract_account_nonce(self: @TContractState, evm_address: EthAddress) -> u64;

    /// Gets the balance associated to an account.
    fn account_balance(self: @TContractState, evm_address: EthAddress) -> u256;

    /// Gets the value associated to a key in the contract account storage
    fn contract_account_storage_at(
        self: @TContractState, evm_address: EthAddress, key: u256
    ) -> u256;

    /// Gets the bytecode associated to a contract account
    fn contract_account_bytecode(self: @TContractState, evm_address: EthAddress) -> ByteArray;

    /// Returns true if the given `offset` is a valid jump destination in the bytecode of a contract account.
    fn contract_account_valid_jump(
        self: @TContractState, evm_address: EthAddress, offset: usize
    ) -> bool;

    /// Deploys an EOA for a particular EVM address
    fn deploy_eoa(ref self: TContractState, evm_address: EthAddress) -> ContractAddress;

    /// View entrypoint into the EVM
    /// Performs view calls into the blockchain
    /// It cannot modify the state of the chain
    fn eth_call(
        self: @TContractState,
        from: EthAddress,
        to: EthAddress,
        gas_limit: u128,
        gas_price: u128,
        value: u128,
        data: Span<u8>
    ) -> Span<u8>;

    /// Transaction entrypoint into the EVM
    /// Executes an EVM transaction and possibly modifies the state
    fn eth_send_transaction(
        ref self: TContractState,
        to: EthAddress,
        gas_limit: u128,
        gas_price: u128,
        value: u128,
        data: Span<u8>
    ) -> Span<u8>;

    /// Upgrade the KakarotCore smart contract
    /// Using replace_class_syscall
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::interface]
trait IExtendedKakarotCore<TContractState> {
    /// Sets the native token, this token will be considered the native coin in the Ethereum sense
    fn set_native_token(ref self: TContractState, native_token: ContractAddress);

    /// Gets the native token used by the Kakarot smart contract
    fn native_token(self: @TContractState) -> ContractAddress;

    /// Sets the deploy fee for an EOA
    /// Currently, the Kakarot RPC can trigger an EOA deployment,
    /// and optimistically fund it.
    /// Then, the KakarotCore smart contract is able to levy this fee retroactively from the EOA
    /// And reimburse the RPC's smart wallet.
    fn set_deploy_fee(ref self: TContractState, deploy_fee: u128);

    /// Get the deploy fee
    fn deploy_fee(self: @TContractState) -> u128;

    /// Get the chain id
    fn chain_id(self: @TContractState) -> u128;

    /// Deterministically computes a Starknet address for an given EVM address
    /// The address is computed as the Starknet address corresponding to the deployment of an EOA,
    /// Using its EVM address as salt, and KakarotCore as deployer.
    fn compute_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Checks into KakarotCore storage if an EOA has been deployed for a
    /// particular EVM address and if so, returns its corresponding Starknet Address
    fn eoa_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Deploys an EOA for a particular EVM address
    fn deploy_eoa(ref self: TContractState, evm_address: EthAddress) -> ContractAddress;

    /// View entrypoint into the EVM
    /// Performs view calls into the blockchain
    /// It cannot modify the state of the chain
    fn eth_call(
        self: @TContractState,
        from: EthAddress,
        to: EthAddress,
        gas_limit: u128,
        gas_price: u128,
        value: u128,
        data: Span<u8>
    ) -> Span<u8>;

    /// Transaction entrypoint into the EVM
    /// Executes an EVM transaction and possibly modifies the state
    fn eth_send_transaction(
        ref self: TContractState,
        to: EthAddress,
        gas_limit: u128,
        gas_price: u128,
        value: u128,
        data: Span<u8>
    ) -> Span<u8>;

    /// Upgrade the KakarotCore smart contract
    /// Using replace_class_syscall
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
}
