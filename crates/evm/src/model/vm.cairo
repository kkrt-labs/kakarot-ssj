use evm::errors::{EVMError, ensure};
use evm::memory::{Memory, MemoryTrait};
use evm::model::{Message, Environment, ExecutionResult};
use evm::stack::{Stack, StackTrait};
use integer::u128_overflowing_sub;
use starknet::EthAddress;
use utils::helpers::{SpanExtTrait, ArrayExtTrait};
use utils::set::{Set, SetTrait, SpanSet};
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
    gas_left: u128,
    running: bool,
    error: bool,
    accessed_addresses: Set<EthAddress>,
    accessed_storage_keys: Set<(EthAddress, u256)>,
}


#[generate_trait]
impl VMImpl of VMTrait {
    #[inline(always)]
    fn new(message: Message, env: Environment) -> VM {
        VM {
            stack: Default::default(),
            memory: Default::default(),
            pc: 0,
            valid_jumpdests: Default::default().span(),
            return_data: Default::default().span(),
            env,
            message,
            gas_left: message.gas_limit,
            running: true,
            error: false,
            accessed_addresses: message.accessed_addresses.inner.clone(),
            accessed_storage_keys: message.accessed_storage_keys.inner.clone(),
        }
    }

    /// Increments the gas_left field of the current execution context by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_left - value < 0
    #[inline(always)]
    fn charge_gas(ref self: VM, value: u128) -> Result<(), EVMError> {
        self.gas_left = match u128_overflowing_sub(self.gas_left, value) {
            Result::Ok(gas_left) => gas_left,
            Result::Err(_) => { return Result::Err(EVMError::OutOfGas); },
        };
        Result::Ok(())
    }


    #[inline(always)]
    fn pc(self: @VM) -> usize {
        *self.pc
    }

    #[inline(always)]
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

    #[inline(always)]
    fn valid_jumpdests(self: @VM) -> Span<usize> {
        *self.valid_jumpdests
    }

    #[inline(always)]
    fn set_valid_jumpdests(ref self: VM, valid_jumpdests: Span<usize>) {
        self.valid_jumpdests = valid_jumpdests;
    }

    #[inline(always)]
    fn is_valid_jump(self: @VM, dest: u32) -> bool {
        self.valid_jumpdests().contains(dest)
    }

    #[inline(always)]
    fn return_data(self: @VM) -> Span<u8> {
        *self.return_data
    }

    #[inline(always)]
    fn set_return_data(ref self: VM, return_data: Span<u8>) {
        self.return_data = return_data;
    }

    #[inline(always)]
    fn is_running(self: @VM) -> bool {
        *self.running
    }

    #[inline(always)]
    fn stop(ref self: VM) {
        self.running = false;
    }

    #[inline(always)]
    fn set_error(ref self: VM) {
        self.error = true;
    }

    #[inline(always)]
    fn is_error(self: @VM) -> bool {
        *self.error
    }

    #[inline(always)]
    fn message(self: @VM) -> Message {
        *self.message
    }

    #[inline(always)]
    fn gas_left(self: @VM) -> u128 {
        *self.gas_left
    }

    #[inline(always)]
    fn accessed_addresses(self: @VM) -> SpanSet<EthAddress> {
        self.accessed_addresses.spanset()
    }

    #[inline(always)]
    fn accessed_storage_keys(self: @VM) -> SpanSet<(EthAddress, u256)> {
        self.accessed_storage_keys.spanset()
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
    fn merge_child(ref self: VM, child: @ExecutionResult) {
        if *child.success {
            //TODO: merge accessed storage
            self.accessed_addresses.extend(*child.accessed_addresses);
            self.accessed_storage_keys.extend(*child.accessed_storage_keys);
        }
        //TODO(gas) handle error case

        self.gas_left += *child.gas_left;
    }
}
