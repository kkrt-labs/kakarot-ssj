//! Stop and Arithmetic Operations.

use integer::{
    u256_overflowing_add, u256_overflow_sub, u256_overflow_mul, u256_safe_divmod,
    u512_safe_div_rem_by_u256, u256_try_as_non_zero
};
use evm::context::{ExecutionContextTrait, ExecutionContext, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use utils::math::{Exponentiation, WrappingExponentiation, u256_wide_add};
use evm::errors::EVMError;
use utils::i256::i256;

#[generate_trait]
impl StopAndArithmeticOperations of StopAndArithmeticOperationsTrait {
    /// 0x00 - STOP
    /// Halts the execution of the current program.
    /// # Specification: https://www.evm.codes/#00?fork=shanghai
    fn exec_stop(ref self: ExecutionContext) -> Result<(), EVMError> {
        self.stop();
        Result::Ok(())
    }

    /// 0x01 - ADD
    /// Addition operation
    /// a + b: integer result of the addition modulo 2^256.
    /// # Specification: https://www.evm.codes/#01?fork=shanghai
    fn exec_add(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;

        // Compute the addition
        let (result, _) = u256_overflowing_add(*popped[0], *popped[1]);

        self.stack.push(result)
    }

    /// 0x02 - MUL
    /// Multiplication
    /// a * b: integer result of the multiplication modulo 2^256.
    /// # Specification: https://www.evm.codes/#02?fork=shanghai
    fn exec_mul(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;

        // Compute the multiplication
        let (result, _) = u256_overflow_mul(*popped[0], *popped[1]);

        self.stack.push(result)
    }

    /// 0x03 - SUB
    /// Subtraction operation
    /// a - b: integer result of the subtraction modulo 2^256.
    /// # Specification: https://www.evm.codes/#03?fork=shanghai
    fn exec_sub(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;

        // Compute the substraction
        let (result, _) = u256_overflow_sub(*popped[0], *popped[1]);

        self.stack.push(result)
    }

    /// 0x04 - DIV
    /// If the denominator is 0, the result will be 0.
    /// a / b: integer result of the integer division.
    /// # Specification: https://www.evm.codes/#04?fork=shanghai
    fn exec_div(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];

        let result: u256 = match u256_try_as_non_zero(b) {
            Option::Some(_) => {
                // Won't panic because b is not zero
                a / b
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x05 - SDIV
    /// Signed division operation
    /// a / b: integer result of the signed integer division.
    /// If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#05?fork=shanghai
    fn exec_sdiv(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a: i256 = Into::<u256, i256>::into(*popped[0]);
        let b: i256 = Into::<u256, i256>::into(*popped[1]);

        let result: u256 = (a / b).into();
        self.stack.push(result)
    }

    /// 0x06 - MOD
    /// Modulo operation
    /// a % b: integer result of the integer modulo. If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#06?fork=shanghai
    fn exec_mod(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];

        let result: u256 = match u256_try_as_non_zero(b) {
            Option::Some(_) => {
                // Won't panic because b is not zero
                a % b
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x07 - SMOD
    /// Signed modulo operation
    /// a % b: integer result of the signed integer modulo. If the denominator is 0, the result will be 0.
    /// All values are treated as two’s complement signed 256-bit integers. Note the overflow semantic when −2^255 is negated.
    /// # Specification: https://www.evm.codes/#07?fork=shanghai
    fn exec_smod(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a: i256 = Into::<u256, i256>::into(*popped[0]);
        let b: i256 = Into::<u256, i256>::into(*popped[1]);

        let result: u256 = (a % b).into();
        self.stack.push(result)
    }

    /// 0x08 - ADDMOD
    /// Addition and modulo operation
    /// (a + b) % N: integer result of the addition followed by a modulo. If the denominator is 0, the result will be 0.
    /// All intermediate calculations of this operation are not subject to the 2256 modulo.
    /// # Specification: https://www.evm.codes/#08?fork=shanghai
    fn exec_addmod(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(3)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];
        let n = *popped[2];

        let result: u256 = match u256_try_as_non_zero(n) {
            Option::Some(nonzero_n) => {
                // This is more gas efficient than computing (a mod N) + (b mod N) mod N
                let sum = u256_wide_add(*popped[0], *popped[1]);
                let (_, r) = u512_safe_div_rem_by_u256(sum, nonzero_n);
                r
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x09 - MULMOD operation.
    /// (a * b) % N: integer result of the multiplication followed by a modulo.
    /// All intermediate calculations of this operation are not subject to the 2^256 modulo.
    /// If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#09?fork=shanghai
    fn exec_mulmod(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(3)?;

        let a: u256 = *popped[0];
        let b: u256 = *popped[1];
        let n = *popped[2];

        let result: u256 = match u256_try_as_non_zero(n) {
            Option::Some(_) => {
                // (x * y) mod N <=> (x mod N) * (y mod N) mod N
                // It is more gas-efficient than to use u256_wide_mul
                // Won't panic because n is not zero
                (*popped[0] % n) * (*popped[1] % n) % n
            },
            Option::None => 0,
        };

        self.stack.push(result)
    }

    /// 0x0A - EXP
    /// Exponential operation
    /// a ** b: integer result of raising a to the bth power modulo 2^256.
    /// # Specification: https://www.evm.codes/#0a?fork=shanghai
    fn exec_exp(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let a = *popped[0];
        let b = *popped[1];

        let result = a.wrapping_pow(b);

        self.stack.push(result)
    }

    /// 0x0B - SIGNEXTEND
    /// SIGNEXTEND takes two inputs `b` and `x` where x: integer value to sign extend
    /// and b: size in byte - 1 of the integer to sign extend and extends the length of
    /// x as a two’s complement signed integer.
    /// The first `i` bits of the output (numbered from the /!\LEFT/!\ counting from zero)
    /// are equal to the `t`-th bit of `x`, where `t` is equal to
    /// `256 - 8(b + 1)`. The remaining bits of the output are equal to the corresponding bits of `x`.
    /// If b >= 32, then the output is x because t<=0.
    /// To efficiently implement this algorithm we can implement it using a mask, which is all zeroes until the t-th bit included,
    /// and all ones afterwards. The index of `t` when numbered from the RIGHT is s = `255 - t` = `8b + 7`; so the integer value
    /// of the mask used is 2^s - 1.
    /// Let v be the t-th bit of x. If v == 1, then the output should be all 1s until the t-th bit included,
    /// followed by the remaining bits of x; which is corresponds to (x | !mask).
    /// If v == 0, then the output should be all 0s until the t-th bit included, followed by the remaining bits of x;
    /// which corresponds to (x & mask).
    /// # Specification: https://www.evm.codes/#0b?fork=shanghai
    /// Complex opcode, check: https://ethereum.github.io/yellowpaper/paper.pdf
    fn exec_signextend(ref self: ExecutionContext) -> Result<(), EVMError> {
        let popped = self.stack.pop_n(2)?;
        let b = *popped[0];
        let x = *popped[1];

        let result = if b < 32 {
            let s = 8 * b + 7;
            let two_pow_s = 2.pow(s);
            // Get v, the t-th bit of x. To do this we bitshift x by s bits to the right and apply a mask to get the last bit.
            let v = (x / two_pow_s) & 1;
            // Compute the mask with 8b+7 bits set to one
            let mask = two_pow_s - 1;
            if v == 0 {
                x & mask
            } else {
                x | ~mask
            }
        } else {
            x
        };

        self.stack.push(result)
    }
}
