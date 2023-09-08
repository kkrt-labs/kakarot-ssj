//! Stack Memory Storage and Flow Operations.
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait
};
use evm::errors::EVMError;
use evm::stack::StackTrait;
use evm::memory::MemoryTrait;
use result::ResultTrait;
use evm::helpers::U256IntoResultU32;

#[generate_trait]
impl MemoryOperation of MemoryOperationTrait {
    /// MLOAD operation.
    /// Load word from memory and push to stack.
    fn exec_mload(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop()?;
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into(popped)?;
        let (result, _) = self.memory.load(offset);
        self.stack.push(result)
    }

    /// 0x52 - MSTORE operation.
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#52?fork=shanghai
    fn exec_mstore(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let value: u256 = self.stack.pop()?;

        self.memory.store(value, offset);
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
        self.stack.pop()?;
        // self.stack.pop() returns a Result<u256, EVMError> so we cannot simply return its result
        Result::Ok(())
    }

    /// 0x53 - MSTORE8 operation.
    /// Save single byte to memory
    /// # Specification: https://www.evm.codes/#53?fork=shanghai
    fn exec_mstore8(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into((*popped[0]))?;
        let value: u8 = (*popped.at(1).low & 0xFF).try_into().unwrap();
        let values = array![value].span();
        self.memory.store_n(values, offset);

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
