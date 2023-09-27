use evm::instructions::ComparisonAndBitwiseOperationsTrait;
use evm::tests::test_utils::setup_execution_context;
use evm::stack::StackTrait;

use debug::PrintTrait;
use integer::BoundedInt;
use evm::context::BoxDynamicExecutionContextDestruct;

#[test]
#[available_gas(20000000)]
fn test_eq_same_pair() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210).unwrap();
    ctx.stack.push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210).unwrap();

    // When
    ctx.exec_eq();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x01, 'stack top should be 0x01');
}

#[test]
#[available_gas(20000000)]
fn test_eq_different_pair() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xAB8765432DCBA98765410F149E87610FDCBA98765432543217654DCBA93210F8).unwrap();
    ctx.stack.push(0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210).unwrap();

    // When
    ctx.exec_eq();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
}

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
fn test_is_zero_true() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x00).unwrap();

    // When
    ctx.exec_iszero();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x01, 'stack top should be true');
}

#[test]
#[available_gas(20000000)]
fn test_is_zero_false() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x01).unwrap();

    // When
    ctx.exec_iszero();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be false');
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
fn test_exec_shl() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xff00000000000000000000000000000000000000000000000000000000000000).unwrap();
    ctx.stack.push(4_u256).unwrap();

    // When
    ctx.exec_shl();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(
        ctx
            .stack
            .peek()
            .unwrap() == 0xf000000000000000000000000000000000000000000000000000000000000000,
        'stack top should be 0xf00000...'
    );
}

#[test]
#[available_gas(20000000)]
fn test_exec_shl_wrapping() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0xff00000000000000000000000000000000000000000000000000000000000000).unwrap();
    ctx.stack.push(256_u256).unwrap();

    // When
    ctx.exec_shl();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0, 'if shift > 255 should return 0');
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

#[test]
#[available_gas(220000000)]
fn test_exec_slt() {
    // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_slt.json
    assert_slt(0x0, 0x0, 0);
    assert_slt(0x0, 0x1, 0);
    assert_slt(0x0, 0x5, 0);
    assert_slt(0x0, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0);
    assert_slt(0x0, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
    assert_slt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000000, 1);
    assert_slt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000001, 1);
    assert_slt(0x0, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 1);
    assert_slt(0x0, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
    assert_slt(0x1, 0x0, 1);
    assert_slt(0x1, 0x1, 0);
    assert_slt(0x1, 0x5, 0);
    assert_slt(0x1, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0);
    assert_slt(0x1, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
    assert_slt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000000, 1);
    assert_slt(0x1, 0x8000000000000000000000000000000000000000000000000000000000000001, 1);
    assert_slt(0x1, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 1);
    assert_slt(0x1, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
    assert_slt(0x5, 0x0, 1);
    assert_slt(0x5, 0x1, 1);
    assert_slt(0x5, 0x5, 0);
    assert_slt(0x5, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0);
    assert_slt(0x5, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
    assert_slt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000000, 1);
    assert_slt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000001, 1);
    assert_slt(0x5, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 1);
    assert_slt(0x5, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
    assert_slt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x0, 1);
    assert_slt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x1, 1);
    assert_slt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x5, 1);
    assert_slt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_slt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        1
    );
    assert_slt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        1
    );
    assert_slt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        1
    );
    assert_slt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_slt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 1);
    assert_slt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 1);
    assert_slt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 1);
    assert_slt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        1
    );
    assert_slt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        1
    );
    assert_slt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        1
    );
    assert_slt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        1
    );
    assert_slt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_slt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x0, 0);
    assert_slt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x1, 0);
    assert_slt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x5, 0);
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x0, 0);
    assert_slt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x1, 0);
    assert_slt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x5, 0);
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        1
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_slt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x0, 0);
    assert_slt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x1, 0);
    assert_slt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x5, 0);
    assert_slt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_slt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        1
    );
    assert_slt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        1
    );
    assert_slt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_slt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 0);
    assert_slt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 0);
    assert_slt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 0);
    assert_slt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_slt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_slt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        1
    );
    assert_slt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        1
    );
    assert_slt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        1
    );
    assert_slt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
}

fn assert_slt(b: u256, a: u256, expected: u256) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(b);
    ctx.stack.push(a);

    // When
    ctx.exec_slt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == expected, 'slt failed');
}

