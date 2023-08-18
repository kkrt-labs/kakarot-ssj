use kakarot::instructions::ComparisonAndBitwiseOperationsTrait;
use kakarot::tests::test_utils::setup_execution_context;
use kakarot::stack::StackTrait;
use option::OptionTrait;
use debug::PrintTrait;


#[test]
#[available_gas(20000000)]
fn test_xor_different_pair() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0b010101);
    ctx.stack.push(0b101010);

    // When
    ctx.exec_xor();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0b111111, 'stack top should be 0xFF');
}

#[test]
#[available_gas(20000000)]
fn test_xor_same_pair() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0b000111);
    ctx.stack.push(0b000111);

    // When
    ctx.exec_xor();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
}

#[test]
#[available_gas(20000000)]
fn test_xor_half_same_pair() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0b111000);
    ctx.stack.push(0b000000);

    // When
    ctx.exec_xor();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0b111000, 'stack top should be 0xFF');
}
