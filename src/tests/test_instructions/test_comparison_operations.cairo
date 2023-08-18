use kakarot::instructions::ComparisonAndBitwiseOperationsTrait;
use kakarot::tests::test_utils::setup_execution_context;
use kakarot::stack::StackTrait;
use option::OptionTrait;
use debug::PrintTrait;
use integer::BoundedInt;

#[test]
#[available_gas(20000000)]
fn test_and_zero_and_max() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x00);
    ctx.stack.push(BoundedInt::<u256>::max());

    // When
    ctx.exec_and();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
}

#[test]
#[available_gas(20000000)]
fn test_and_max_and_max() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max());
    ctx.stack.push(BoundedInt::<u256>::max());

    // When
    ctx.exec_and();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == BoundedInt::<u256>::max(),
        'stack top should be 0xFF...FFF'
    );
}

#[test]
#[available_gas(20000000)]
fn test_and_two_random_uint() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xAB8765432DCBA98765410F149E87610FDCBA98765432543217654DCBA93210F8);
    ctx.stack.push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210);

    // When
    ctx.exec_and();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xAA8420002440200064400A1016042000DC989810541010101644088820101010,
        'stack top is wrong'
    );
}


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
