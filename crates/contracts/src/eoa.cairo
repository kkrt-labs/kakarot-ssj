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
}

#[starknet::contract(account)]
mod ExternallyOwnedAccount {
    use contracts::components::upgradeable::IUpgradeable;
    use contracts::components::upgradeable::upgradeable_component;
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use core::starknet::event::EventEmitter;

    use starknet::account::{Call, AccountContract};

    use starknet::{
        ContractAddress, EthAddress, ClassHash, VALIDATED, get_caller_address, get_contract_address,
        get_tx_info
    };
    use utils::eth_transaction::{EthTransactionTrait, EthereumTransaction, TransactionMetadata};
    use utils::helpers::ArrayExtTrait;
    use utils::helpers::{
        Felt252SpanExTrait, U8SpanExTrait, EthAddressSignatureTrait, TryIntoEthSignatureTrait
    };

    component!(path: upgradeable_component, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableImpl = upgradeable_component::Upgradeable<ContractState>;

    #[storage]
    struct Storage {
        evm_address: EthAddress,
        kakarot_core_address: ContractAddress,
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradeableEvent: upgradeable_component::Event,
        TransactionExecuted: TransactionExecuted
    }

    /// event representing execution of transaction, should be emmitted inside `__execute__` of an EOA
    ///
    /// # Arguments
    /// * `hash`: the transaction hash { can be obtained from `get_tx_info` }
    /// * `response`: represents the return data obtained by applying the transaction
    /// * `success`: represents whether the transaction succeeded or not
    #[derive(Drop, Debug, starknet::Event)]
    struct TransactionExecuted {
        #[key]
        hash: u256,
        response: Span<felt252>,
        success: bool
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
            get_tx_info().unbox().chain_id.try_into().unwrap()
        }
        // TODO: add some security methods to make sure that only some specific upgrades can be made ( low priority )
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.assert_only_self();
            self.upgradeable.upgrade_contract(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl AccountContractImpl of AccountContract<ContractState> {
        fn __validate__(ref self: ContractState, calls: Array<Call>) -> felt252 {
            assert(get_caller_address().is_zero(), 'Caller not 0');

            let tx_info = get_tx_info().unbox();

            let call_len = calls.len();
            assert(call_len == 1, 'call len is not 1');

            let call = calls.at(0);
            assert(*call.to == self.kakarot_core_address(), 'to is not kakarot core');
            assert!(
                *call.selector == selector!("eth_send_transaction"),
                "Validate: selector must be eth_send_transaction"
            );

            let signature = tx_info.signature;
            let chain_id = self.chain_id();

            let tx_metadata = TransactionMetadata {
                address: self.evm_address(),
                chain_id,
                account_nonce: tx_info.nonce.try_into().unwrap(),
                signature: signature
                    .try_into_eth_signature(chain_id)
                    .expect('signature extraction failed')
            };

            let encoded_tx = (*call.calldata)
                .try_into_bytes()
                .expect('conversion to Span<u8> failed');
            let validation_result = EthTransactionTrait::validate_eth_tx(
                tx_metadata, encoded_tx.span()
            )
                .expect('failed to validate eth tx');

            assert(validation_result, 'transaction validation failed');

            VALIDATED
        }

        /// Validate Declare is not used for Kakarot
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            panic_with_felt252('Cannot Declare EOA')
        }


        fn __execute__(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            assert(calls.len() == 1, 'calls length is not 1');

            let call = calls.at(0);
            let calldata = (*call.calldata).try_into_bytes().expect('conversion failed').span();

            let tx = EthTransactionTrait::decode(calldata).expect('rlp decoding of tx failed');

            let kakarot_core_dispatcher = IKakarotCoreDispatcher {
                contract_address: self.kakarot_core_address()
            };

            let (return_data, success) = kakarot_core_dispatcher.eth_send_transaction(tx);
            let return_data = return_data.to_felt252_array().span();

            let tx_info = get_tx_info().unbox();
            self
                .emit(
                    TransactionExecuted {
                        hash: tx_info.transaction_hash.into(),
                        response: return_data,
                        success: success
                    }
                );

            array![return_data]
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn assert_only_self(self: @ContractState) {
            assert(get_caller_address() == get_contract_address(), 'Caller not self');
        }
    }
}
