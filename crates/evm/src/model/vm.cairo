use evm::errors::EVMError;
use evm::memory::{Memory, MemoryTrait};
use evm::model::{Message, Environment};
use evm::stack::{Stack, StackTrait};
use starknet::EthAddress;
use utils::helpers::ArrayExtTrait;
use utils::set::{Set, SetTrait};
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
    accessed_addresses: Set<EthAddress>
}


#[generate_trait]
impl VMImpl of VMTrait {
    fn new(message: Message, env: Environment) -> VM {
        let accessed_addresses: Set<EthAddress> = Default::default();
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
            accessed_addresses
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

    fn init_valid_jump_destinations(ref self: VM) {
        let bytecode = self.message.code;
        let mut valid_jumpdests: Array<usize> = array![];

        let mut i = 0;
        loop {
            if (i >= bytecode.len()) {
                break;
            }

            let opcode = *bytecode.at(i);
            // checking for PUSH opcode family
            if (opcode >= 0x5f && opcode <= 0x7f) {
                let number_of_args = opcode - 0x5f;
                i += (number_of_args + 1).into();
                continue;
            }

            // JUMPDEST
            if (opcode == 0x5B) {
                valid_jumpdests.append(i.into());
            }

            i += 1;
        };

        self.set_valid_jumpdests(valid_jumpdests.span());
    }

    fn valid_jumpdests(self: @VM) -> Span<usize> {
        *self.valid_jumpdests
    }

    fn set_valid_jumpdests(ref self: VM, valid_jumpdests: Span<usize>) {
        self.valid_jumpdests = valid_jumpdests;
    }

    #[inline(always)]
    fn is_valid_jump(self: @VM, dest: u32) -> bool {
        self.valid_jumpdests().contains(dest)
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
            self.accessed_addresses.extend(other.accessed_addresses.spanset());
        }
    }
}
