use evm::context::BoxDynamicExecutionContextDestruct;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_execution_context;
use array::ArrayTrait;
use evm::context::ExecutionContextTrait;
use evm::instructions::exchange_operations::ExchangeOperationsTrait;
use core::result::ResultTrait;


#[test]
#[available_gas(20000000)]
fn test_exec_swap1() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap1();

    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap2() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap2();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap3() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap3();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap4() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap4();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap5() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap5();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap6() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap6();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap7() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap7();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap8() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap8();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap9() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap9();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap10() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap10();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap11() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap11();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap12() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap12();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap13() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap13();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap14() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap14();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap15() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap15();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap16() {
    let mut ctx = setup_execution_context();
    // given
    ctx.stack.push(0xf).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(0).unwrap();
    ctx.stack.push(1).unwrap();
    ctx.exec_swap16();
    assert(ctx.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
}
