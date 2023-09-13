use evm::instructions::SystemOperationsTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_execution_context;
use evm::instructions::MemoryOperationTrait;
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use utils::helpers::load_word;
use traits::Into;

#[test]
#[available_gas(20000000)]
fn test_exec_return() {
    // Given
    let mut ctx = setup_execution_context();
    // When
    ctx.stack.push(1000);
    ctx.stack.push(0);
    ctx.exec_mstore();

    ctx.stack.push(32);
    ctx.stack.push(0);
    assert(ctx.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(1000 == load_word(32, ctx.return_data()), 'Wrong return_data');
}

#[test]
#[available_gas(20000000)]
fn test_exec_return_with_offset() {
    // Given
    let mut ctx = setup_execution_context();
    // When
    ctx.stack.push(1);
    ctx.stack.push(0);
    ctx.exec_mstore();

    ctx.stack.push(32);
    ctx.stack.push(1);
    assert(ctx.exec_return().is_ok(), 'Exec return failed');

    // Then
    assert(256 == load_word(32, ctx.return_data()), 'Wrong return_data');
}
