use starknet::account::{Call, AccountContract};
// Migrate https://github.com/kkrt-labs/kakarot/blob/7ec7a96074394ddb592a2b6fbea279c6c5cb25a6/src/kakarot/accounts/eoa/externally_owned_account.cairo#L4
use starknet::{ContractAddress, EthAddress,};

#[starknet::interface]
trait IExternallyOwnedAccount<TContractState> {
    fn kakarot_core_address(self: @TContractState) -> ContractAddress;
    fn evm_address(self: @TContractState) -> EthAddress;
}

#[starknet::contract]
mod ExternallyOwnedAccount {
    use starknet::account::{Call, AccountContract};
    use starknet::{ContractAddress, EthAddress, VALIDATED, get_caller_address};

    #[storage]
    struct Storage {
        evm_address: EthAddress,
        kakarot_core_address: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, kakarot_address: ContractAddress, evm_address: EthAddress
    ) {
        self.kakarot_core_address.write(kakarot_address);
        self.evm_address.write(evm_address);
    }

    #[external(v0)]
    impl ExternallyOwnedAccount of super::IExternallyOwnedAccount<ContractState> {
        fn kakarot_core_address(self: @ContractState) -> ContractAddress {
            self.kakarot_core_address.read()
        }
        fn evm_address(self: @ContractState) -> EthAddress {
            self.evm_address.read()
        }
    }

    #[external(v0)]
    impl AccountContractImpl of AccountContract<ContractState> {
        fn __validate__(ref self: ContractState, calls: Array<Call>) -> felt252 {
            assert(get_caller_address().is_zero(), 'Caller not zero');
            // TODO
            // Steps:
            // Receive a payload formed as:
            // Starknet Transaction Signature field: r, s, v (EVM Signature fields)
            // Calldata field: an RLP-encoded EVM transaction, without r, s, v

            // Step 1:
            // Hash RLP-encoded EVM transaction
            // Step 2:
            // Verify EVM signature using get_tx_info().signature field against the keccak hash of the EVM tx
            // Step 3:
            // If valid signature, decode the RLP-encoded payload
            // Step 4:
            // Return ok

            VALIDATED
        }

        /// Validate Declare is not used for Kakarot
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            panic_with_felt252('Cannot Declare EOA')
        }


        fn __execute__(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            // TODO

            // Step 1:
            // Decode RLP-encoded transaction
            // Step 2:
            // Call KakarotCore.send_eth_transaction with correct params

            array![]
        }
    }
}

