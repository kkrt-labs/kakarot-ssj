//! Logging Operations.

// Internal imports
use evm::context::ExecutionContext;
use evm::errors::EVMError;

#[generate_trait]
impl LoggingOperations of LoggingOperationsTrait {
    /// 0xA0 - LOG0 operation
    /// Append log record with no topic.
    /// # Specification: https://www.evm.codes/#a0?fork=shanghai
    fn exec_log0(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 0)
    }


    /// 0xA1 - LOG1 
    /// Append log record with one topic.
    /// # Specification: https://www.evm.codes/#a1?fork=shanghai
    fn exec_log1(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 1)
    }

    /// 0xA2 - LOG2 
    /// Append log record with two topics.
    /// # Specification: https://www.evm.codes/#a2?fork=shanghai
    fn exec_log2(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 2)
    }

    /// 0xA3 - LOG3 
    /// Append log record with three topics.
    /// # Specification: https://www.evm.codes/#a3?fork=shanghai
    fn exec_log3(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 3)
    }

    /// 0xA4 - LOG4 
    /// Append log record with four topics.
    /// # Specification: https://www.evm.codes/#a4?fork=shanghai
    fn exec_log4(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 4)
    }
}

mod internal {
    use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
    use evm::stack::StackTrait;
    use evm::memory::MemoryTrait;
    use evm::model::Event;
    use evm::errors::{EVMError, STATE_MODIFICATION_ERROR};
    use evm::helpers::U256IntoResultU32;
    use utils::helpers::u256_to_bytes_array;
    use utils::helpers::ArrayExtensionTrait;
    use array::ArrayTrait;

    /// This generic function will store a new event in the dynamic context
    /// using topics popped from the stack and data from the memory.
    ///
    /// # Arguments
    ///
    /// * `self` - The context to which the event will be added
    /// * `topics_len` - The amount of topics to pop from the stack
    fn exec_log_i(ref self: ExecutionContext, topics_len: u8) -> Result<(), EVMError> {
        // Revert if the transaction is in a read only context
        if self.read_only() {
            return Result::Err(EVMError::StateModificationError(STATE_MODIFICATION_ERROR));
        }

        let popped = self.stack.pop_n(2 + topics_len.into())?;
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into(*popped[0])?;
        let size: u32 = Into::<u256, Result<u32, EVMError>>::into(*popped[1])?;

        // Feed topics array for the new event
        let mut topics: Array<u256> = Default::default();
        ArrayExtensionTrait::concat(ref topics, popped.span().slice(2, popped.len() - 2));

        // Feed data array for the new event
        let mut data: Array<felt252> = Default::default();
        load_data_from_memory(ref self, ref data, size, offset);

        // Create and store the new event in the dynamic context
        store_event_in_dyn_context(ref self, topics, data);

        Result::Ok(())
    }

    /// This function will store a new event in the dynamic context
    /// using given topics and data.
    /// The dynamic context has to be recreated to be modified.
    ///
    /// # Arguments
    ///
    /// * `self` - The context to which the event will be added
    /// * `topics` - Topics of the event
    /// * `data` - Data of the event
    fn store_event_in_dyn_context(
        ref self: ExecutionContext, topics: Array<u256>, data: Array<felt252>
    ) {
        let event: Event = Event { keys: topics, data };
        let mut dyn_ctx = self.dynamic_context.unbox();
        dyn_ctx.events.append(event);
        self.dynamic_context = BoxTrait::new(dyn_ctx);
    }


    /// This function will load data from the memory by 32Bytes
    /// using given topics and data.
    /// The dynamic context has to be recreated to be modified.
    ///
    /// # Arguments
    ///
    /// * `self` - The context to which the event will be added
    /// * `topics` - Topics of the event
    /// * `data` - Data of the event
    fn load_data_from_memory(
        ref self: ExecutionContext, ref data_array: Array<felt252>, size: u32, offset: u32
    ) -> Result<(), EVMError> {
        let mut i = 0;
        loop {
            if 31 + i > size {
                if i != size {
                    let loaded = self.memory.load(offset + i);
                    let mut chunk: Array<u8> = u256_to_bytes_array(loaded);
                    let mut last_elem = 0;
                    let mut j = 0;
                    loop {
                        if j + i == size {
                            break;
                        }
                        last_elem *= 256;
                        last_elem += (*chunk[j]).into();
                        j += 1;
                    };
                    data_array.append(last_elem);
                }
                break;
            };
            let mut loaded = self.memory.load(offset + i);
            loaded /= 256;
            data_array.append(loaded.try_into().unwrap());
            i += 31;
        };
        Result::Ok(())
    }
}
