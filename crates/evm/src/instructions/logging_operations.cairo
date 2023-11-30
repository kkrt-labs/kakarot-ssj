use evm::errors::EVMError;
//! Logging Operations.

// Internal imports
use evm::model::vm::{VM, VMTrait};

#[generate_trait]
impl LoggingOperations of LoggingOperationsTrait {
    /// 0xA0 - LOG0 operation
    /// Append log record with no topic.
    /// # Specification: https://www.evm.codes/#a0?fork=shanghai
    fn exec_log0(ref self: VM) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 0)
    }

    /// 0xA1 - LOG1 
    /// Append log record with one topic.
    /// # Specification: https://www.evm.codes/#a1?fork=shanghai
    fn exec_log1(ref self: VM) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 1)
    }

    /// 0xA2 - LOG2 
    /// Append log record with two topics.
    /// # Specification: https://www.evm.codes/#a2?fork=shanghai
    fn exec_log2(ref self: VM) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 2)
    }

    /// 0xA3 - LOG3 
    /// Append log record with three topics.
    /// # Specification: https://www.evm.codes/#a3?fork=shanghai
    fn exec_log3(ref self: VM) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 3)
    }

    /// 0xA4 - LOG4 
    /// Append log record with four topics.
    /// # Specification: https://www.evm.codes/#a4?fork=shanghai
    fn exec_log4(ref self: VM) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 4)
    }
}

mod internal {
    use evm::errors::{EVMError, WRITE_IN_STATIC_CONTEXT};
    use evm::gas;
    use evm::memory::MemoryTrait;
    use evm::model::Event;
    use evm::stack::StackTrait;
    use evm::state::StateTrait;
    use evm::model::vm::{VM, VMTrait};


    /// Store a new event in the dynamic context using topics
    /// popped from the stack and data from the memory.
    ///
    /// # Arguments
    ///
    /// * `self` - The context to which the event will be added
    /// * `topics_len` - The amount of topics to pop from the stack
    fn exec_log_i(ref self: VM, topics_len: u8) -> Result<(), EVMError> {
        // Revert if the transaction is in a read only context
        if self.message().read_only {
            return Result::Err(EVMError::WriteInStaticContext(WRITE_IN_STATIC_CONTEXT));
        }

        // TODO: Add dynamic memory gas
        self.charge_gas(gas::LOG + gas::LOGTOPIC * topics_len.into())?;

        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;
        let topics: Array<u256> = self.stack.pop_n(topics_len.into())?;

        let mut data: Array<u8> = Default::default();
        self.memory.load_n(size, ref data, offset);

        let event: Event = Event { keys: topics, data };
        self.env.state.add_event(event);

        Result::Ok(())
    }
}
