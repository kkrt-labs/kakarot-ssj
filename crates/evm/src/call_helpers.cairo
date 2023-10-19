use evm::context::{ExecutionContext, CallContext, CallContextTrait, ExecutionContextTrait};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use starknet::{EthAddress};
use utils::traits::{BoolIntoNumeric, U256TryIntoResult};

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
struct CallArgs {
    to: EthAddress,
    value: u256,
    calldata: Span<u8>
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

        let argsOffset = self.stack.pop_usize()?;
        let argsSize = self.stack.pop_usize()?;

        let mut calldata = array![];
        self.memory.load_n(argsSize, ref calldata, argsOffset);

        // TODO: handle more detailed gas logic
        // gas stipend,
        // dynamic gas,
        // reference: https://github.com/ethereum/execution-specs/blob/master/src/ethereum/berlin/vm/instructions/system.py#L327
        if gas > self.gas_limit() {
            return Result::Err(EVMError::InsufficientGas(CALL_GAS_GT_GAS_LIMIT));
        }

        Result::Ok(CallArgs { to, value, calldata: calldata.span() })
    }

    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn init_sub_ctx(ref self: Machine, with_value: bool, read_only: bool) -> Result<(), EVMError> {
        let call_args = self.prepare_call(with_value)?;

        // Case 1: `to` address is a precompile
        // Handle precompile logic
        if is_precompile(call_args.to) {
            return Result::Err(EVMError::NotImplemented);
        }

        // Case 2: `to` address is not a precompile
        // We enter the standard flow
        // TODO(elias): be able to fetch bytecode
        let bytecode = array![].span();
        // The caller in the subcontext is the current context's current address
        let caller = self.evm_address();

        // The read_only parameter is:
        // True if read_only == true, else current_ctx.read_only,
        // Example: if a staticcall performs a subcall
        let read_only = read_only | self.read_only();

        // TODO: handle gas accurately
        let call_ctx = CallContextTrait::new(
            caller,
            bytecode,
            call_args.calldata,
            call_args.value,
            read_only,
            self.gas_limit(),
            self.gas_price()
        );

        let parent_ctx = NullableTrait::new(self.current_ctx.unbox());
        let child_ctx = ExecutionContextTrait::new(
            self.ctx_count, call_args.to, call_ctx, parent_ctx, array![].span()
        );

        // Machine logic
        // Increment the total context count
        self.ctx_count += 1;
        // Set the current context to be the newly created child context
        self.current_ctx = BoxTrait::new(child_ctx);

        Result::Ok(())
    }
}

/// Check whether a `to` address for a call-family opcode is a precompile
/// Since range check is expensive in Cairo, we proceed with checking equality
fn is_precompile(to: EthAddress) -> bool {
    if to.into() == 0x01_felt252 {
        return true;
    }
    if to.into() == 0x02_felt252 {
        return true;
    }
    if to.into() == 0x03_felt252 {
        return true;
    }
    if to.into() == 0x04_felt252 {
        return true;
    }
    if to.into() == 0x05_felt252 {
        return true;
    }
    if to.into() == 0x06_felt252 {
        return true;
    }
    if to.into() == 0x07_felt252 {
        return true;
    }
    if to.into() == 0x08_felt252 {
        return true;
    }
    if to.into() == 0x09_felt252 {
        return true;
    }
    false
}
