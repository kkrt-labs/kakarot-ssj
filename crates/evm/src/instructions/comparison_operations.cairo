// Internal imports
use evm::machine::Machine;
use evm::stack::StackTrait;
use evm::errors::STACK_UNDERFLOW;
use evm::errors::EVMError;
use utils::math::{Exponentiation, Bitshift, WrappingBitshift};
use utils::constants::{POW_2_127_U128};
use utils::traits::BoolIntoNumeric;
use utils::i256::i256;
use integer::BoundedInt;

#[generate_trait]
impl ComparisonAndBitwiseOperations of ComparisonAndBitwiseOperationsTrait {
    /// 0x10 - LT
    /// # Specification: https://www.evm.codes/#10?fork=shanghai
    fn exec_lt(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = (a < b).into();
        self.stack.push(result)
    }

    /// 0x11 - GT
    /// # Specification: https://www.evm.codes/#11?fork=shanghai
    fn exec_gt(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = (a > b).into();
        self.stack.push(result)
    }


    /// 0x12 - SLT
    /// # Specification: https://www.evm.codes/#12?fork=shanghai
    fn exec_slt(ref self: Machine) -> Result<(), EVMError> {
        let a: i256 = self.stack.pop_i256()?;
        let b: i256 = self.stack.pop_i256()?;
        let result: u256 = (a < b).into();
        self.stack.push(result)
    }

    /// 0x13 - SGT
    /// # Specification: https://www.evm.codes/#13?fork=shanghai
    fn exec_sgt(ref self: Machine) -> Result<(), EVMError> {
        let a: i256 = self.stack.pop_i256()?;
        let b: i256 = self.stack.pop_i256()?;
        let result: u256 = (a > b).into();
        self.stack.push(result)
    }


    /// 0x14 - EQ
    /// # Specification: https://www.evm.codes/#14?fork=shanghai
    fn exec_eq(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = (a == b).into();
        self.stack.push(result)
    }

    /// 0x15 - ISZERO
    /// # Specification: https://www.evm.codes/#15?fork=shanghai
    fn exec_iszero(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop()?;
        let result: u256 = (popped == 0).into();
        self.stack.push(result)
    }

    /// 0x16 - AND
    /// # Specification: https://www.evm.codes/#16?fork=shanghai
    fn exec_and(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = a & b;
        self.stack.push(result)
    }

    /// 0x17 - OR
    /// # Specification: https://www.evm.codes/#17?fork=shanghai
    fn exec_or(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = a | b;
        self.stack.push(result)
    }

    /// 0x18 - XOR operation
    /// # Specification: https://www.evm.codes/#18?fork=shanghai
    fn exec_xor(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];
        let result = a ^ b;
        self.stack.push(result)
    }

    /// 0x19 - NOT
    /// Bitwise NOT operation
    /// # Specification: https://www.evm.codes/#19?fork=shanghai
    fn exec_not(ref self: Machine) -> Result<(), EVMError> {
        let a = self.stack.pop()?;
        let result = ~a;
        self.stack.push(result)
    }

    /// 0x1A - BYTE
    /// # Specification: https://www.evm.codes/#1a?fork=shanghai
    /// Retrieve single byte located at the byte offset of value, starting from the most significant byte.
    fn exec_byte(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let i = *popped[0];
        let x = *popped[1];

        /// If the byte offset is out of range, we early return with 0.
        if i > 31 {
            return self.stack.push(0);
        }

        // Right shift value by offset bits and then take the least significant byte.
        let result = x.shr((31 - i) * 8) & 0xFF;
        self.stack.push(result)
    }

    /// 0x1B - SHL
    /// # Specification: https://www.evm.codes/#1b?fork=shanghai
    fn exec_shl(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let shift = *popped[0];
        let val = *popped[1];

        // if shift is bigger than 255 return 0
        if shift > 255 {
            return self.stack.push(0);
        }

        let result = val.wrapping_shl(shift);
        self.stack.push(result)
    }

    /// 0x1C - SHR
    /// # Specification: https://www.evm.codes/#1c?fork=shanghai
    fn exec_shr(ref self: Machine) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let shift = *popped[0];
        let value = *popped[1];

        let result = value.wrapping_shr(shift);
        self.stack.push(result)
    }

    /// 0x1D - SAR
    /// # Specification: https://www.evm.codes/#1d?fork=shanghai
    fn exec_sar(ref self: Machine) -> Result<(), EVMError> {
        let shift: u256 = self.stack.pop()?;
        let value: i256 = self.stack.pop_i256()?;

        // Checks the MSB bit sign for a 256-bit integer
        let positive = value.value.high < POW_2_127_U128;
        let sign = if positive {
            // If sign is positive, set it to 0.
            0
        } else {
            // If sign is negative, set the number to -1.
            BoundedInt::<u256>::max()
        };

        if (shift > 256) {
            self.stack.push(sign)
        } else {
            // XORing with sign before and after the shift propagates the sign bit of the operation
            let result = (sign ^ value.value).shr(shift) ^ sign;
            self.stack.push(result)
        }
    }
}
