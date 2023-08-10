use kakarot::tests::test_utils::setup_execution_context;
use kakarot::instructions::StopAndArithmeticOperationsTrait;
use kakarot::stack::StackTrait;
use option::OptionTrait;
use integer::BoundedInt;

#[test]
#[available_gas(20000000)]
fn test__exec_stop() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_stop();

    // Then
    assert(ctx.stopped, 'ctx not stopped');
}

#[test]
#[available_gas(20000000)]
fn test__exec_add() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(1);
    ctx.stack.push(2);
    ctx.stack.push(3);

    // When
    ctx.exec_add();

    // Then
    assert(ctx.stack.len == 2, 'stack should have two elems');
    assert(ctx.stack.peek().unwrap() == 5, 'stack top should be 3+2');
    assert(ctx.stack.peek_at(1) == 1, 'stack[1] should be 1');
}

#[test]
#[available_gas(20000000)]
fn test__exec_add_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(1);

    // When
    ctx.exec_add();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
#[available_gas(20000000)]
fn test__exec_mul() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(4);
    ctx.stack.push(5);

    // When
    ctx.exec_mul();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 20, 'stack top should be 4*5');
}

#[test]
#[available_gas(20000000)]
fn test__exec_mul_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(2);

    // When
    ctx.exec_mul();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == BoundedInt::<u256>::max() - 1, 'expected MAX_U256 -1');
}

#[test]
#[available_gas(20000000)]
fn test__exec_sub() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(7);
    ctx.stack.push(10);

    // When
    ctx.exec_sub();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 3, 'stack top should be 10-7');
}

#[test]
#[available_gas(20000000)]
fn test__exec_sub_underflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(1);
    ctx.stack.push(0);

    // When
    ctx.exec_sub();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == BoundedInt::<u256>::max(), 'stack top should be MAX_U256');
}


#[test]
#[available_gas(20000000)]
fn test__exec_div() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(4);
    ctx.stack.push(100);

    // When
    ctx.exec_div();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 25, 'stack top should be 100/4');
}

#[test]
#[available_gas(20000000)]
fn test__exec_mod() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(6);
    ctx.stack.push(100);

    // When
    ctx.exec_mod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 4, 'stack top should be 100%6');
}

#[test]
#[available_gas(20000000)]
fn test__exec_addmod() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(7);
    ctx.stack.push(10);
    ctx.stack.push(20);

    // When
    ctx.exec_addmod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 2, 'stack top should be (10+20)%7');
}

#[test]
#[available_gas(20000000)]
fn test__exec_addmod_overflow() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(101);
    ctx.stack.push(BoundedInt::<u256>::max());

    // When
    ctx.exec_addmod();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 100, 'stack top should be 100');
}

