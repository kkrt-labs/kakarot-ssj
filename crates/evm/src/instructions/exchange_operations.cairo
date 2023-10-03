//! Exchange Operations.

use evm::errors::EVMError;
use evm::machine::Machine;
use evm::stack::StackTrait;
use utils::helpers::load_word;

#[generate_trait]
impl ExchangeOperations of ExchangeOperationsTrait {
    /// 0x90 - SWAP1 operation
    /// Exchange 1st and 2nd stack items.
    /// # Specification: https://www.evm.codes/#90?fork=shanghai

    fn exec_swap1(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(1)
    }

    /// 0x91 - SWAP2 operation
    /// Exchange 1st and 3rd stack items.
    /// # Specification: https://www.evm.codes/#91?fork=shanghai
    fn exec_swap2(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(2)
    }

    /// 0x92 - SWAP3 operation
    /// Exchange 1st and 4th stack items.
    /// # Specification: https://www.evm.codes/#92?fork=shanghai
    fn exec_swap3(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(3)
    }

    /// 0x93 - SWAP4 operation
    /// Exchange 1st and 5th stack items.
    /// # Specification: https://www.evm.codes/#93?fork=shanghai
    fn exec_swap4(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(4)
    }

    /// 0x94 - SWAP5 operation
    /// Exchange 1st and 6th stack items.
    /// # Specification: https://www.evm.codes/#94?fork=shanghai
    fn exec_swap5(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(5)
    }

    /// 0x95 - SWAP6 operation
    /// Exchange 1st and 7th stack items.
    /// # Specification: https://www.evm.codes/#95?fork=shanghai
    fn exec_swap6(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(6)
    }

    /// 0x96 - SWAP7 operation
    /// Exchange 1st and 8th stack items.
    /// # Specification: https://www.evm.codes/#96?fork=shanghai
    fn exec_swap7(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(7)
    }

    /// 0x97 - SWAP8 operation
    /// Exchange 1st and 9th stack items.
    /// # Specification: https://www.evm.codes/#97?fork=shanghai
    fn exec_swap8(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(8)
    }

    /// 0x98 - SWAP9 operation
    /// Exchange 1st and 10th stack items.
    /// # Specification: https://www.evm.codes/#98?fork=shanghai
    fn exec_swap9(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(9)
    }

    /// 0x99 - SWAP10 operation
    /// Exchange 1st and 11th stack items.
    /// # Specification: https://www.evm.codes/#99?fork=shanghai
    fn exec_swap10(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(10)
    }

    /// 0x9A - SWAP11 operation
    /// Exchange 1st and 12th stack items.
    /// # Specification: https://www.evm.codes/#9a?fork=shanghai
    fn exec_swap11(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(11)
    }

    /// 0x9B - SWAP12 operation
    /// Exchange 1st and 13th stack items.
    /// # Specification: https://www.evm.codes/#9b?fork=shanghai
    fn exec_swap12(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(12)
    }

    /// 0x9C - SWAP13 operation
    /// Exchange 1st and 14th stack items.
    /// # Specification: https://www.evm.codes/#9c?fork=shanghai
    fn exec_swap13(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(13)
    }

    /// 0x9D - SWAP14 operation
    /// Exchange 1st and 15th stack items.
    /// # Specification: https://www.evm.codes/#9d?fork=shanghai
    fn exec_swap14(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(14)
    }

    /// 0x9E - SWAP15 operation
    /// Exchange 1st and 16th stack items.
    /// # Specification: https://www.evm.codes/#9e?fork=shanghai
    fn exec_swap15(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(15)
    }

    /// 0x9F - SWAP16 operation
    /// Exchange 1st and 16th stack items.
    /// # Specification: https://www.evm.codes/#9f?fork=shanghai
    fn exec_swap16(ref self: Machine) -> Result<(), EVMError> {
        self.stack.swap_i(16)
    }
}
