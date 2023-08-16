//! Stop and Arithmetic Operations.

use integer::{u256_overflowing_add, u256_overflow_sub, u256_overflow_mul, u256_safe_divmod};
use traits::TryInto;
use option::OptionTrait;

use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;
use kakarot::stack::StackTrait;
use kakarot::utils::u256_signed_math::u256_signed_div_rem;
use kakarot::utils::math::{Exponentiation, ExponentiationModulo};

#[generate_trait]
impl StopAndArithmeticOperations of StopAndArithmeticOperationsTrait {
    /// 0x00 - STOP
    /// Halts the execution of the current program.
    /// # Specification: https://www.evm.codes/#00?fork=shanghai
    fn exec_stop(ref self: ExecutionContext) {
        self.stop();
    }

    /// 0x01 - ADD
    /// Addition operation 
    /// a + b: integer result of the addition modulo 2^256.
    /// # Specification: https://www.evm.codes/#01?fork=shanghai
    fn exec_add(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(2);

        // Compute the addition
        let (result, _) = u256_overflowing_add(*popped[0], *popped[1]);

        self.stack.push(result);
    }

    /// 0x02 - MUL
    /// Multiplication
    /// a * b: integer result of the multiplication modulo 2^256.
    /// # Specification: https://www.evm.codes/#02?fork=shanghai
    fn exec_mul(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(2);

        // Compute the multiplication
        let (result, _) = u256_overflow_mul(*popped[0], *popped[1]);

        self.stack.push(result);
    }

    /// 0x03 - SUB
    /// Subtraction operation
    /// a - b: integer result of the subtraction modulo 2^256.
    /// # Specification: https://www.evm.codes/#03?fork=shanghai
    fn exec_sub(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(2);

        // Compute the substraction
        let (result, _) = u256_overflow_sub(*popped[0], *popped[1]);

        self.stack.push(result);
    }

    /// 0x04 - DIV
    /// If the denominator is 0, the result will be 0.
    /// a / b: integer result of the integer division. 
    /// # Specification: https://www.evm.codes/#04?fork=shanghai
    fn exec_div(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(2);

        let a = *popped[0];
        let b = *popped[1];
        let mut result = 0;
        // Won't panic since 0 case is handled manually
        if b != 0 {
            result = a / b;
        }

        self.stack.push(result);
    }

    /// 0x05 - SDIV
    /// Signed division operation
    /// a / b: integer result of the signed integer division. 
    /// If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#05?fork=shanghai
    fn exec_sdiv(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(2);
        let a = *popped[0];
        let b = *popped[1];

        // Compute the division
        let (result, _) = u256_signed_div_rem(a, b);

        self.stack.push(result);
    }

    /// 0x06 - MOD
    /// Modulo operation
    /// a % b: integer result of the integer modulo. If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#06?fork=shanghai
    fn exec_mod(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(2);

        let mut result = 0;
        let b = *popped[1];
        if b != 0 {
            result = *popped[0] % *popped[1];
        }

        self.stack.push(result);
    }

    /// 0x07 - SMOD
    /// Signed modulo operation
    /// a % b: integer result of the signed integer modulo. If the denominator is 0, the result will be 0.
    /// All values are treated as two’s complement signed 256-bit integers. Note the overflow semantic when −2255 is negated.
    /// # Specification: https://www.evm.codes/#07?fork=shanghai
    fn exec_smod(ref self: ExecutionContext) {}

    /// 0x08 - ADDMOD
    /// Addition and modulo operation
    /// a % b: integer result of the signed integer modulo. If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#08?fork=shanghai
    fn exec_addmod(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: first integer value to add.
        // 1 = b: second integer value to add.
        // 2 = n: modulo
        let popped = self.stack.pop_n(3);

        let n = *popped[2];
        let mut result = 0;
        if n != 0 {
            // Compute the addition
            let (add_res, _) = u256_overflowing_add(*popped[0], *popped[1]);
            result = add_res % *popped[2];
        }
        // Stack output:
        // (a + b) % N: integer result of the addition followed by a modulo. If the denominator is 0, the result will be 0.
        self.stack.push(result);
    }

    /// 0x09 - MULMOD operation.
    /// (a * b) % N: integer result of the multiplication followed by a modulo.
    /// All intermediate calculations of this operation are not subject to the 2^256 modulo.
    /// If the denominator is 0, the result will be 0.
    /// # Specification: https://www.evm.codes/#09?fork=shanghai
    fn exec_mulmod(ref self: ExecutionContext) {
        let popped = self.stack.pop_n(3);

        let n: u256 = *popped[2];
        let mut result = 0;
        if n != 0 {
            // (x * y) mod N <=> (x mod N) * (y mod N) mod N
            // It is more gas-efficient than to use u256_wide_mul
            result = (*popped[0] % n) * (*popped[1] % n) % n;
        }
        self.stack.push(result);
    }

    /// 0x0A - EXP
    /// Exponential operation
    /// a ** b: integer result of raising a to the bth power modulo 2^256.
    /// # Specification: https://www.evm.codes/#0a?fork=shanghai
    fn exec_exp(ref self: ExecutionContext) {
        // Stack input:
        // 0 - a: integer base.
        // 1 - exponent: integer exponent.
        let popped = self.stack.pop_n(2);
        let a = *popped[0];
        let b = *popped[1];

        // Compute the result of a**exponent
        let result = a.pow_mod(b);

        // Stack output:
        // a ** exponent: integer result of the exponential operation modulo 2256.
        self.stack.push(result);
    }

    /// 0x0B - SIGNEXTEND
    /// # Specification: https://www.evm.codes/#0b?fork=shanghai
    /// Complex opcode, check: https://ethereum.github.io/yellowpaper/paper.pdf
    fn exec_signextend(ref self: ExecutionContext) { // TODO signed integer extension algorithm
    }
}
