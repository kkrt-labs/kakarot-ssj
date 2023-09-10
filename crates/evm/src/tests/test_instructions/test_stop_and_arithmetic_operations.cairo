use core::result::ResultTrait;
use evm::tests::test_utils::setup_execution_context;
use evm::instructions::StopAndArithmeticOperationsTrait;
use evm::stack::StackTrait;
use evm::context::ExecutionContextTrait;
use option::OptionTrait;
use integer::BoundedInt;
use traits::{TryInto, Into};
use evm::context::BoxDynamicExecutionContextDestruct;

#[test]
#[available_gas(20000000)]
fn test_exec_stop() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_stop();

    // Then
    assert(ctx.stopped(), 'ctx not stopped');
}

#[test]
#[available_gas(20000000)]
fn test_exec_add() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(1).unwrap();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();

    // When
    ctx.exec_add();

    // Then
    assert(ctx.stack.len == 2, 'stack should have two elems');
    assert(ctx.stack.peek().unwrap() == 5, 'stack top should be 3+2');
    assert(ctx.stack.peek_at(1).unwrap() == 1, 'stack[1] should be 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_add_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();
    ctx.stack.push(1).unwrap();

    // When
    ctx.exec_add();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mul() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(4).unwrap();
    ctx.stack.push(5).unwrap();

    // When
    ctx.exec_mul();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 20, 'stack top should be 4*5');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mul_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();
    ctx.stack.push(2).unwrap();

    // When
    ctx.exec_mul();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == BoundedInt::<u256>::max() - 1, 'expected MAX_U256 -1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sub() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(7).unwrap();
    ctx.stack.push(10).unwrap();

    // When
    ctx.exec_sub();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 3, 'stack top should be 10-7');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sub_underflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(1).unwrap();
    ctx.stack.push(0).unwrap();

    // When
    ctx.exec_sub();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == BoundedInt::<u256>::max(), 'stack top should be MAX_U256');
}


#[test]
#[available_gas(20000000)]
fn test_exec_div() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(4).unwrap();
    ctx.stack.push(100).unwrap();

    // When
    ctx.exec_div();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 25, 'stack top should be 100/4');
}

#[test]
#[available_gas(20000000)]
fn test_exec_div_by_zero() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(100).unwrap();

    // When
    ctx.exec_div();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sdiv_pos() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(5).unwrap();
    ctx.stack.push(10).unwrap();

    // When
    ctx.exec_sdiv(); // 10 / 5

    // Then
    assert(ctx.stack.len() == 1, 'stack len should be 1');
    assert(ctx.stack.peek().unwrap() == 2, 'ctx not stopped');
}

#[test]
#[available_gas(20000000)]
fn test__exec_sdiv_neg() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::max()).unwrap();
    ctx.stack.push(2).unwrap();

    // When
    ctx.exec_sdiv(); // 2 / -1

    // Then
    assert(ctx.stack.len() == 1, 'stack len should be 1');
    assert(ctx.stack.peek().unwrap() == BoundedInt::max() - 1, 'ctx not stopped');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sdiv_by_0() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(10).unwrap();

    // When
    ctx.exec_sdiv();

    // Then
    assert(ctx.stack.len() == 1, 'stack len should be 1');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mod() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(6).unwrap();
    ctx.stack.push(100).unwrap();

    // When
    ctx.exec_mod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 4, 'stack top should be 100%6');
}

#[test]
#[available_gas(20000000)]
fn test_exec_mod_by_zero() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(100).unwrap();

    // When
    ctx.exec_smod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 100%6');
}

#[test]
#[available_gas(20000000)]
fn test_exec_smod() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(10).unwrap();

    // When
    ctx.exec_smod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 1, 'stack top should be 10%3 = 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_smod_neg() {
    // Given
    let mut ctx = setup_execution_context();
    ctx
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD)
        .unwrap(); // -3
    ctx
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8)
        .unwrap(); // -8

    // When
    ctx.exec_smod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
        'stack top should be -8%-3 = -2'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_smod_zero() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(10).unwrap();

    // When
    ctx.exec_mod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_exec_addmod() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(7).unwrap();
    ctx.stack.push(10).unwrap();
    ctx.stack.push(20).unwrap();

    // When
    ctx.exec_addmod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 2, 'stack top should be (10+20)%7');
}

#[test]
#[available_gas(20000000)]
fn test_exec_addmod_by_zero() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(10).unwrap();
    ctx.stack.push(20).unwrap();

    // When
    ctx.exec_addmod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_exec_addmod_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();

    // When
    ctx.exec_addmod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 2, 'stack top should be 2'
    ); // (MAX_U256 + 2) % 3 = (2^256 + 1) % 3 = 2
}

#[test]
#[available_gas(20000000)]
fn test_mulmod_basic() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(10).unwrap();
    ctx.stack.push(7).unwrap();
    ctx.stack.push(5).unwrap();

    // When
    ctx.exec_mulmod();

    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 5, 'stack top should be 5'); // (5 * 7) % 10 = 5
}

#[test]
#[available_gas(20000000)]
fn test_mulmod_zero_modulus() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(7).unwrap();
    ctx.stack.push(5).unwrap();

    ctx.exec_mulmod();

    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0'); // modulus is 0
}

#[test]
#[available_gas(20000000)]
fn test_mulmod_overflow() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(12).unwrap();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();

    ctx.exec_mulmod();

    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 9, 'stack top should be 1'
    ); // (MAX_U256 * MAX_U256) % 12 = 9
}

#[test]
#[available_gas(20000000)]
fn test_mulmod_zero() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(10).unwrap();
    ctx.stack.push(7).unwrap();
    ctx.stack.push(0).unwrap();

    ctx.exec_mulmod();

    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0'); // 0 * 7 % 10 = 0
}

#[test]
#[available_gas(20000000)]
fn test_exec_exp() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(10).unwrap();

    // When
    ctx.exec_exp();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 100, 'stack top should be 100');
}

#[test]
#[available_gas(20000000)]
fn test_exec_exp_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(BoundedInt::<u128>::max().into() + 1).unwrap();

    // When
    ctx.exec_exp();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0, 'stack top should be 0'
    ); // (2^128)^2 = 2^256 = 0 % 2^256
}

#[test]
#[available_gas(20000000)]
fn test_exec_signextend() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xFF).unwrap();
    ctx.stack.push(0x00).unwrap();

    // When
    ctx.exec_signextend();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'stack top should be MAX_u256 -1'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_signextend_no_effect() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x7F).unwrap();
    ctx.stack.push(0x00).unwrap();

    // When
    ctx.exec_signextend();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0x7F, 'stack top should be 0x7F'
    ); // The 248-th bit of x is 0, so the output is not changed.
}

#[test]
#[available_gas(20000000)]
fn test_exec_signextend_on_negative() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0001).unwrap();
    ctx.stack.push(0x01).unwrap(); // s = 15, v = 0

    // When
    ctx.exec_signextend();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0x01, 'stack top should be 0'
    ); // The 241-th bit of x is 0, so all bits before t are switched to 0
}

