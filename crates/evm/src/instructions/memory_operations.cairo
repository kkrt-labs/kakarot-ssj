//! Stack Memory Storage and Flow Operations.

use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait
};
use evm::errors::EVMError;
use evm::stack::StackTrait;


#[generate_trait]
impl MemoryOperation of MemoryOperationTrait {
    /// MLOAD operation.
    /// Load word from memory and push to stack.
    fn exec_mload(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x52 - MSTORE operation.
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#52?fork=shanghai
    fn exec_mstore(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x58 - PC operation
    /// Get the value of the program counter prior to the increment.
    /// # Specification: https://www.evm.codes/#58?fork=shanghai
    fn exec_pc(ref self: ExecutionContext) -> Result<(), EVMError> {
        let pc = self.program_counter.into();
        self.stack.push(pc)
    }

    /// 0x59 - MSIZE operation.
    /// Get the value of memory size.
    /// # Specification: https://www.evm.codes/#59?fork=shanghai
    fn exec_msize(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x56 - JUMP operation
    /// The JUMP instruction changes the pc counter. 
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#56?fork=shanghai
    fn exec_jump(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x57 - JUMPI operation.
    /// Change the pc counter under a provided certain condition.
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#57?fork=shanghai
    fn exec_jumpi(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x5b - JUMPDEST operation
    /// Serves as a check that JUMP or JUMPI was executed correctly.
    /// # Specification: https://www.evm.codes/#5b?fork=shanghai
    fn exec_jumpdest(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x50 - POP operation.
    /// Pops the first item on the stack (top of the stack).
    /// # Specification: https://www.evm.codes/#50?fork=shanghai
    fn exec_pop(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x53 - MSTORE8 operation.
    /// Save single byte to memory
    /// # Specification: https://www.evm.codes/#53?fork=shanghai
    fn exec_mstore8(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x55 - SSTORE operation
    /// Save 32-byte word to storage.
    /// # Specification: https://www.evm.codes/#55?fork=shanghai
    fn exec_sstore(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x54 - SLOAD operation
    /// Load from storage.
    /// # Specification: https://www.evm.codes/#54?fork=shanghai
    fn exec_sload(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }

    /// 0x5A - GAS operation
    /// Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
    /// # Specification: https://www.evm.codes/#5a?fork=shanghai
    fn exec_gas(ref self: ExecutionContext) -> Result<(), EVMError> {
        Result::Ok(())
    }
}
