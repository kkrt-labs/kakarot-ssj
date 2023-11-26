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
    use contracts::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use core::option::OptionTrait;

    use starknet::account::{Call, AccountContract};

    use starknet::{
        ContractAddress, EthAddress, ClassHash, VALIDATED, get_caller_address, get_contract_address,
        get_tx_info
    };
    use utils::eth_transaction::{EthTransactionTrait, EthereumTransaction, TransactionMetadata};
    use utils::helpers::{Felt252SpanExTrait, U8SpanExTrait, EthAddressSignatureTrait};

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
        // TODO: add some security methods to make sure that only some specific upgrades can be made ( low priority )
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.assert_only_self();
            self.upgradeable.upgrade_contract(new_class_hash);
        }

        fn set_chain_id(ref self: ContractState, chain_id: u128) {
            assert(
                get_caller_address() == self.kakarot_core_address.read(),
                'Caller not kakarot address'
            );
            self.chain_id.write(chain_id);
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
            assert(
                *call.selector == selector!("eth_send_transaction"),
                'selector not eth_send_transa...'
            );

            let signature = tx_info.signature;

            let tx_metadata = TransactionMetadata {
                address: self.evm_address(),
                chain_id: self.chain_id(),
                account_nonce: tx_info.nonce.try_into().unwrap(),
                signature: signature.try_into_eth_signature().expect('signature extraction failed')
            };

            let encoded_tx = (call.calldata)
                .span()
                .try_into_bytes()
                .expect('converstion to Span<u8> failed');
            let validation_result = EthTransactionTrait::validate_eth_tx(
                tx_metadata, encoded_tx.span()
            )
                .unwrap();

            if (!validation_result) {
                panic(array!['transaction validation failed']);
            }

            VALIDATED
        }

        /// Validate Declare is not used for Kakarot
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            panic_with_felt252('Cannot Declare EOA')
        }


        fn __execute__(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            assert(calls.len() == 1, 'calls length is not 1');

            let call = calls.at(0);
            let calldata = call.calldata.span().try_into_bytes().expect('conversion failed');

            let EthereumTransaction{nonce,
            gas_price,
            gas_limit,
            destination,
            amount,
            calldata,
            chain_id } =
                EthTransactionTrait::decode(
                calldata.span()
            )
                .expect('rlp decoding of tx failed');

            let kakarot_core_dispatcher = IKakarotCoreDispatcher {
                contract_address: self.kakarot_core_address()
            };

            let result = kakarot_core_dispatcher
                .eth_send_transaction(
                    Option::Some(destination), gas_limit, gas_price, amount, calldata
                );

            array![result.to_felt252_array().span()]
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn assert_only_self(self: @ContractState) {
            assert(get_caller_address() == get_contract_address(), 'Caller not self');
        }
    }
}
