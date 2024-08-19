use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait, OutsideExecution};
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcher;
use contracts::test_utils::{setup_contracts_for_testing, deploy_contract_account};
use core::starknet::ContractAddress;
use core::starknet::account::Call;
use core::starknet::contract_address_const;
use core::starknet::secp256_trait::Signature;
use evm::test_utils::{ca_address, chain_id};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp, start_cheat_chain_id_global, stop_cheat_chain_id_global,
    start_mock_call, stop_mock_call
};
use utils::eth_transaction::TransactionType;
use utils::serialization::{serialize_bytes, serialize_transaction_signature};
use utils::test_data::eip_2930_encoded_tx;

const VALID_SIGNATURE: [felt252; 5] = [1, 2, 3, 4, 0];

const EIP2930_CALLER: felt252 = 0xaA36F24f65b5F0f2c642323f3d089A3F0f2845Bf;
const VALID_EIP2930_SIGNATURE: Signature =
    Signature {
        r: 0xbced8d81c36fe13c95b883b67898b47b4b70cae79e89fa27856ddf8c533886d1,
        s: 0x3de0109f00bc3ed95ffec98edd55b6f750cb77be8e755935dbd6cfec59da7ad0,
        y_parity: true
    };

#[derive(Destruct)]
struct CallBuilder {
    call: Call
}

#[generate_trait]
impl CallBuilderImpl of CallBuilderTrait {
    fn new(kakarot_core: ContractAddress) -> CallBuilder {
        CallBuilder {
            call: Call {
                to: kakarot_core,
                selector: selector!("eth_send_transaction"),
                calldata: serialize_bytes(eip_2930_encoded_tx()).span()
            }
        }
    }

    fn with_to(mut self: CallBuilder, to: ContractAddress) -> CallBuilder {
        self.call.to = to;
        self
    }

    fn with_selector(mut self: CallBuilder, selector: felt252) -> CallBuilder {
        self.call.selector = selector;
        self
    }

    fn with_calldata(mut self: CallBuilder, calldata: Span<felt252>) -> CallBuilder {
        self.call.calldata = calldata;
        self
    }

    fn build(mut self: CallBuilder) -> Call {
        return self.call;
    }
}

#[derive(Destruct)]
struct OutsideExecutionBuilder {
    outside_execution: OutsideExecution
}

#[generate_trait]
impl OutsideExecutionBuilderImpl of OutsideExecutionBuilderTrait {
    fn new(kakarot_core: ContractAddress) -> OutsideExecutionBuilder {
        OutsideExecutionBuilder {
            outside_execution: OutsideExecution {
                caller: 'ANY_CALLER'.try_into().unwrap(),
                nonce: 0,
                execute_after: 998,
                execute_before: 1000,
                calls: [
                    CallBuilderTrait::new(kakarot_core).build(),
                ].span()
            }
        }
    }

    fn with_caller(
        mut self: OutsideExecutionBuilder, caller: ContractAddress
    ) -> OutsideExecutionBuilder {
        self.outside_execution.caller = caller;
        self
    }

    fn with_nonce(mut self: OutsideExecutionBuilder, nonce: u64) -> OutsideExecutionBuilder {
        self.outside_execution.nonce = nonce;
        self
    }

    fn with_execute_after(
        mut self: OutsideExecutionBuilder, execute_after: u64
    ) -> OutsideExecutionBuilder {
        self.outside_execution.execute_after = execute_after;
        self
    }

    fn with_execute_before(
        mut self: OutsideExecutionBuilder, execute_before: u64
    ) -> OutsideExecutionBuilder {
        self.outside_execution.execute_before = execute_before;
        self
    }

    fn with_calls(mut self: OutsideExecutionBuilder, calls: Span<Call>) -> OutsideExecutionBuilder {
        self.outside_execution.calls = calls;
        self
    }

