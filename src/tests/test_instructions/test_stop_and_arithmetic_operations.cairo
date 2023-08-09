use kakarot::tests::test_utils::setup_execution_context;
use kakarot::instructions::StopAndArithmeticOperationsTrait;

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
