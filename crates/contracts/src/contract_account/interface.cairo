use starknet::account::{Call, AccountContract};
use starknet::{ContractAddress, EthAddress, ClassHash};

#[starknet::interface]
trait IContractAccount<TContractState> {
    fn kakarot_core_address(self: @TContractState) -> ContractAddress;
    fn evm_address(self: @TContractState) -> EthAddress;

    // Contract Account Specific Methods
    // ***
    // BYTECODE
    // ***
    /// Getter for CA bytecode
    fn bytecode(self: @TContractState) -> Span<u8>;

    /// Set the bytecode of a contract account
    fn set_bytecode(ref self: TContractState, bytecode: Span<u8>);

    // ***
    // STORAGE
    // ***
    /// Getter for a specific EVM storage slot (key: bytes32, value: bytes32)
    fn storage_at(self: @TContractState, key: u256) -> u256;

    /// Setter for a specific EVM storage slot  (key: bytes32, value: bytes32)
    fn set_storage_at(ref self: TContractState, key: u256, value: u256);

    // ***
    // NONCE
    // The concept of nonce for CAs in EVM exists (when calling CREATE or CREATE2, a CA's nonce is incremented)
    // In Starknet context, the protocol handles ONLY the nonce of wallets (so called `accounts` - AA equivalent of EVM EOAs)
    // Therefore, we account for the nonce directly as a storage variable
    // ***

    fn nonce(self: @TContractState) -> u64;
    fn set_nonce(ref self: TContractState, new_nonce: u64);
    fn increment_nonce(ref self: TContractState);
    // ***
    // JUMP
    // Records of valid jumps in the context of jump opcodes
    // All valids jumps are recorded in a mapping offset -> bool, to know if a vlaid
    // ***

    /// Checks if for a specific offset, i.e. if  bytecode at index `offset`, bytecode[offset] == 0x5B && is part of a PUSH opcode input.
    /// Prevents false positive checks in JUMP opcode of the type: jump destination opcode == JUMPDEST in appearance, but is a PUSH opcode bytecode slice.
    fn is_false_jumpdest(self: @TContractState, offset: usize) -> bool;

    fn set_false_positive_jumpdest(ref self: TContractState, offset: usize);

    /// Selfdestruct whatever can be
    /// It's not possible to remove a contract in Starknet
    fn selfdestruct(ref self: TContractState);

    /// Upgrade the ExternallyOwnedAccount smart contract
    /// Using replace_class_syscall
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
