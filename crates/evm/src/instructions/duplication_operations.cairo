//! Duplication Operations.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::errors::EVMError;

mod internal {
    use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
    use evm::stack::StackTrait;
    use evm::errors::EVMError;

    /// Generic DUP operation
    fn exec_dup_i(ref context: ExecutionContext, i: NonZero<u8>) -> Result<(), EVMError> {
        let i: u8 = i.into();

        let item = context.stack.peek_at((i - 1).into())?;
        context.stack.push(item)
    }
}

#[generate_trait]
impl DuplicationOperations of DuplicationOperationsTrait {
    /// 0x80 - DUP1 operation
    fn exec_dup1(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 1_u8.try_into().unwrap())
    }

    /// 0x81 - DUP2 operation
    fn exec_dup2(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 2_u8.try_into().unwrap())
    }

    /// 0x82 - DUP3 operation
    fn exec_dup3(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 3_u8.try_into().unwrap())
    }

    /// 0x83 - DUP2 operation
    fn exec_dup4(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 4_u8.try_into().unwrap())
    }

    /// 0x84 - DUP5 operation
    fn exec_dup5(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 5_u8.try_into().unwrap())
    }

    /// 0x85 - DUP6 operation
    fn exec_dup6(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 6_u8.try_into().unwrap())
    }

    /// 0x86 - DUP7 operation
    fn exec_dup7(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 7_u8.try_into().unwrap())
    }

    /// 0x87 - DUP8 operation
    fn exec_dup8(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 8_u8.try_into().unwrap())
    }

    /// 0x88 - DUP9 operation
    fn exec_dup9(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 9_u8.try_into().unwrap())
    }

    /// 0x89 - DUP10 operation
    fn exec_dup10(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 10_u8.try_into().unwrap())
    }

    /// 0x8A - DUP11 operation
    fn exec_dup11(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 11_u8.try_into().unwrap())
    }

    /// 0x8B - DUP12 operation
    fn exec_dup12(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 12_u8.try_into().unwrap())
    }

    /// 0x8C - DUP13 operation
    fn exec_dup13(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 13_u8.try_into().unwrap())
    }

    /// 0x8D - DUP14 operation
    fn exec_dup14(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 14_u8.try_into().unwrap())
    }

    /// 0x8E - DUP15 operation
    fn exec_dup15(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 15_u8.try_into().unwrap())
    }

    /// 0x8F - DUP16 operation
    fn exec_dup16(ref self: ExecutionContext) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 16_u8.try_into().unwrap())
    }
}
