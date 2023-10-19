use cmp::min;
use evm::bytecode::bytecode;
use evm::context::{
    ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextId,
    ExecutionContextTrait
};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
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
    output_offset: usize,
    output_size: usize,
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
            0
        };

        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;

        let output_offset = self.stack.pop_usize()?;
        let output_size = self.stack.pop_usize()?;

        let mut calldata = Default::default();
        self.memory.load_n(args_size, ref calldata, args_offset);

        Result::Ok(
            CallArgs { to, value, gas, calldata: calldata.span(), output_offset, output_size }
        )
    }

    /// Initializes and enters into a new call sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn init_sub_call_ctx(
        ref self: Machine, call_args: CallArgs, read_only: bool
    ) -> Result<(), EVMError> {
        // Case 1: `to` address is a precompile
        // Handle precompile logic
        if is_precompile(call_args.to) {
            panic_with_felt252('not implemented');
        }

        // Case 2: `to` address is not a precompile
        // We enter the standard flow
        let bytecode = bytecode(call_args.to)?;
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
            call_args.output_offset,
            call_args.output_size
        );

        let parent_ctx = NullableTrait::new(self.current_ctx.unbox());
        let child_ctx = ExecutionContextTrait::new(
            ExecutionContextId::Call(self.ctx_count),
            call_args.to,
            call_ctx,
            parent_ctx,
            Default::default().span()
        );

        // Machine logic
        // Increment the total context count
        self.ctx_count += 1;
        // Set the current context to be the newly created child context
        self.current_ctx = BoxTrait::new(child_ctx);

        Result::Ok(())
    }

    /// Finalize the calling context by:
    /// - Pushing the execution status to the Stack
    /// - Set the return data of the parent context
    /// - Store the return data in Memory
    /// - Return to parent context and decrease the ctx_count.
    fn finalize_calling_context(ref self: Machine) -> () {
        // Put the status of the call on the stack.
        let status = self.status();
        let status = match status {
            Status::Active => 1,
            Status::Stopped => 1,
            Status::Reverted => 0,
        };
        self.stack.push(status);

        // Set the return_data of the parent context if a call, or of the
        // root.
        let ctx_output = self.output();
        self.set_return_data(ctx_output);

        // Get the min between len(output) and call_ctx.output_size.
        let call_ctx = self.call_ctx();
        let return_data_len = min(ctx_output.len(), call_ctx.output_size);

        // Save the return data in memory.
        let return_data = ctx_output.slice(0, return_data_len);
        self.memory.store_n(return_data, call_ctx.output_offset);

        // Return from the current sub ctx by setting the execution context
        // to the parent context.
        self.return_to_parent_ctx();

        // Machine logic
        // Decrement the total context count
        self.ctx_count += 1;
        return ();
    }
}

/// Check whether a `to` address for a call-family opcode is a precompile
/// Since range check is expensive in Cairo, we proceed with checking equality
fn is_precompile(to: EthAddress) -> bool {
    let to: felt252 = to.into();
    if to.into() <= 0x9_u256 {
        return true;
    }
    false
}
