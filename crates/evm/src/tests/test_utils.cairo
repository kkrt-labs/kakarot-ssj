use contracts::tests::test_utils::{deploy_contract_account};
use contracts::uninitialized_account::UninitializedAccount;
use core::traits::TryInto;
use evm::errors::{EVMError};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Message, Environment, ContractAccountTrait, Address, Account, AccountType};
use evm::state::State;
use evm::{stack::{Stack, StackTrait}, memory::{Memory, MemoryTrait}};
use nullable::{match_nullable, FromNullableResult};
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
        VMBuilder { vm: Default::default() }
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

    fn build(self: VMBuilder) -> VM {
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


fn deploy_fee() -> u128 {
    0x10
}

fn native_token() -> ContractAddress {
    contract_address_const::<'native_token'>()
}

fn chain_id() -> u128 {
    'CHAIN_ID'.try_into().unwrap()
}

fn kakarot_address() -> ContractAddress {
    contract_address_const::<'kakarot'>()
}

fn eoa_address() -> EthAddress {
    let evm_address: EthAddress = 0xe0a.try_into().unwrap();
    evm_address
}

fn tx_gas_limit() -> u128 {
    0x100000000000000000
}

fn gas_price() -> u128 {
    0xf00000000000000000
}

fn value() -> u256 {
    0xffffffffffffffffffffffffffffffff
}

fn ca_address() -> EthAddress {
    let evm_address: EthAddress = 0xca.try_into().unwrap();
    evm_address
}

fn preset_message() -> Message {
    let code: Span<u8> = array![0x00].span();
    let data: Span<u8> = array![4, 5, 6].span();
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
        state: Default::default(),
    }
}

fn preset_vm() -> VM {
    let message = preset_message();
    let environment = preset_environment();
    let return_data = array![1, 2, 3].span();
    VM {
        stack: Default::default(),
        memory: Default::default(),
        pc: 0,
        valid_jumpdests: Default::default().span(),
        return_data,
        env: environment,
        message,
        gas_used: 0,
        running: true,
        error: false
    }
}

// // Simulate return of subcontext where
// /// 1. Set `return_data` field of parent context
// /// 2. make `parent_ctx` of `current_ctx` the current ctx
// fn return_from_subcontext(ref self: Machine, return_data: Span<u8>) {
//     let current_ctx = self.current_ctx.unbox();
//     let mut parent_ctx = current_ctx.parent_ctx.deref();
//     parent_ctx.return_data = return_data;
//     self.current_ctx = BoxTrait::new(parent_ctx);
// }

// /// Returns the `return_data` field of the parent_ctx of the current_ctx.
// fn parent_ctx_return_data(ref self: Machine) -> Span<u8> {
//     let mut current_ctx = self.current_ctx.unbox();
//     let maybe_parent_ctx = current_ctx.parent_ctx;
//     let value = match match_nullable(maybe_parent_ctx) {
//         // Due to ownership mechanism, both branches need to explicitly re-bind the parent_ctx.
//         FromNullableResult::Null => {
//             current_ctx.parent_ctx = Default::default();
//             Default::default().span()
//         },
//         FromNullableResult::NotNull(parent_ctx) => {
//             let mut parent_ctx = parent_ctx.unbox();
//             let value = parent_ctx.return_data();
//             current_ctx.parent_ctx = NullableTrait::new(parent_ctx);
//             value
//         }
//     };
//     self.current_ctx = BoxTrait::new(current_ctx);
//     value
// }

/// Initializes the contract account by setting the bytecode, the storage
/// and incrementing the nonce to 1.
fn initialize_contract_account(
    eth_address: EthAddress, bytecode: Span<u8>, storage: Span<(u256, u256)>
) -> Result<Address, EVMError> {
    let mut ca_address = deploy_contract_account(eth_address, bytecode);
    // Set the storage of the contract account
    let account = Account {
        account_type: AccountType::ContractAccount,
        address: ca_address,
        code: array![0xab, 0xcd, 0xef].span(),
        nonce: 1,
        balance: 0,
        selfdestruct: false
    };
    let mut i = 0;
    loop {
        if i == storage.len() {
            break;
        };
        let (key, value) = storage.get(i).unwrap().unbox();
        account.store_storage(*key, *value).expect('failed init CA');
        i += 1;
    };

    Result::Ok(ca_address)
}
