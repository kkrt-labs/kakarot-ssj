use evm::context::BoxDynamicExecutionContextDestruct;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_execution_context;
use array::ArrayTrait;
use evm::context::ExecutionContextTrait;
use evm::instructions::exchange_operations::ExchangeOperationsTrait;
use core::result::ResultTrait;


#[test]
#[available_gas(20000000)]
fn test_swap1() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap1();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be now [1]');
}

#[test]
#[available_gas(20000000)]
fn test_swap2() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap2();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be now[2]');
}

#[test]
#[available_gas(20000000)]
fn test_swap3() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap3();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be now [3]');
}

#[test]
#[available_gas(20000000)]
fn test_swap4() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap4();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [4]');
}


#[test]
#[available_gas(20000000)]
fn test_swap5() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap5();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [5]');
}

#[test]
#[available_gas(20000000)]
fn test_swap6() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap6();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [6]');
}


#[test]
#[available_gas(20000000)]
fn test_swap7() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap7();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [7]');
}

#[test]
#[available_gas(20000000)]
fn test_swap8() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap8();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [8]');
}


#[test]
#[available_gas(20000000)]
fn test_swap9() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap9();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [9]');
}

#[test]
#[available_gas(20000000)]
fn test_swap10() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap10();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [10]');
}

#[test]
#[available_gas(20000000)]
fn test_swap11() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap11();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [11]');
}

#[test]
#[available_gas(20000000)]
fn test_swap12() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap12();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [12]');
}

#[test]
#[available_gas(20000000)]
fn test_swap13() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap13();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [13]');
}

#[test]
#[available_gas(20000000)]
fn test_swap14() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap14();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [14]');
}

#[test]
#[available_gas(20000000)]
fn test_swap15() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap15();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [15]');
}

#[test]
#[available_gas(20000000)]
fn test_swap16() {
    let mut ctx = setup_execution_context();
    ctx.stack.push(2).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.stack.push(3).unwrap();
    ctx.exec_swap16();
    assert(ctx.stack.peek().unwrap() == 2, 'Top should be  now [16]');
}
