use evm::instructions::BlockInformationTrait;
use evm::context::BoxDynamicExecutionContextDestruct;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_execution_context;
use starknet::testing::{set_block_timestamp, set_block_number};

#[test]
#[available_gas(20000000)]
fn test_block_timestamp_set_to_1692873993() {
    // Given
    let mut ctx = setup_execution_context();
    // 24/08/2023 12h46 33s
    // If not set the default timestamp is 0.
    set_block_timestamp(1692873993);
    // When
    ctx.exec_timestamp();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 1692873993, 'stack top should be 1692873993');
}

#[test]
#[available_gas(20000000)]
fn test_block_number_set_to_32() {
    // Given
    let mut ctx = setup_execution_context();
    // If not set the default block number is 0.
    set_block_number(32);
    // When
    ctx.exec_number();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 32, 'stack top should be 32');
}
