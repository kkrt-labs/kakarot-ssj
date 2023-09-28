//! Duplication Operations.

// Internal imports
use evm::errors::EVMError;
use evm::machine::Machine;

mod internal {
    use evm::context::{ExecutionContext, ExecutionContextTrait,};
    use evm::stack::StackTrait;
    use evm::errors::EVMError;
    use evm::machine::Machine;

    /// Generic DUP operation
    #[inline(always)]
    fn exec_dup_i(ref machine: Machine, i: u8) -> Result<(), EVMError> {
        let item = machine.stack.peek_at((i - 1).into())?;
        machine.stack.push(item)
    }
}

#[generate_trait]
impl DuplicationOperations of DuplicationOperationsTrait {
    /// 0x80 - DUP1 operation
    #[inline(always)]
    fn exec_dup1(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 1)
    }

    /// 0x81 - DUP2 operation
    #[inline(always)]
    fn exec_dup2(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 2)
    }

    /// 0x82 - DUP3 operation
    #[inline(always)]
    fn exec_dup3(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 3)
    }

    /// 0x83 - DUP2 operation
    #[inline(always)]
    fn exec_dup4(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 4)
    }

    /// 0x84 - DUP5 operation
    #[inline(always)]
    fn exec_dup5(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 5)
    }

    /// 0x85 - DUP6 operation
    #[inline(always)]
    fn exec_dup6(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 6)
    }

    /// 0x86 - DUP7 operation
    #[inline(always)]
    fn exec_dup7(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 7)
    }

    /// 0x87 - DUP8 operation
    #[inline(always)]
    fn exec_dup8(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 8)
    }

    /// 0x88 - DUP9 operation
    #[inline(always)]
    fn exec_dup9(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 9)
    }

    /// 0x89 - DUP10 operation
    #[inline(always)]
    fn exec_dup10(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 10)
    }

    /// 0x8A - DUP11 operation
    #[inline(always)]
    fn exec_dup11(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 11)
    }

    /// 0x8B - DUP12 operation
    #[inline(always)]
    fn exec_dup12(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 12)
    }

    /// 0x8C - DUP13 operation
    #[inline(always)]
    fn exec_dup13(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 13)
    }

    /// 0x8D - DUP14 operation
    #[inline(always)]
    fn exec_dup14(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 14)
    }

    /// 0x8E - DUP15 operation
    #[inline(always)]
    fn exec_dup15(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 15)
    }

    /// 0x8F - DUP16 operation
    #[inline(always)]
    fn exec_dup16(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_dup_i(ref self, 16)
    }
}
