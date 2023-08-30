use evm::instructions::ComparisonAndBitwiseOperationsTrait;
use evm::tests::test_utils::setup_execution_context;
use evm::stack::StackTrait;
use option::OptionTrait;
use debug::PrintTrait;
use integer::BoundedInt;
use evm::context::BoxDynamicExecutionContextDestruct;

#[test]
#[available_gas(20000000)]
fn test_and_zero_and_max() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x00).unwrap();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();

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
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();

    // When
    ctx.exec_and();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == BoundedInt::<u256>::max(), 'stack top should be 0xFF...FFF'
    );
}

#[test]
#[available_gas(20000000)]
fn test_and_two_random_uint() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xAB8765432DCBA98765410F149E87610FDCBA98765432543217654DCBA93210F8).unwrap();
    ctx.stack.push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210).unwrap();

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
    ctx.stack.push(0b010101).unwrap();
    ctx.stack.push(0b101010).unwrap();

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
    ctx.stack.push(0b000111).unwrap();
    ctx.stack.push(0b000111).unwrap();

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
    ctx.stack.push(0b111000).unwrap();
    ctx.stack.push(0b000000).unwrap();

    // When
    ctx.exec_xor();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0b111000, 'stack top should be 0xFF');
}


#[test]
#[available_gas(20000000)]
fn test_not_zero() {
    // Given 
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x00).unwrap();

    // When
    ctx.exec_not();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx.stack.peek().unwrap() == BoundedInt::<u256>::max(), 'stack top should be 0xFFF..FFFF'
    );
}

#[test]
#[available_gas(20000000)]
fn test_not_max_uint() {
    // Given 
    let mut ctx = setup_execution_context();
    ctx.stack.push(BoundedInt::<u256>::max()).unwrap();

    // When
    ctx.exec_not();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
}

#[test]
#[available_gas(20000000)]
fn test_not_random_uint() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF1234).unwrap();

    // When
    ctx.exec_not();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xEDCBA9876543210EDCBA9876543210EDCBA9876543210EDCBA9876543210EDCB,
        'stack top should be 0x7553'
    );
}

#[test]
#[available_gas(20000000)]
fn test_is_zero() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x00).unwrap();
    
    // When
    ctx.exec_iszero();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x01, 'stack top should be 0x01');
}

#[test]
#[available_gas(20000000)]
fn test_byte_random_u256() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xf7ec8b2ea4a6b7fd5f4ed41b66197fcc14c4a37d68275ea151d899bb4d7c2ae7).unwrap();
    ctx.stack.push(0x08).unwrap();

    // When
    ctx.exec_byte();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x5f, 'stack top should be 0x22');
}

#[test]
#[available_gas(20000000)]
fn test_byte_offset_out_of_range() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x01be893aefcfa1592f60622b80d45c2db74281d2b9e10c14b0f6ce7c8f58e209).unwrap();
    ctx.stack.push(32_u256).unwrap();

    // When
    ctx.exec_byte();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
}

#[test]
#[available_gas(20000000)]
fn test_exec_gt_true() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(9_u256).unwrap();
    ctx.stack.push(10_u256).unwrap();

    // When
    ctx.exec_gt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 1, 'stack top should be 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_gt_false() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(10_u256).unwrap();
    ctx.stack.push(9_u256).unwrap();

    // When
    ctx.exec_gt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_exec_gt_false_equal() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(10_u256).unwrap();
    ctx.stack.push(10_u256).unwrap();

    // When
    ctx.exec_gt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'stack top should be 0');
}
