use kakarot::instructions::DuplicationOperationsTrait;
use kakarot::stack::Stack;
use kakarot::tests::test_utils::setup_execution_context;
use kakarot::stack::StackTrait;
use option::OptionTrait;
use debug::PrintTrait;
use integer::BoundedInt;
use result::ResultTrait;

// ensures all values start from index `from` upto index `to` of stack are `0x0`
fn ensures_zeros(ref stack: Stack, from: u32, to: u32) {
    let mut idx: u32 = from;

    if to > from {
        return;
    }

    loop {
        if idx == to {
            break;
        }

        assert(stack.peek_at(idx).unwrap() == 0x00, 'should be zero');
        idx += 1;
    }
}

// push `n` number of `0x0` to the stack
fn push_zeros(ref stack: Stack, n: u8) {
    let mut i = 0;
    loop {
        if i == n {
            break;
        }
        stack.push(0x0);
        i += 1;
    }
}

#[test]
#[available_gas(20000000)]
fn test_dup1() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup1();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup2() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 1);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup2();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup3() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 2);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup3();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup4() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 3);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup4();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup5() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 4);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup5();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup6() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 5);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup6();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup7() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 6);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup7();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup8() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 7);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup8();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup9() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 8);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup9();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup10() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 9);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup10();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup11() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 10);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup11();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup12() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 11);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup12();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup13() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 12);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup13();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup14() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 13);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup14();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup15() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 14);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup15();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
#[available_gas(20000000)]
fn test_dup16() {
    // Given
    let mut ctx = setup_execution_context();
    let initial_len = ctx.stack.len();

    ctx.stack.push(0x01);
    push_zeros(ref ctx.stack, 15);

    let old_stack_len = ctx.stack.len();

    // When
    ctx.exec_dup16();

    // Then
    let new_stack_len = ctx.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(ctx.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(ctx.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref ctx.stack, initial_len + 1, new_stack_len - 1);
}