#[test]
#[available_gas(220000000)]
fn test_exec_sgt() {
    // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_sgt.json
    assert_sgt(0x0, 0x0, 0);
    assert_sgt(0x0, 0x1, 1);
    assert_sgt(0x0, 0x5, 1);
    assert_sgt(0x0, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1);
    assert_sgt(0x0, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
    assert_sgt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000000, 0);
    assert_sgt(0x0, 0x8000000000000000000000000000000000000000000000000000000000000001, 0);
    assert_sgt(0x0, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0);
    assert_sgt(0x0, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
    assert_sgt(0x1, 0x0, 0);
    assert_sgt(0x1, 0x1, 0);
    assert_sgt(0x1, 0x5, 1);
    assert_sgt(0x1, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1);
    assert_sgt(0x1, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
    assert_sgt(0x1, 0x8000000000000000000000000000000000000000000000000000000000000000, 0);
    assert_sgt(0x1, 0x8000000000000000000000000000000000000000000000000000000000000001, 0);
    assert_sgt(0x1, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0);
    assert_sgt(0x1, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
    assert_sgt(0x5, 0x0, 0);
    assert_sgt(0x5, 0x1, 0);
    assert_sgt(0x5, 0x5, 0);
    assert_sgt(0x5, 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 1);
    assert_sgt(0x5, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 1);
    assert_sgt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000000, 0);
    assert_sgt(0x5, 0x8000000000000000000000000000000000000000000000000000000000000001, 0);
    assert_sgt(0x5, 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0);
    assert_sgt(0x5, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0);
    assert_sgt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x0, 0);
    assert_sgt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x1, 0);
    assert_sgt(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe, 0x5, 0);
    assert_sgt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_sgt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_sgt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_sgt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_sgt(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_sgt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 0);
    assert_sgt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 0);
    assert_sgt(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 0);
    assert_sgt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0
    );
    assert_sgt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_sgt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_sgt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_sgt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_sgt(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
    assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x0, 1);
    assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x1, 1);
    assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000000, 0x5, 1);
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x0, 1);
    assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x1, 1);
    assert_sgt(0x8000000000000000000000000000000000000000000000000000000000000001, 0x5, 1);
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        1
    );
    assert_sgt(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x0, 1);
    assert_sgt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x1, 1);
    assert_sgt(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb, 0x5, 1);
    assert_sgt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        1
    );
    assert_sgt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_sgt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_sgt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_sgt(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x0, 1);
    assert_sgt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x1, 1);
    assert_sgt(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0x5, 1);
    assert_sgt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        1
    );
    assert_sgt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        1
    );
    assert_sgt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0
    );
    assert_sgt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0
    );
    assert_sgt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0
    );
    assert_sgt(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0
    );
}

fn assert_sgt(b: u256, a: u256, expected: u256) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(b);
    ctx.stack.push(a);

    // When
    ctx.exec_sgt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == expected, 'sgt failed');
}

#[test]
#[available_gas(30000000)]
fn test_exec_shr() {
    // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_shr.json
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000001
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000005
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000002
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x4000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0400000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x4000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0400000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_shr(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
}

fn assert_shr(a: u256, b: u256, expected: u256) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(a).unwrap();
    ctx.stack.push(b).unwrap();

    // When
    ctx.exec_shr();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == expected, 'shr failed');
}

#[test]
#[available_gas(30000000)]
fn test_exec_sar() {
    // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_sar.json
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000001
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000005
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000002
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xc000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xfc00000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0x8000000000000000000000000000000000000000000000000000000000000001
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xc000000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xfc00000000000000000000000000000000000000000000000000000000000000
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x0000000000000000000000000000000000000000000000000000000000000005,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000000,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0x8000000000000000000000000000000000000000000000000000000000000001,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    assert_sar(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
}

fn assert_sar(a: u256, b: u256, expected: u256) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(a).unwrap();
    ctx.stack.push(b).unwrap();

    // When

    ctx.exec_sar();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == expected, 'sar failed');
}

#[test]
#[available_gas(20000000)]
fn test__exec_or__should_pop_0_and_1_and_push_0xCD__when_0_is_0x89_and_1_is_0xC5() {
    //Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x89);
    ctx.stack.push(0xC5);

    //When
    ctx.exec_or();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0xCD, 'stack top should be 0xCD');
}

#[test]
#[available_gas(20000000)]
fn test_or_true() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x01).unwrap();
    ctx.stack.push(0x00).unwrap();

    // When
    ctx.exec_or();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x01, 'stack top should be 0x01');
}

#[test]
#[available_gas(20000000)]
fn test_or_false() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(0x00).unwrap();
    ctx.stack.push(0x00).unwrap();

    // When
    ctx.exec_or();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be 0x00');
}


#[test]
#[available_gas(20000000)]
fn test_exec_lt_true() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(10_u256).unwrap();
    ctx.stack.push(9_u256).unwrap();

    // When
    ctx.exec_lt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x01, 'stack top should be true');
}

#[test]
#[available_gas(20000000)]
fn test_exec_lt_false() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(10_u256).unwrap();
    ctx.stack.push(20_u256).unwrap();

    // When
    ctx.exec_lt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be false');
}

#[test]
#[available_gas(20000000)]
fn test_exec_lt_false_eq() {
    // Given
    let mut ctx = setup_execution_context();
    ctx.stack.push(10_u256).unwrap();
    ctx.stack.push(10_u256).unwrap();

    // When
    ctx.exec_lt();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 0x00, 'stack top should be false');
}
