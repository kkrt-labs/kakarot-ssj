use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use evm::backend::starknet_backend::fetch_original_storage;
//! Stack Memory Storage and Flow Operations.
use evm::errors::{EVMError, ensure, INVALID_DESTINATION, READ_SYSCALL_FAILED};
use evm::gas;
use evm::memory::MemoryTrait;
use evm::model::account::AccountTrait;
use evm::model::vm::{VM, VMTrait};
use evm::model::{AddressTrait};
use evm::stack::StackTrait;
use evm::state::{StateTrait, compute_state_key};
use starknet::{storage_base_address_from_felt252, Store};
use utils::helpers::U256Trait;
use utils::set::SetTrait;

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

        let memory_expansion = gas::memory_expansion(self.memory.size(), offset + 32);
        self.charge_gas(gas::VERYLOW + memory_expansion.expansion_cost)?;

        let result = self.memory.load(offset);
        self.stack.push(result)
    }

    /// 0x52 - MSTORE operation.
    /// Save word to memory.
    /// # Specification: https://www.evm.codes/#52?fork=shanghai
    fn exec_mstore(ref self: VM) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;
        let value: u256 = self.stack.pop()?;
        let memory_expansion = gas::memory_expansion(self.memory.size(), offset + 32);
        self.charge_gas(gas::VERYLOW + memory_expansion.expansion_cost)?;

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

        let memory_expansion = gas::memory_expansion(self.memory.size(), offset + 1);
        self.charge_gas(gas::VERYLOW + memory_expansion.expansion_cost)?;

        self.memory.store_byte(value, offset);

        Result::Ok(())
    }


    /// 0x54 - SLOAD operation
    /// Load from storage.
    /// # Specification: https://www.evm.codes/#54?fork=shanghai
    fn exec_sload(ref self: VM) -> Result<(), EVMError> {
        let key = self.stack.pop()?;
        let evm_address = self.message().target.evm;

        // GAS
        if self.accessed_storage_keys.contains((evm_address, key)) {
            self.charge_gas(gas::WARM_ACCESS_COST)?;
        } else {
            self.accessed_storage_keys.add((evm_address, key));
            self.charge_gas(gas::COLD_SLOAD_COST)?;
        }

        let value = self.env.state.read_state(evm_address, key);
        self.stack.push(value)
    }


    /// 0x55 - SSTORE operation
    /// Save 32-byte word to storage.
    /// # Specification: https://www.evm.codes/#55?fork=shanghai
    fn exec_sstore(ref self: VM) -> Result<(), EVMError> {
        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;
        ensure(self.gas_left() > gas::CALL_STIPEND, EVMError::OutOfGas)?; //EIP-1706

        let key = self.stack.pop()?;
        let new_value = self.stack.pop()?;
        let evm_address = self.message().target.evm;
        let account = self.env.state.get_account(evm_address);
        let original_value = fetch_original_storage(@account, key);
        let current_value = self.env.state.read_state(evm_address, key);

        // GAS
        let mut gas_cost = 0;
        if !self.accessed_storage_keys.contains((evm_address, key)) {
            self.accessed_storage_keys.add((evm_address, key));
            gas_cost += gas::COLD_SLOAD_COST;
        }

        if original_value == current_value && current_value != new_value {
            if original_value == 0 {
                gas_cost += gas::SSTORE_SET
            } else {
                gas_cost += gas::SSTORE_RESET - gas::COLD_SLOAD_COST;
            }
        } else {
            gas_cost += gas::WARM_ACCESS_COST;
        }

        // Gas refunds
        if current_value != new_value {
            if original_value != 0 && current_value != 0 && new_value == 0 {
                // Storage is cleared for the first time in the transaction
                self.gas_refund += gas::REFUND_SSTORE_CLEARS;
            }

            if original_value != 0 && current_value == 0 {
                // Earlier gas refund needs to be reversed
                self.gas_refund -= gas::REFUND_SSTORE_CLEARS;
            }

            if original_value == new_value {
                // Restoring slot to original value (used as transient storage)
                if original_value == 0 {
                    // The access cost is still charged but the SSTORE cost is refunded
                    self.gas_refund += (gas::SSTORE_SET - gas::WARM_ACCESS_COST);
                } else {
                    // Slot was originally non-empty and was updated earlier
                    // cold sload cost and warm access cost are not refunded
                    self
                        .gas_refund +=
                            (gas::SSTORE_RESET - gas::COLD_SLOAD_COST - gas::WARM_ACCESS_COST);
                }
            }
        }

        self.charge_gas(gas_cost)?;

        self.env.state.write_state(:evm_address, :key, value: new_value);
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
            Option::Some(_) => { ensure(self.is_valid_jump(index), EVMError::InvalidJump)?; },
            Option::None => { return Result::Err(EVMError::InvalidJump); }
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
        self.stack.push(self.gas_left().into())
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
