use starknet::{ContractAddress, EthAddress, ClassHash};

#[starknet::interface]
trait IKakarotCore<TContractState> {
    fn set_native_token(ref self: TContractState, new_address: ContractAddress);
    fn native_token(self: @TContractState) -> ContractAddress;
    fn set_deploy_fee(ref self: TContractState, deploy_fee: u128);
    fn deploy_fee(self: @TContractState) -> u128;
    fn compute_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;
    fn get_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;
    fn deploy_externally_owned_account(
        ref self: TContractState, evm_address: EthAddress
    ) -> ContractAddress;
    fn eth_call(
        self: @TContractState,
        from: EthAddress,
        to: EthAddress,
        gas_limit: u128,
        gas_price: u128,
        value: u128,
        data: Span<u8>
    ) -> Span<u8>;
    fn eth_send_transaction(
        ref self: TContractState,
        to: EthAddress,
        gas_limit: u128,
        gas_price: u128,
        value: u128,
        data: Span<u8>
    ) -> Span<u8>;
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[derive(Copy, Drop, Serde, starknet::Store)]
enum ContractTypeStorage {
    EOA: ContractAddress,
    ContractAccount: ContractAccountStorage
}

/// Note: We might not want to implement Copy on the bytecode field, as it'll be an expensive List
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
    use starknet::{EthAddress, ContractAddress, ClassHash};
    use super::{ContractAccountStorage, ContractTypeStorage};
    #[storage]
    struct Storage {
        /// Kakarot storage for accounts: Externally Owned Accounts (EOA) and Contract Accounts (CA)
        /// EOAs:
        /// Map their EVM address and their Starknet address
        /// - starknet_address: the deterministic starknet address (31 bytes) computed given an EVM address (20 bytes)
        ///
        /// CAs:
        /// Map EVM address of a CA and the corresponding Kakarot Core storage -> 
        /// - nonce (note that this nonce is not the same as the Starknet protocol nonce)
        /// - current balance in native token (CAs can use this balance as an allowance to spend native Starknet token through Kakarot Core)
        /// - bytecode of the CA
        accounts: LegacyMap::<ContractAddress, ContractTypeStorage>,
        native_token: ContractAddress,
        deploy_fee: u128,
        eoa_class_hash: ClassHash,
        /// Storage of CAs in EVM is defined as a mapping of key (bytes32) - value (bytes32) pairs
        contract_account_storage: LegacyMap<(EthAddress, u256), u256>,
    // TODO: add ownable as component
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        native_token: ContractAddress,
        deploy_fee: u128,
        externally_owned_account_class_hash: ClassHash
    ) {
        self.native_token.write(native_token);
        self.deploy_fee.write(deploy_fee);
        self.externally_owned_account_class_hash.write(externally_owned_account_class_hash);
    }
}

