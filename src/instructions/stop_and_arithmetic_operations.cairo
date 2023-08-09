//! Stop and Arithmetic Operations.

// Internal imports
use kakarot::context::ExecutionContext;
use kakarot::context::ExecutionContextTrait;

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
    /// # TODO
    /// - Implement me.
    fn exec_add(ref self: ExecutionContext) {}

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
    /// # TODO
    /// - Implement me.
    fn exec_mul(ref self: ExecutionContext) {}

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
    /// # TODO
    /// - Implement me.
    fn exec_sub(ref self: ExecutionContext) {}

    /// DIV operation.
    /// # Additional informations:
    /// - Since:  Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    /// # TODO
    /// - Implement me.
    fn exec_div(ref self: ExecutionContext) {}

    /// SDIV operation.
    /// Signed division operation
    /// # Additional informations:
    /// - Since: Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    /// # TODO
    /// - Implement me.
    fn exec_sdiv(ref self: ExecutionContext) {}

    /// MOD operation.
    /// # Additional informations:
    /// - Since: Frontier
    /// - Group: Stop and Arithmetic Operations
    /// - Gas: 5
    /// - Stack consumed elements: 2
    /// - Stack produced elements: 1
    /// # Arguments
    /// * `self` - the execution context
    /// # TODO
    /// - Implement me.
    fn exec_mod(ref self: ExecutionContext) {}

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
    /// # TODO
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
    /// # TODO
    /// - Implement me.
    fn exec_addmod(ref self: ExecutionContext) {}

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
    fn exec_mulmod(ref self: ExecutionContext) {}

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
    fn exec_exp(ref self: ExecutionContext) {}

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
    /// # TODO
    /// - Implement me.
    fn exec_signextend(ref self: ExecutionContext) {}
}
