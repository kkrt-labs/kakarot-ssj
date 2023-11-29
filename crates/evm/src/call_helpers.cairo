use evm::interpreter::EVMTrait;
//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use cmp::min;
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;

use evm::context::{ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextTrait};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::{Transfer, Address};
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
    fn prepare_call(
        ref self: ExecutionContext, call_type: @CallType
    ) -> Result<CallArgs, EVMError> {
        let gas = self.stack.pop_u128()?;

        let code_address = self.stack.pop_eth_address()?;
        let to = match call_type {
            CallType::Call => code_address,
            CallType::DelegateCall => self.address().evm,
            CallType::CallCode => self.address().evm,
            CallType::StaticCall => code_address
        };

        let kakarot_core = KakarotCore::unsafe_new_contract_state();

        let code_address = Address {
            evm: code_address, starknet: kakarot_core.compute_starknet_address(code_address)
        };

        let to = Address { evm: to, starknet: kakarot_core.compute_starknet_address(to) };

        let (value, caller, should_transfer, read_only) = match call_type {
            CallType::Call => (self.stack.pop()?, self.address(), true, self.read_only()),
            CallType::DelegateCall => (
                self.value(), self.call_ctx().caller, false, self.read_only()
            ),
            CallType::CallCode => (self.stack.pop()?, self.address(), false, self.read_only()),
            CallType::StaticCall => (0, self.address(), false, true),
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
    fn generic_call(ref self: ExecutionContext, call_args: CallArgs,) -> Result<(), EVMError> {
        // check if depth is too high

        // Case 2: `to` address is not a precompile
        // We enter the standard flow
        let bytecode = self.state.get_account(call_args.code_address.evm).code;

        let call_ctx = CallContextTrait::new(
            call_args.caller,
            self.origin(),
            bytecode,
            call_args.calldata,
            call_args.value,
            call_args.read_only,
            call_args.gas,
            self.gas_price(),
            call_args.should_transfer,
        );

        let mut child_ctx = ExecutionContextTrait::new(
            call_args.to,
            call_ctx,
            depth: self.depth()
                + 1, // TODO(elias): deep copy and pass the state down to the child context
            state: Default::default(),
        );

        let result = child_ctx.process_message();
        let success = match result.status {
            Status::Active => {
                // TODO: The Execution Result should not share the Status type since it cannot be active
                // This INVARIANT should be handled by the type system
                panic!(
                    "INVARIANT: Status of the Execution Context should not be Active in finalize logic"
                )
            },
            Status::Stopped => 1,
            Status::Reverted => 0,
        };
        self.stack.push(success)?;

        // Get the min between len(return_data) and call_ctx.ret_size.
        let return_data_len = min(result.return_data.len(), call_args.ret_size);

        let return_data = result.return_data.slice(0, return_data_len);
        // TODO: Check if need to padd the memory with zeroes if result.return_data.len() < call_ctx.ret_size and memory is not empty at
        // offset call_args.ret_offset + result.return_data.len()
        self.memory.store_n(return_data, call_args.ret_offset);

        Result::Ok(())
    }
}

/// Check whether a `to` address for a call-family opcode is a precompile.
fn is_precompile(to: EthAddress) -> bool {
    let to: felt252 = to.into();
    if to.into() < 0x10_u256 {
        return true;
    }
    false
}
