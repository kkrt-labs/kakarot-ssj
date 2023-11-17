use starknet::account::{Call, AccountContract};
use starknet::{ContractAddress, EthAddress, ClassHash};

#[starknet::interface]
trait IExternallyOwnedAccount<TContractState> {
    fn kakarot_core_address(self: @TContractState) -> ContractAddress;
    fn evm_address(self: @TContractState) -> EthAddress;
    fn chain_id(self: @TContractState) -> u128;   

    /// Upgrade the ExternallyOwnedAccount smart contract
    /// Using replace_class_syscall
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn set_chain_id(ref self: TContractState, chain_id: u128);
}

#[starknet::contract]
mod ExternallyOwnedAccount {
    use contracts::components::upgradeable::IUpgradeable;
    use contracts::components::upgradeable::upgradeable_component;
    use starknet::account::{Call, AccountContract};

    use starknet::{
        ContractAddress, EthAddress, ClassHash, VALIDATED, get_caller_address, get_contract_address
    };

    component!(path: upgradeable_component, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableImpl = upgradeable_component::Upgradeable<ContractState>;

    #[storage]
    struct Storage {
        evm_address: EthAddress,
        kakarot_core_address: ContractAddress,
        chain_id: u128,
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradeableEvent: upgradeable_component::Event,
    }


    #[abi(embed_v0)]
    impl ExternallyOwnedAccount of super::IExternallyOwnedAccount<ContractState> {
        fn kakarot_core_address(self: @ContractState) -> ContractAddress {
            self.kakarot_core_address.read()
        }
        fn evm_address(self: @ContractState) -> EthAddress {
            self.evm_address.read()
        }

        fn chain_id(self: @ContractState) -> u128 {
            self.chain_id.read()
        }
        // TODO: make this function reachable from an external invoke call
        // TODO: add some security methods to make sure that only some specific upgrades can be made ( low priority )
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(get_caller_address() == get_contract_address(), 'Caller not contract address');
            self.upgradeable.upgrade_contract(new_class_hash);
        }

        fn set_chain_id(ref self: ContractState, chain_id: u128){
            assert(get_caller_address() == self.kakarot_core_address.read(), 'Caller not kakarot address');
            self.chain_id.write(chain_id);
        }
    }

    #[abi(embed_v0)]
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
