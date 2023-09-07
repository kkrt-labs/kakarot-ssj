//! Logging Operations.

// Internal imports
use evm::context::ExecutionContext;
use evm::errors::EVMError;

mod internal {
    use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
    use evm::stack::StackTrait;
    use evm::memory::MemoryTrait;
    use evm::model::Event;
    use evm::errors::{EVMError, STATE_MODIFICATION_ERROR};
    use core::array::ArrayTrait;
    use box::BoxTrait;
    use evm::helpers::U256IntoResultU32;
    use utils::helpers::u256_to_bytes_array;

    use debug::PrintTrait;

    /// Generic logging operation.
    /// Append log record with n topics.
    fn exec_log_i(ref self: ExecutionContext, topics_len: u8) -> Result<(), EVMError> {
        if self.read_only() {
            return Result::Err(EVMError::StateModificationError(STATE_MODIFICATION_ERROR));
        }

        let popped = self.stack.pop_n(2 + topics_len.into())?;
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into(*popped[0])?;
        let size: u32 = Into::<u256, Result<u32, EVMError>>::into(*popped[1])?;

        let mut topics: Array<u256> = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i == topics_len {
                break;
            }
            topics.append(*popped[2 + i.into()]);

            i += 1;
        };

        let mut datas: Array<felt252> = ArrayTrait::new();

        let mut i = 0;
        loop {
            if 31 + i > size {
                if i != size {
                    let (mut loaded, _) = self.memory.load(offset + i);
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
                    datas.append(last_elem);
                }
                break;
            };
            let (mut loaded, _) = self.memory.load(offset + i);
            loaded /= 256;
            datas.append(loaded.try_into().unwrap());
            i += 31;
        };

        let event: Event = Event { keys: topics, data: datas };

        let mut dyn_ctx = self.dynamic_context.unbox();
        dyn_ctx.events.append(event);
        self.dynamic_context = BoxTrait::new(dyn_ctx);

        Result::Ok(())
    }
}

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
    /// Append log record with 4 topics.
    /// # Specification: https://www.evm.codes/#a4?fork=shanghai
    fn exec_log4(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_log_i(ref self, 4)
    }
}
