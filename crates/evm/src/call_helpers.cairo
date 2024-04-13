use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;
//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use core::cmp::min;

use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::gas;
use evm::interpreter::EVMTrait;
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Transfer, Address, Message};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use starknet::{EthAddress, get_contract_address};
use utils::constants;
use utils::helpers::compute_starknet_address;
use utils::set::SetTrait;
use utils::traits::{BoolIntoNumeric, U256TryIntoResult};

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
#[derive(Drop, PartialEq)]
struct CallArgs {
    caller: Address,
    code_address: Address,
    to: Address,
    gas: u128,
    value: u256,
    calldata: Span<u8>,
    ret_offset: usize,
    ret_size: usize,
    read_only: bool,
    should_transfer: bool,
    max_memory_size: usize,
}

#[derive(Drop)]
enum CallType {
    Call,
    DelegateCall,
    CallCode,
    StaticCall,
}

#[generate_trait]
impl CallHelpersImpl of CallHelpers {
    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn generic_call(
        ref self: VM,
        gas: u128,
        value: u256,
        caller: EthAddress,
        to: EthAddress,
        code_address: EthAddress,
        should_transfer_value: bool,
        is_staticcall: bool,
        args_offset: usize,
        args_size: usize,
        ret_offset: usize,
        ret_size: usize
    ) -> Result<(), EVMError> {
        self.return_data = Default::default().span();
        if self.message().depth >= constants::STACK_MAX_DEPTH {
            self.gas_left += gas;
            return self.stack.push(0);
        }

        let mut calldata = Default::default();
        self.memory.load_n(args_size, ref calldata, args_offset);

        // We enter the standard flow
        let code = self.env.state.get_account(code_address).code;
        let read_only = is_staticcall || self.message.read_only;

        let kakarot_core = KakarotCore::unsafe_new_contract_state();
        let to = Address { evm: to, starknet: kakarot_core.compute_starknet_address(to) };
        let caller = Address {
            evm: caller, starknet: kakarot_core.compute_starknet_address(caller)
        };

        let message = Message {
            caller,
            target: to,
            gas_limit: gas,
            data: calldata.span(),
            code,
            value: value,
            should_transfer_value: should_transfer_value,
            depth: self.message().depth + 1,
            read_only: read_only,
            accessed_addresses: self.accessed_addresses.clone().spanset(),
            accessed_storage_keys: self.accessed_storage_keys.clone().spanset(),
        };

        let result = EVMTrait::process_message(message, ref self.env);
        self.merge_child(@result);

        self.return_data = result.return_data;
        if result.success {
            self.stack.push(1)?;
        } else {
            self.stack.push(0)?;
        }

        // Get the min between len(return_data) and call_ctx.ret_size.
        let actual_returndata_len = min(result.return_data.len(), ret_size);

        let actual_return_data = result.return_data.slice(0, actual_returndata_len);
        // TODO: Check if need to pad the memory with zeroes if result.return_data.len() < call_ctx.ret_size and memory is not empty at
        // offset call_args.ret_offset + result.return_data.len()
        self.memory.store_n(actual_return_data, ret_offset);

        Result::Ok(())
    }
}

/// Check whether an address for a call-family opcode is a precompile.
fn is_precompile(self: EthAddress) -> bool {
    let self: felt252 = self.into();
    return (self != 0 && self.into() < 10_u256);
}
