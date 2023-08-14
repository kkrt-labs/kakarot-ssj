//! Stop and Arithmetic Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;
use kakarot::stack::StackTrait;
use integer::{u256_overflowing_add, u256_overflow_sub, u256_overflow_mul, u256_safe_divmod};

#[generate_trait]
impl StopAndArithmeticOperations of StopAndArithmeticOperationsTrait {
    /// 0x00 - STOP operation.
    /// Halts the execution of the current program.
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group:
    /// - Gas: 
    /// # Arguments
    /// * `self` - the execution context
    fn exec_stop(ref self: ExecutionContext) {
        self.stop();
    }

    /// 0x01 - ADD
    /// Addition operation
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 3
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `ctx` - The pointer to the execution context.
    fn exec_add(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: first integer value to add.
        // 1 = b: second integer value to add.
        let popped = self.stack.pop_n(2);

        // Compute the addition
        let (result, _) = u256_overflowing_add(*popped[0], *popped[1]);

        // Stack output:
        // a+b: integer addition of a and b.
        self.stack.push(result);
    }

    /// 0x02 - MUL operation.
    /// Multiplication operation.
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    fn exec_mul(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: first integer value to multiply.
        // 1 = b: second integer value to multiply.
        let popped = self.stack.pop_n(2);

        // Compute the multiplication
        let (result, _) = u256_overflow_mul(*popped[0], *popped[1]);

        // Stack output:
        // a*b: integer multiplication of a and b.
        self.stack.push(result);
    }

    /// 0x03 - SUB
    /// Subtraction operation
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 3
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    fn exec_sub(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: first integer value to subtract.
        // 1 = b: second integer value to subtract.
        let popped = self.stack.pop_n(2);

        // Compute the substraction
        let (result, _) = u256_overflow_sub(*popped[0], *popped[1]);

        // Stack output:
        // a-b: integer subtraction of a and b.
        self.stack.push(result);
    }

    /// DIV operation.
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    fn exec_div(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: numerator
        // 1 = b: denominator
        let popped = self.stack.pop_n(2);

        // Compute the division
        // Won't panic since 0 case is handled manually
        let a = *popped[0];
        let b = *popped[1];
        let mut result = 0;
        if b != 0 {
            result = a / b;
        }

        // Stack output:
        // a/b: integer division of a and b.
        self.stack.push(result);
    }

    /// SDIV operation.
    /// Signed division operation
    /// # Additional informations:
    /// - Since: Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    ///TODO 
    /// - Implement me.
    /// * `self` - the execution context
    fn exec_sdiv(
        ref self: ExecutionContext
    ) { //TODO implement two's complement u256 signed division
    }

    /// MOD operation.
    /// # Additional informations:
    /// - Since: Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    fn exec_mod(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: number
        // 1 = b: modulo
        let popped = self.stack.pop_n(2);

        // Compute the result of a mod b
        let result = *popped[0] % *popped[1];

        // Stack output:
        // a%b: unsigned integer result of a mod b
        self.stack.push(result);
    }

    /// SMOD operation.
    /// Signed modulo operation
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    ///TODO
    /// - Implement me.
    fn exec_smod(ref self: ExecutionContext) {}

    /// ADDMOD operation.
    /// Addition modulo operation
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 8
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    fn exec_addmod(ref self: ExecutionContext) {
        // Stack input:
        // 0 = a: first integer value to add.
        // 1 = b: second integer value to add.
        // 2 = n: modulo
        let popped = self.stack.pop_n(3);

        // Compute the addition
        let (add_res, _) = u256_overflowing_add(*popped[0], *popped[1]);
        let result = add_res % *popped[2];

        // Stack output:
        // (a+b)%n: integer addition of a and b modulo n.
        self.stack.push(result);
    }

    /// MULMOD operation.
    /// Multiplication modulo operation.
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 8
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    /// # TODO
    /// - Implement me.
    fn exec_mulmod(ref self: ExecutionContext) { //TODO implement u256 mulmod
    }

    /// EXP operation.
    /// # Additional informations:
    /// - Since: Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 10
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    /// # TODO
    /// - Implement me.
    fn exec_exp(ref self: ExecutionContext) { //TODO exponentiation algorithm
    }

    /// SIGNEXTEND - 0x0B
    /// Exp operation
    /// # Additional informations:
    /// - Since: Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    /// TODO
    /// - Implement me.
    fn exec_signextend(ref self: ExecutionContext) { // TODO signed integer extension algorithm
    }
}
