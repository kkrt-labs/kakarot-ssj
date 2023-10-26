//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use cmp::min;
use evm::context::{
    ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextType,
    ExecutionContextTrait
};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::AccountTrait;
use evm::stack::StackTrait;
use starknet::{EthAddress};
use utils::traits::{BoolIntoNumeric, U256TryIntoResult};

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
#[derive(Drop)]
struct CallArgs {
    to: EthAddress,
    gas: u128,
    value: u256,
    calldata: Span<u8>,
    ret_offset: usize,
    ret_size: usize,
}

#[generate_trait]
impl MachineCallHelpersImpl of MachineCallHelpers {
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CALL family of opcodes.
    fn prepare_call(ref self: Machine, with_value: bool) -> Result<CallArgs, EVMError> {
        // For CALL and CALLCODE, we pop 5 items off of the stack
        // For STATICCALL and DELEGATECALL, we pop 4 items off of the stack
        // The difference being the "value" parameter in CALL and CALLCODE.
        let gas = self.stack.pop_u128()?;
        let to = self.stack.pop_eth_address()?;

        // CALL and CALLCODE expect value to be on the stack
        // for STATICCALL and DELEGATECALL, the value is the calling call context's value
        let value = if with_value {
            self.stack.pop()?
        } else {
            self.value()
        };

        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;

        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let mut calldata = Default::default();
        self.memory.load_n(args_size, ref calldata, args_offset);

        Result::Ok(CallArgs { to, value, gas, calldata: calldata.span(), ret_offset, ret_size })
    }

    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn init_sub_ctx(
        ref self: Machine, call_args: CallArgs, read_only: bool
    ) -> Result<(), EVMError> {
        // Case 1: `to` address is a precompile
        // Handle precompile logic
        if is_precompile(call_args.to) {
            panic_with_felt252('not implemented');
        }

        // Case 2: `to` address is not a precompile
        // We enter the standard flow
        let maybe_account = AccountTrait::account_type_at(call_args.to)?;
        let bytecode = match maybe_account {
            Option::Some(acc) => acc.bytecode()?,
            Option::None => Default::default().span(),
        };

        // The caller in the subcontext is the current context's current address
        let caller = self.evm_address();

        let call_ctx = CallContextTrait::new(
            caller,
            bytecode,
            call_args.calldata,
            call_args.value,
            read_only,
            call_args.gas,
            self.gas_price(),
            call_args.ret_offset,
            call_args.ret_size
        );

        let parent_ctx = NullableTrait::new(self.current_ctx.unbox());
        let child_ctx = ExecutionContextTrait::new(
            ExecutionContextType::Call(self.ctx_count),
            call_args.to,
            call_ctx,
            parent_ctx,
            Default::default().span()
        );

        // Machine logic
        self.ctx_count += 1;
        self.current_ctx = BoxTrait::new(child_ctx);

        Result::Ok(())
    }

    /// Finalize the calling context by:
    /// - Pushing the execution status to the Stack
    /// - Set the return data of the parent context
    /// - Store the return data in Memory
    /// - Return to parent context and decrease the ctx_count.
    fn finalize_calling_context(ref self: Machine) -> Result<(), EVMError> {
        // Put the status of the call on the stack.
        let status = self.status();
        let success = match status {
            Status::Active => {
                return Result::Err(
                    EVMError::InvalidMachineState(ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION)
                );
            },
            Status::Stopped => 1,
            Status::Reverted => 0,
        };
        self.stack.push(success)?;

        // Get the return_data of the parent context.
        let return_data = self.parent_ctx_return_data();

        // Get the min between len(return_data) and call_ctx.ret_size.
        let call_ctx = self.call_ctx();
        let return_data_len = min(return_data.len(), call_ctx.ret_size);

        let return_data = return_data.slice(0, return_data_len);
        self.memory.store_n(return_data, call_ctx.ret_offset);

        // Return from the current sub ctx by setting the execution context
        // to the parent context.
        self.return_to_parent_ctx()
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
