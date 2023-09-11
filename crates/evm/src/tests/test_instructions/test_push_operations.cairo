use evm::instructions::PushOperationsTrait;
use evm::context::BoxDynamicExecutionContextDestruct;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_execution_context_with_bytecode;

use evm::context::ExecutionContextTrait;

fn get_n_0xFF(mut n: u8) -> Span<u8> {
    let mut array: Array<u8> = ArrayTrait::new();
    loop {
        if n == 0 {
            break;
        }
        array.append(0xFF);
        n -= 1;
    };
    array.span()
}

#[test]
#[available_gas(20000000)]
fn test_push0() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(0));
    // When
    ctx.exec_push0();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push1() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(1));
    // When
    ctx.exec_push1();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push2() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(2));
    // When
    ctx.exec_push2();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push3() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(3));
    // When
    ctx.exec_push3();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push4() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(4));
    // When
    ctx.exec_push4();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push5() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(5));
    // When
    ctx.exec_push5();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push6() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(6));
    // When
    ctx.exec_push6();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push7() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(7));
    // When
    ctx.exec_push7();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFF, 'invalid stack top');
}


#[test]
#[available_gas(20000000)]
fn test_push8() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(8));
    // When
    ctx.exec_push8();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push9() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(9));
    // When
    ctx.exec_push9();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push10() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(10));
    // When
    ctx.exec_push10();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push11() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(11));
    // When
    ctx.exec_push11();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push12() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(12));
    // When
    ctx.exec_push12();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push13() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(13));
    // When
    ctx.exec_push13();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push14() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(14));
    // When
    ctx.exec_push14();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push15() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(15));
    // When
    ctx.exec_push15();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push16() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(16));
    // When
    ctx.exec_push16();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push17() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(17));
    // When
    ctx.exec_push17();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
#[available_gas(20000000)]
fn test_push18() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(18));
    // When
    ctx.exec_push18();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top'
    );
}
#[test]
#[available_gas(20000000)]
fn test_push19() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(19));
    // When
    ctx.exec_push19();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push20() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(20));
    // When
    ctx.exec_push20();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push21() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(21));
    // When
    ctx.exec_push21();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push22() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(22));
    // When
    ctx.exec_push22();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}
#[test]
#[available_gas(20000000)]
fn test_push23() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(23));
    // When
    ctx.exec_push23();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}
#[test]
#[available_gas(20000000)]
fn test_push24() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(24));
    // When
    ctx.exec_push24();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push25() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(25));
    // When
    ctx.exec_push25();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push26() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(26));
    // When
    ctx.exec_push26();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push27() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(27));
    // When
    ctx.exec_push27();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push28() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(28));
    // When
    ctx.exec_push28();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push29() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(29));
    // When
    ctx.exec_push29();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push30() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(30));
    // When
    ctx.exec_push30();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push31() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(31));
    // When
    ctx.exec_push31();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
#[available_gas(20000000)]
fn test_push32() {
    // Given
    let mut ctx = setup_execution_context_with_bytecode(get_n_0xFF(32));
    // When
    ctx.exec_push32();
    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}
