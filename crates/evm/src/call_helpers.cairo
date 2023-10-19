//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use evm::machine::{Machine, MachineCurrentContextTrait};
use starknet::EthAddress;
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT};
use evm::stack::StackTrait;
use evm::memory::MemoryTrait;
use utils::traits::{BoolIntoNumeric, U256TryIntoResult};

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
struct CallArgs {
    evm_address: EthAddress,
    value: u256,
    calldata: Span<u8>
}

///  Prepare the initialization of a new child or so-called sub-context
/// As part of the CALL family of opcodes.
fn prepare_call(ref self: Machine, with_value: bool) -> Result<CallArgs, EVMError> {
    // For CALL and CALLCODE, we pop 5 items off of the stack
    // For STATICCALL and DELEGATECALL, we pop 4 items off of the stack
    // The difference being the "value" parameter in CALL and CALLCODE.
    let gas = self.stack.pop_u128()?;
    let evm_address = self.stack.pop_eth_address()?;

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

    Result::Ok(CallArgs { evm_address, value, calldata: calldata.span() })
}