    fn build(mut self: OutsideExecutionBuilder) -> OutsideExecution {
        return self.outside_execution;
    }
}

fn setUp() -> (IExtendedKakarotCoreDispatcher, IAccountDispatcher) {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    start_cheat_block_timestamp(ca_address.starknet, 999);
    start_cheat_chain_id_global(chain_id().into());

    (kakarot_core, contract_account)
}

fn tearDown(contract_account: IAccountDispatcher) {
    stop_cheat_chain_id_global();
    stop_cheat_block_timestamp(contract_account.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid caller')]
fn test_execute_from_outside_invalid_caller() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(contract_address_const::<0xb0b>())
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'Too early call')]
fn test_execute_from_outside_too_early_call() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_execute_after(999)
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'Too late call')]
fn test_execute_from_outside_too_late_call() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_execute_before(999)
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'Invalid signature length')]
fn test_execute_from_outside_invalid_signature_length() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .build();

    let _ = contract_account.execute_from_outside(outside_execution, [].span());

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'Multicall not supported')]
fn test_execute_from_outside_multicall_not_supported() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address).build(),
                CallBuilderTrait::new(kakarot_core.contract_address).build(),
            ].span()
        )
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'to is not kakarot core')]
fn test_execute_from_outside_to_is_not_kakarot_core() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls([CallBuilderTrait::new(contract_address_const::<0xb0b>()).build()].span())
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: "selector must be eth_send_transaction")]
fn test_execute_from_outside_wrong_selector() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_selector('bad_selector')
                    .build()
            ].span()
        )
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'invalid signature')]
fn test_execute_from_outside_invalid_signature() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .build();
    let signature: Span<felt252> = [1, 2, 3, 4, (chain_id() * 2 + 40).into()].span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'conversion to Span<u8> failed')]
fn test_execute_from_outside_bad_raw_tx() {
    let (kakarot_core, contract_account) = setUp();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_calldata([1, 256].span())
                    .build()
            ].span()
        )
        .build();
    let signature = VALID_SIGNATURE.span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
#[should_panic(expected: 'failed to validate eth tx')]
fn test_execute_from_outside_invalid_tx() {
    let (kakarot_core, contract_account) = setUp();

    let mut faulty_eip_2930_tx = eip_2930_encoded_tx();
    let _ = faulty_eip_2930_tx.pop_front();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_calls(
            [
                CallBuilderTrait::new(kakarot_core.contract_address)
                    .with_calldata(serialize_bytes(faulty_eip_2930_tx).span())
                    .build()
            ].span()
        )
        .build();

    let signature = serialize_transaction_signature(
        VALID_EIP2930_SIGNATURE, TransactionType::EIP2930, chain_id()
    )
        .span();

    let _ = contract_account.execute_from_outside(outside_execution, signature);

    tearDown(contract_account);
}

#[test]
fn test_execute_from_outside() {
    let (kakarot_core, contract_account) = setUp();

    let caller = contract_address_const::<EIP2930_CALLER>();

    let outside_execution = OutsideExecutionBuilderTrait::new(kakarot_core.contract_address)
        .with_caller(caller)
        .build();
    let signature = serialize_transaction_signature(
        VALID_EIP2930_SIGNATURE, TransactionType::EIP2930, chain_id()
    )
        .span();

    start_cheat_caller_address(contract_account.contract_address, caller);

    start_mock_call::<
        (bool, Span<u8>, u128)
    >(
        kakarot_core.contract_address,
        selector!("eth_send_transaction"),
        (true, [1, 2, 3].span(), 0)
    );

    let data = contract_account.execute_from_outside(outside_execution, signature);

    assert(data.len() == 1, 'bad length');
    assert(*data.at(0) == [1, 2, 3].span(), 'bad data');

    stop_mock_call(kakarot_core.contract_address, selector!("eth_send_transaction"));
    stop_cheat_caller_address(contract_account.contract_address);
    tearDown(contract_account);
}
