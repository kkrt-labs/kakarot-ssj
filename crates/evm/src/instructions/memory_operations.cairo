//! Stack Memory Storage and Flow Operations.
use evm::errors::{EVMError, INVALID_DESTINATION, READ_SYSCALL_FAILED, WRITE_IN_STATIC_CONTEXT};
use evm::gas;
use evm::memory::MemoryTrait;
use evm::model::vm::{VM, VMTrait};
use evm::stack::StackTrait;
use evm::state::{StateTrait, compute_state_key};
use hash::{HashStateTrait, HashStateExTrait};
use poseidon::PoseidonTrait;
use starknet::{storage_base_address_from_felt252, Store};
use utils::helpers::U256Trait;

#[generate_trait]
impl MemoryOperation of MemoryOperationTrait {
    /// 0x50 - POP operation.
    /// Pops the first item on the stack (top of the stack).
    /// # Specification: https://www.evm.codes/#50?fork=shanghai
    fn exec_pop(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        // self.stack.pop() returns a Result<u256, EVMError> so we cannot simply return its result
        self.stack.pop()?;
        Result::Ok(())
    }

    /// MLOAD operation.
    /// Load word from memory and push to stack.
    fn exec_mload(ref self: VM) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;

        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), offset + 32);
        self.charge_gas(gas::VERYLOW + expand_memory_cost)?;

        let result = self.memory.load(offset);
        self.stack.push(result)
    }

    /// 0x52 - MSTORE operation.
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#52?fork=shanghai
    fn exec_mstore(ref self: VM) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;
        let value: u256 = self.stack.pop()?;
        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), offset + 32);
        self.charge_gas(gas::VERYLOW + expand_memory_cost)?;

        self.memory.store(value, offset);
        Result::Ok(())
    }

    /// 0x53 - MSTORE8 operation.
    /// Save single byte to memory
    /// # Specification: https://www.evm.codes/#53?fork=shanghai
    fn exec_mstore8(ref self: VM) -> Result<(), EVMError> {
        let offset = self.stack.pop_usize()?;
        let value = self.stack.pop()?;
        let value: u8 = (value.low & 0xFF).try_into().unwrap();

        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), offset + 1);
        self.charge_gas(gas::VERYLOW + expand_memory_cost)?;

        self.memory.store_byte(value, offset);

        Result::Ok(())
    }


    /// 0x54 - SLOAD operation
    /// Load from storage.
    /// # Specification: https://www.evm.codes/#54?fork=shanghai
    fn exec_sload(ref self: VM) -> Result<(), EVMError> {
        // TODO: Add Warm / Cold storage costs
        self.charge_gas(gas::WARM_ACCESS_COST)?;

        let key = self.stack.pop()?;
        let evm_address = self.message().target.evm;

        let value = self.env.state.read_state(evm_address, key)?;
        self.stack.push(value)
    }


    /// 0x55 - SSTORE operation
    /// Save 32-byte word to storage.
    /// # Specification: https://www.evm.codes/#55?fork=shanghai
    fn exec_sstore(ref self: VM) -> Result<(), EVMError> {
        if self.message().read_only {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }

        // TODO: Add Warm / Cold storage costs
        self.charge_gas(gas::WARM_ACCESS_COST)?;

        let key = self.stack.pop()?;
        let value = self.stack.pop()?;
        let evm_address = self.message().target.evm;
        self.env.state.write_state(:evm_address, :key, :value);
        Result::Ok(())
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
    fn exec_jump(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::MID)?;

        let index = self.stack.pop_usize()?;

        match self.message().code.get(index) {
            Option::Some(opcode) => {
                if !self.is_valid_jump(index) {
                    return Result::Err(EVMError::JumpError(INVALID_DESTINATION));
                }
            },
            Option::None => { return Result::Err(EVMError::JumpError(INVALID_DESTINATION)); }
        }
        self.set_pc(index);
        Result::Ok(())
    }

    /// 0x57 - JUMPI operation.
    /// Change the pc counter under a provided certain condition.
    /// The new pc target has to be a JUMPDEST opcode.
    /// # Specification: https://www.evm.codes/#57?fork=shanghai
    fn exec_jumpi(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::HIGH)?;

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

    /// 0x58 - PC operation
    /// Get the value of the program counter prior to the increment.
    /// # Specification: https://www.evm.codes/#58?fork=shanghai
    fn exec_pc(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let pc = self.pc().into();
        self.stack.push(pc)
    }

    /// 0x59 - MSIZE operation.
    /// Get the value of memory size.
    /// # Specification: https://www.evm.codes/#59?fork=shanghai
    fn exec_msize(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let msize: u256 = self.memory.size().into();
        self.stack.push(msize)
    }


    /// 0x5A - GAS operation
    /// Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
    /// # Specification: https://www.evm.codes/#5a?fork=shanghai
    fn exec_gas(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;
        self.stack.push((self.message().gas_limit - self.gas_used()).into())
    }


    /// 0x5b - JUMPDEST operation
    /// Serves as a check that JUMP or JUMPI was executed correctly.
    /// # Specification: https://www.evm.codes/#5b?fork=shanghai
    ///
    /// This doesn't have any affect on execution state, so we don't have
    /// to do anything here. It's a NO-OP.
    fn exec_jumpdest(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::JUMPDEST)?;
        Result::Ok(())
    }
}
