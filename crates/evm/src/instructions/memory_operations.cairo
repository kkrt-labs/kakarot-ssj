//! Stack Memory Storage and Flow Operations.
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait
};
use evm::errors::{EVMError, INVALID_DESTINATION};
use evm::stack::StackTrait;
use evm::memory::MemoryTrait;
use evm::helpers::U256IntoResultU32;

#[generate_trait]
impl MemoryOperation of MemoryOperationTrait {
    /// MLOAD operation.
    /// Load word from memory and push to stack.
    fn exec_mload(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;
        let result = self.memory.load(offset);
        self.stack.push(result)
    }

    /// 0x52 - MSTORE operation.
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#52?fork=shanghai
    fn exec_mstore(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;
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
        let msize: u256 = self.memory.size().into();
        self.stack.push(msize)
    }

    /// 0x56 - JUMP operation
    /// The JUMP instruction changes the pc counter.
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#56?fork=shanghai
    ///
    ///  Valid jump destinations are defined as follows:
    ///     * The jump destination is less than the length of the code.
    ///     * The jump destination should have the `JUMPDEST` opcode (0x5B).
    ///     * The jump destination shouldn't be part of the data corresponding to
    ///       `PUSH-N` opcodes.
    ///
    /// Note: Jump destinations are 0-indexed.
    fn exec_jump(ref self: ExecutionContext) -> Result<(), EVMError> {
        let index = self.stack.pop_usize()?;

        // TODO: Currently this doesn't check that byte is actually `JUMPDEST`
        // and not `0x5B` that is a part of PUSHN instruction
        // 
        // That can be done by storing all valid jump locations during contract deployment
        // which would also simplify the logic because we would be just checking if idx is
        // present in that list
        //
        // Check if idx in bytecode points to `JUMPDEST` opcode
        match self.call_context().bytecode.get(index) {
            Option::Some(opcode) => {
                if *opcode.unbox() != 0x5B {
                    return Result::Err(EVMError::JumpError(INVALID_DESTINATION));
                }
            },
            Option::None => {
                return Result::Err(EVMError::JumpError(INVALID_DESTINATION));
            }
        }
        self.program_counter = index;
        Result::Ok(())
    }

    /// 0x57 - JUMPI operation.
    /// Change the pc counter under a provided certain condition.
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#57?fork=shanghai
    fn exec_jumpi(ref self: ExecutionContext) -> Result<(), EVMError> {
        // Peek the value so we don't need to push it back again incase we want to call `exec_jump`
        let b = self.stack.peek_at(1)?;

        if b != 0x0 {
            self.exec_jump()?;
            // counter would have been already popped by `exec_jump`
            // so we just remove `b`
            self.stack.pop()?;
        } else {
            // remove both `value` and `b`
            self.stack.pop()?;
            self.stack.pop()?;
        }

        Result::Ok(())
    }

    /// 0x5b - JUMPDEST operation
    /// Serves as a check that JUMP or JUMPI was executed correctly.
    /// # Specification: https://www.evm.codes/#5b?fork=shanghai
    /// 
    /// This doesn't have any affect on execution state, so we don't have
    /// to do anything here. It's a NO-OP.
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
        let offset = self.stack.pop_usize()?;
        let value = self.stack.pop()?;
        let value: u8 = (value.low & 0xFF).try_into().unwrap();
        self.memory.store_byte(value, offset);

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
