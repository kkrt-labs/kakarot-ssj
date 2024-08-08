use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::test_utils::{deploy_contract_account};
use contracts::uninitialized_account::UninitializedAccount;
use core::nullable::{match_nullable, FromNullableResult};
use core::traits::TryInto;
use evm::errors::{EVMError};

use evm::model::vm::{VM, VMTrait};
use evm::model::{Message, Environment, Address, Account, AccountTrait};
use evm::state::State;
use evm::{stack::{Stack, StackTrait}, memory::{Memory, MemoryTrait}};
use starknet::{
    StorageBaseAddress, storage_base_address_from_felt252, contract_address_try_from_felt252,
    ContractAddress, EthAddress, deploy_syscall, get_contract_address, contract_address_const
};
use utils::constants;

#[derive(Destruct)]
struct VMBuilder {
    vm: VM
}

#[generate_trait]
impl VMBuilderImpl of VMBuilderTrait {
    fn new() -> VMBuilder {
        VMBuilder { vm: Default::default() }.with_gas_limit(0x100000000000000000000)
    }

    fn new_with_presets() -> VMBuilder {
        VMBuilder { vm: preset_vm() }
    }

    fn with_return_data(mut self: VMBuilder, return_data: Span<u8>) -> VMBuilder {
        self.vm.set_return_data(return_data);
        self
    }

    fn with_caller(mut self: VMBuilder, address: Address) -> VMBuilder {
        self.vm.message.caller = address;
        self
    }

    fn with_calldata(mut self: VMBuilder, calldata: Span<u8>) -> VMBuilder {
        self.vm.message.data = calldata;
        self
    }

    fn with_read_only(mut self: VMBuilder) -> VMBuilder {
        self.vm.message.read_only = true;
        self
    }

    fn with_bytecode(mut self: VMBuilder, bytecode: Span<u8>) -> VMBuilder {
        self.vm.message.code = bytecode;
        self
    }

    fn with_gas_limit(mut self: VMBuilder, gas_limit: u128) -> VMBuilder {
        self.vm.message.gas_limit = gas_limit;
        self
    }

    // fn with_nested_vm(mut self: VMBuilder) -> VMBuilder {
    //     let current_ctx = self.machine.current_ctx.unbox();

    //     // Second Execution Context
    //     let context_id = ExecutionContextType::Call(1);
    //     let mut child_context = preset_message();
    //     child_context.ctx_type = context_id;
    //     child_context.parent_ctx = NullableTrait::new(current_ctx);
    //     let mut call_ctx = child_context.call_ctx();
    //     call_ctx.caller = other_address();
    //     child_context.call_ctx = BoxTrait::new(call_ctx);
    //     self.machine.current_ctx = BoxTrait::new(child_context);
    //     self
    // }

    fn with_target(mut self: VMBuilder, target: Address) -> VMBuilder {
        self.vm.message.target = target;
        self
    }

    fn build(mut self: VMBuilder) -> VM {
        self.vm.valid_jumpdests = AccountTrait::get_jumpdests(self.vm.message.code);
        return self.vm;
    }
}

fn origin() -> EthAddress {
    'origin'.try_into().unwrap()
}

fn caller() -> EthAddress {
    'caller'.try_into().unwrap()
}

fn coinbase() -> EthAddress {
    'coinbase'.try_into().unwrap()
}

fn starknet_address() -> ContractAddress {
    contract_address_const::<'starknet_address'>()
}

fn evm_address() -> EthAddress {
    'evm_address'.try_into().unwrap()
}

fn test_address() -> Address {
    Address { evm: evm_address(), starknet: starknet_address() }
}

fn other_evm_address() -> EthAddress {
    'other_evm_address'.try_into().unwrap()
}

fn other_starknet_address() -> ContractAddress {
    contract_address_const::<'other_starknet_address'>()
}

fn other_address() -> Address {
    Address { evm: other_evm_address(), starknet: other_starknet_address() }
}

fn storage_base_address() -> StorageBaseAddress {
    storage_base_address_from_felt252('storage_base_address')
}

fn zero_address() -> ContractAddress {
    contract_address_const::<0x00>()
}

fn callvalue() -> u256 {
    123456789
}

fn native_token() -> ContractAddress {
    contract_address_const::<'native_token'>()
}

fn chain_id() -> u128 {
    'KKRT'.try_into().unwrap()
}

fn kakarot_address() -> ContractAddress {
    contract_address_const::<'kakarot'>()
}

fn sequencer_evm_address() -> EthAddress {
    'sequencer'.try_into().unwrap()
}

fn eoa_address() -> EthAddress {
    let evm_address: EthAddress = 0xe0a.try_into().unwrap();
    evm_address
}

fn tx_gas_limit() -> u128 {
    15000000000
}

fn gas_price() -> u128 {
    32
}

fn value() -> u256 {
    0xffffffffffffffffffffffffffffffff
}

fn ca_address() -> EthAddress {
    let evm_address: EthAddress = 0xca.try_into().unwrap();
    evm_address
}

fn preset_message() -> Message {
    let code: Span<u8> = [0x00].span();
    let data: Span<u8> = [4, 5, 6].span();
    let value: u256 = callvalue();
    let caller = Address {
        evm: origin(),
        starknet: utils::helpers::compute_starknet_address(
            get_contract_address(),
            origin(),
            UninitializedAccount::TEST_CLASS_HASH.try_into().unwrap()
        )
    };
    let read_only = false;
    let tx_gas_limit = tx_gas_limit();
    let target = test_address();

    Message {
        target,
        caller,
        data,
        value,
        gas_limit: tx_gas_limit,
        read_only,
        code,
        should_transfer_value: true,
        depth: 0,
        accessed_addresses: Default::default(),
        accessed_storage_keys: Default::default(),
    }
}

fn preset_environment() -> Environment {
    let block_info = starknet::get_block_info().unbox();
    Environment {
        origin: origin(),
        gas_price: gas_price(),
        chain_id: chain_id(),
        prevrandao: 0,
        block_number: block_info.block_number,
        block_timestamp: block_info.block_timestamp,
        block_gas_limit: constants::BLOCK_GAS_LIMIT,
        coinbase: coinbase(),
        base_fee: 0,
        state: Default::default(),
    }
}

fn preset_vm() -> VM {
    let message = preset_message();
    let environment = preset_environment();
    let return_data = [1, 2, 3].span();
    VM {
        stack: Default::default(),
        memory: Default::default(),
        pc: 0,
        valid_jumpdests: AccountTrait::get_jumpdests(message.code),
        return_data,
        env: environment,
        message,
        gas_left: message.gas_limit,
        running: true,
        error: false,
        accessed_addresses: Default::default(),
        accessed_storage_keys: Default::default(),
        gas_refund: 0,
    }
}


/// Initializes the contract account by setting the bytecode, the storage
/// and incrementing the nonce to 1.
fn initialize_contract_account(
    eth_address: EthAddress, bytecode: Span<u8>, storage: Span<(u256, u256)>
) -> Result<Address, EVMError> {
    let mut ca_address = deploy_contract_account(eth_address, bytecode);
    // Set the storage of the contract account
    let account = Account {
        address: ca_address, code: [
            0xab, 0xcd, 0xef
        ].span(), nonce: 1, balance: 0, selfdestruct: false, is_created: false,
    };

    let mut i = 0;
    while i != storage.len() {
        let (key, value) = storage.get(i).unwrap().unbox();
        IAccountDispatcher { contract_address: account.starknet_address() }
            .write_storage(*key, *value);
        i += 1;
    };

    Result::Ok(ca_address)
}
