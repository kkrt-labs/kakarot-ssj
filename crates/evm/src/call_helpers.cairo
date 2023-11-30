use evm::interpreter::EVMTrait;
//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use cmp::min;
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;

use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::{Transfer, Address, Message};
use evm::model::vm::{VM, VMTrait};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use starknet::{EthAddress, get_contract_address};
use utils::helpers::compute_starknet_address;
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
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CALL family of opcodes.
    fn prepare_call(ref self: VM, call_type: @CallType) -> Result<CallArgs, EVMError> {
        let gas = self.stack.pop_u128()?;

        let code_address = self.stack.pop_eth_address()?;
        let to = match call_type {
            CallType::Call => code_address,
            CallType::DelegateCall => self.message().target.evm,
            CallType::CallCode => self.message().target.evm,
            CallType::StaticCall => code_address
        };

        let kakarot_core = KakarotCore::unsafe_new_contract_state();

        let code_address = Address {
            evm: code_address, starknet: kakarot_core.compute_starknet_address(code_address)
        };

        let to = Address { evm: to, starknet: kakarot_core.compute_starknet_address(to) };

        let (value, caller, should_transfer, read_only) = match call_type {
            CallType::Call => (
                self.stack.pop()?, self.message().target, true, self.message().read_only
            ),
            CallType::DelegateCall => (
                self.message().value, self.message().caller, false, self.message().read_only
            ),
            CallType::CallCode => (
                self.stack.pop()?, self.message().target, false, self.message().read_only
            ),
            CallType::StaticCall => (0, self.message().target, false, true),
        };

        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;

        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let mut calldata = Default::default();
        self.memory.load_n(args_size, ref calldata, args_offset);

        Result::Ok(
            CallArgs {
                caller,
                code_address,
                to,
                value,
                gas,
                calldata: calldata.span(),
                ret_offset,
                ret_size,
                should_transfer,
                read_only,
            }
        )
    }

    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn generic_call(ref self: VM, call_args: CallArgs) -> Result<(), EVMError> {
        // check if depth is too high

        // Case 2: `to` address is not a precompile
        // We enter the standard flow
        let code = self.env.state.get_account(call_args.code_address.evm).code;
        self.return_data = Default::default().span();
        let message = Message {
            caller: call_args.caller,
            target: call_args.to,
            gas_limit: call_args.gas,
            value: call_args.value,
            read_only: call_args.read_only,
            should_transfer_value: call_args.should_transfer,
            data: call_args.calldata,
            code,
            depth: self.message().depth + 1
        };

        let state_snapshot = self.env.state;
        //TODO perform deep copy of the state
        self.env.state = Default::default();
        let result = EVMTrait::process_message(message, ref self.env);

        self.return_data = result.return_data;
        self.gas_used += result.gas_used;
        if result.success {
            self.stack.push(1)?;
        } else {
            // The `process_message` function has mutated the environment state.
            // Revert state changes using the old snapshot as execution failed.
            self.env.state = state_snapshot;
            self.stack.push(0)?;
        }

        // Get the min between len(return_data) and call_ctx.ret_size.
        let actual_returndata_len = min(result.return_data.len(), call_args.ret_size);

        let actual_return_data = result.return_data.slice(0, actual_returndata_len);
        // TODO: Check if need to padd the memory with zeroes if result.return_data.len() < call_ctx.ret_size and memory is not empty at
        // offset call_args.ret_offset + result.return_data.len()
        self.memory.store_n(actual_return_data, call_args.ret_offset);

        Result::Ok(())
    }
}

/// Check whether an address for a call-family opcode is a precompile.
fn is_precompile(self: EthAddress) -> bool {
    let self: felt252 = self.into();
    if self.into() < 0x10_u256 {
        return true;
    }
    false
}
