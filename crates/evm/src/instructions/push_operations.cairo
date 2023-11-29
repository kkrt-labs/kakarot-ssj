//! Push Operations.

use evm::errors::EVMError;
use evm::gas;
use evm::machine::{Machine, MachineTrait};
use evm::stack::StackTrait;

mod internal {
    use evm::errors::EVMError;
    use evm::gas;
    use evm::machine::{Machine, MachineTrait};
    use evm::stack::StackTrait;
    use utils::helpers::load_word;

    /// Place i bytes items on stack.
    #[inline(always)]
    fn exec_push_i(ref machine: Machine, i: u8) -> Result<(), EVMError> {
        machine.increment_gas_used_checked(gas::VERYLOW)?;
        let i = i.into();
        let data = machine.read_code(i);

        machine.set_pc(machine.pc() + i);

        machine.stack.push(load_word(i, data))
    }
}

#[generate_trait]
impl PushOperations of PushOperationsTrait {
    /// 5F - PUSH0 operation
    /// # Specification: https://www.evm.codes/#5f?fork=shanghai
    #[inline(always)]
    fn exec_push0(ref self: Machine) -> Result<(), EVMError> {
        self.increment_gas_used_checked(gas::BASE)?;
        self.stack.push(0)
    }


    /// 0x60 - PUSH1 operation
    /// # Specification: https://www.evm.codes/#60?fork=shanghai
    #[inline(always)]
    fn exec_push1(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 1)
    }


    /// 0x61 - PUSH2 operation
    /// # Specification: https://www.evm.codes/#61?fork=shanghai
    #[inline(always)]
    fn exec_push2(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 2)
    }


    /// 0x62 - PUSH3 operation
    /// # Specification: https://www.evm.codes/#62?fork=shanghai
    #[inline(always)]
    fn exec_push3(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 3)
    }

    /// 0x63 - PUSH4 operation
    /// # Specification: https://www.evm.codes/#63?fork=shanghai
    #[inline(always)]
    fn exec_push4(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 4)
    }

    /// 0x64 - PUSH5 operation
    /// # Specification: https://www.evm.codes/#64?fork=shanghai
    #[inline(always)]
    fn exec_push5(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 5)
    }

    /// 0x65 - PUSH6 operation
    /// # Specification: https://www.evm.codes/#65?fork=shanghai
    #[inline(always)]
    fn exec_push6(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 6)
    }

    /// 0x66 - PUSH7 operation
    /// # Specification: https://www.evm.codes/#66?fork=shanghai
    #[inline(always)]
    fn exec_push7(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 7)
    }

    /// 0x67 - PUSH8 operation
    /// # Specification: https://www.evm.codes/#67?fork=shanghai
    #[inline(always)]
    fn exec_push8(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 8)
    }


    /// 0x68 - PUSH9 operation
    /// # Specification: https://www.evm.codes/#68?fork=shanghai
    #[inline(always)]
    fn exec_push9(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 9)
    }

    /// 0x69 - PUSH10 operation
    /// # Specification: https://www.evm.codes/#69?fork=shanghai
    #[inline(always)]
    fn exec_push10(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 10)
    }

    /// 0x6A - PUSH11 operation
    /// # Specification: https://www.evm.codes/#6a?fork=shanghai
    #[inline(always)]
    fn exec_push11(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 11)
    }

    /// 0x6B - PUSH12 operation
    /// # Specification: https://www.evm.codes/#6b?fork=shanghai
    #[inline(always)]
    fn exec_push12(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 12)
    }


    /// 0x6C - PUSH13 operation
    /// # Specification: https://www.evm.codes/#6c?fork=shanghai
    #[inline(always)]
    fn exec_push13(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 13)
    }

    /// 0x6D - PUSH14 operation
    /// # Specification: https://www.evm.codes/#6d?fork=shanghai
    #[inline(always)]
    fn exec_push14(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 14)
    }


    /// 0x6E - PUSH15 operation
    /// # Specification: https://www.evm.codes/#6e?fork=shanghai
    #[inline(always)]
    fn exec_push15(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 15)
    }

    /// 0x6F - PUSH16 operation
    /// # Specification: https://www.evm.codes/#6f?fork=shanghai
    #[inline(always)]
    fn exec_push16(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 16)
    }

    /// 0x70 - PUSH17 operation
    /// # Specification: https://www.evm.codes/#70?fork=shanghai
    #[inline(always)]
    fn exec_push17(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 17)
    }

    /// 0x71 - PUSH18 operation
    /// # Specification: https://www.evm.codes/#71?fork=shanghai
    #[inline(always)]
    fn exec_push18(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 18)
    }


    /// 0x72 - PUSH19 operation
    /// # Specification: https://www.evm.codes/#72?fork=shanghai
    #[inline(always)]
    fn exec_push19(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 19)
    }

    /// 0x73 - PUSH20 operation
    /// # Specification: https://www.evm.codes/#73?fork=shanghai
    #[inline(always)]
    fn exec_push20(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 20)
    }


    /// 0x74 - PUSH21 operation
    /// # Specification: https://www.evm.codes/#74?fork=shanghai
    #[inline(always)]
    fn exec_push21(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 21)
    }


    /// 0x75 - PUSH22 operation
    /// # Specification: https://www.evm.codes/#75?fork=shanghai
    #[inline(always)]
    fn exec_push22(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 22)
    }


    /// 0x76 - PUSH23 operation
    /// # Specification: https://www.evm.codes/#76?fork=shanghai
    #[inline(always)]
    fn exec_push23(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 23)
    }


    /// 0x77 - PUSH24 operation
    /// # Specification: https://www.evm.codes/#77?fork=shanghai
    #[inline(always)]
    fn exec_push24(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 24)
    }


    /// 0x78 - PUSH21 operation
    /// # Specification: https://www.evm.codes/#78?fork=shanghai
    #[inline(always)]
    fn exec_push25(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 25)
    }


    /// 0x79 - PUSH26 operation
    /// # Specification: https://www.evm.codes/#79?fork=shanghai
    #[inline(always)]
    fn exec_push26(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 26)
    }


    /// 0x7A - PUSH27 operation
    /// # Specification: https://www.evm.codes/#7a?fork=shanghai
    #[inline(always)]
    fn exec_push27(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 27)
    }

    /// 0x7B - PUSH28 operation
    /// # Specification: https://www.evm.codes/#7b?fork=shanghai
    #[inline(always)]
    fn exec_push28(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 28)
    }


    /// 0x7C - PUSH29 operation
    /// # Specification: https://www.evm.codes/#7c?fork=shanghai
    #[inline(always)]
    fn exec_push29(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 29)
    }


    /// 0x7D - PUSH30 operation
    /// # Specification: https://www.evm.codes/#7d?fork=shanghai
    #[inline(always)]
    fn exec_push30(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 30)
    }


    /// 0x7E - PUSH31 operation
    /// # Specification: https://www.evm.codes/#7e?fork=shanghai
    #[inline(always)]
    fn exec_push31(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 31)
    }


    /// 0x7F - PUSH32 operation
    /// # Specification: https://www.evm.codes/#7f?fork=shanghai
    #[inline(always)]
    fn exec_push32(ref self: Machine) -> Result<(), EVMError> {
        internal::exec_push_i(ref self, 32)
    }
}
