use evm::errors::EVMError;
use evm::memory::{Memory, MemoryTrait};
use evm::model::{Message, Environment};
use evm::stack::{Stack, StackTrait};
use starknet::EthAddress;
use utils::helpers::ArrayExtTrait;
use utils::traits::{SpanDefault};

#[derive(Default, Destruct)]
struct VM {
    stack: Stack,
    memory: Memory,
    pc: usize,
    valid_jumpdests: Span<usize>,
    return_data: Span<u8>,
    env: Environment,
    message: Message,
    gas_used: u128,
    running: bool,
    error: bool,
    accessed_addresses: Array<EthAddress>
}


#[generate_trait]
impl VMImpl of VMTrait {
    fn new(message: Message, env: Environment) -> VM {
        VM {
            stack: Default::default(),
            memory: Default::default(),
            pc: 0,
            valid_jumpdests: Default::default().span(),
            return_data: Default::default().span(),
            env,
            message,
            gas_used: 0,
            running: true,
            error: false,
            accessed_addresses: Default::default()
        }
    }

    /// Increments the gas_used field of the current execution context by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_used + new_gas >= limit
    #[inline(always)]
    fn charge_gas(ref self: VM, value: u128) -> Result<(), EVMError> {
        let new_gas_used = self.gas_used + value;
        if (new_gas_used >= self.message().gas_limit) {
            return Result::Err(EVMError::OutOfGas);
        }
        self.gas_used = new_gas_used;
        Result::Ok(())
    }


    fn pc(self: @VM) -> usize {
        *self.pc
    }

    fn set_pc(ref self: VM, pc: usize) {
        self.pc = pc;
    }

    fn valid_jumpdests(self: @VM) -> Span<usize> {
        *self.valid_jumpdests
    }

    fn set_valid_jumpdests(ref self: VM, valid_jumpdests: Span<usize>) {
        self.valid_jumpdests = valid_jumpdests;
    }

    fn return_data(self: @VM) -> Span<u8> {
        *self.return_data
    }

    fn set_return_data(ref self: VM, return_data: Span<u8>) {
        self.return_data = return_data;
    }

    fn is_running(self: @VM) -> bool {
        *self.running
    }

    fn stop(ref self: VM) {
        self.running = false;
    }

    fn set_error(ref self: VM) {
        self.error = true;
    }

    fn message(self: @VM) -> Message {
        *self.message
    }

    fn gas_used(self: @VM) -> u128 {
        *self.gas_used
    }

    /// Reads and return data from bytecode.
    /// The program counter is incremented accordingly.
    ///
    /// # Arguments
    ///
    /// * `self` - The `ExecutionContext` instance to read the data from.
    /// * `len` - The length of the data to read from the bytecode.
    #[inline(always)]
    fn read_code(self: @VM, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let code = self.message().code.slice(self.pc(), len);
        code
    }

    #[inline(always)]
    fn increment_gas_used_unchecked(ref self: VM, value: u128) {
        self.gas_used += value;
    }

    fn merge_child(ref self: VM, other: VM) {
        //TODO rest of the return logic
        if !self.error {
            self.accessed_addresses.concat_unique(other.accessed_addresses.span());
        }
    }
}
