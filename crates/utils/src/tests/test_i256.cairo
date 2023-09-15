use utils::i256::i256;
use utils::math::Bitshift;
use integer::BoundedInt;

#[test]
#[available_gas(20000000)]
fn test_i256_eq() {
    let val: i256 = 1_u256.into();

    assert(val == 1_u256.into(), 'i256 should be eq');
}

#[test]
#[available_gas(20000000)]
fn test_i256_ne() {
    let val: i256 = 1_u256.into();

    assert(val != 2_u256.into(), 'i256 should be ne');
}

#[test]
#[available_gas(20000000)]
fn test_i256_positive() {
    let val: i256 = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256.into();

    assert(val > 0_u256.into(), 'i256 should be positive');
}

#[test]
#[available_gas(20000000)]
fn test_i256_negative() {
    let val: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(val < 0_u256.into(), 'i256 should be negative');
}

#[test]
#[available_gas(20000000)]
fn test_lt_positive_positive() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = 2_u256.into();

    assert(lhs < rhs == true, 'lhs should be lt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_lt_negative_negative() {
    let lhs: i256 = (BoundedInt::<u256>::max() - 1).into(); // -2
    let rhs: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(lhs < rhs == true, 'lhs should be lt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_lt_negative_positive() {
    let lhs: i256 = BoundedInt::<u256>::max().into(); // -1
    let rhs: i256 = 1_u256.into();

    assert(lhs < rhs == true, 'lhs should be lt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_lt_positive_negative() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(lhs < rhs == false, 'lhs should not be lt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_lt_equals() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = 1_u256.into();

    assert(lhs < rhs == false, 'lhs should not be lt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_le_positive_positive() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = 2_u256.into();

    assert(lhs <= rhs == true, 'lhs should be le rhs');
}

#[test]
#[available_gas(20000000)]
fn test_le_negative_negative() {
    let lhs: i256 = (BoundedInt::<u256>::max() - 1).into(); // -2
    let rhs: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(lhs <= rhs == true, 'lhs should be le rhs');
}

#[test]
#[available_gas(20000000)]
fn test_le_negative_positive() {
    let lhs: i256 = BoundedInt::<u256>::max().into(); // -1
    let rhs: i256 = 1_u256.into();

    assert(lhs <= rhs == true, 'lhs should be le rhs');
}

#[test]
#[available_gas(20000000)]
fn test_le_positive_negative() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(lhs <= rhs == false, 'lhs should not be le rhs');
}

#[test]
#[available_gas(20000000)]
fn test_le_equals() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = 1_u256.into();

    assert(lhs <= rhs == true, 'lhs should be le rhs');
}

#[test]
#[available_gas(20000000)]
fn test_gt_positive_positive() {
    let lhs: i256 = 2_u256.into();
    let rhs: i256 = 1_u256.into();

    assert(lhs > rhs == true, 'lhs should be gt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_gt_negative_negative() {
    let lhs: i256 = BoundedInt::<u256>::max().into(); // -1
    let rhs: i256 = (BoundedInt::<u256>::max() - 1).into(); // -2

    assert(lhs > rhs == true, 'lhs should be gt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_gt_negative_positive() {
    let lhs: i256 = BoundedInt::<u256>::max().into(); // -1
    let rhs: i256 = 1_u256.into();

    assert(lhs > rhs == false, 'lhs should not be gt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_gt_positive_negative() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(lhs > rhs == true, 'lhs should be gt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_gt_equals() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = 1_u256.into();

    assert(lhs > rhs == false, 'lhs should not be gt rhs');
}

#[test]
#[available_gas(20000000)]
fn test_ge_positive_positive() {
    let lhs: i256 = 2_u256.into();
    let rhs: i256 = 1_u256.into();

    assert(lhs >= rhs == true, 'lhs should be ge rhs');
}

#[test]
#[available_gas(20000000)]
fn test_ge_negative_negative() {
    let lhs: i256 = BoundedInt::<u256>::max().into(); // -1
    let rhs: i256 = (BoundedInt::<u256>::max() - 1).into(); // -2

    assert(lhs >= rhs == true, 'lhs should be ge rhs');
}

#[test]
#[available_gas(20000000)]
fn test_ge_negative_positive() {
    let lhs: i256 = BoundedInt::<u256>::max().into(); // -1
    let rhs: i256 = 1_u256.into();

    assert(lhs >= rhs == false, 'lhs should not be ge rhs');
}

#[test]
#[available_gas(20000000)]
fn test_ge_positive_negative() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = BoundedInt::<u256>::max().into(); // -1

    assert(lhs >= rhs == true, 'lhs should be ge rhs');
}

#[test]
#[available_gas(20000000)]
fn test_ge_equals() {
    let lhs: i256 = 1_u256.into();
    let rhs: i256 = 1_u256.into();

    assert(lhs >= rhs == true, 'lhs should be ge rhs');
}

#[test]
#[available_gas(20000000)]
fn test_shr_positive() {
    let value: i256 = 5_u256.into();
    let shift: i256 = 1_u256.into();

    let result = value.shr(shift);
    assert(result == 2_u256.into(), '5 >> 1 should be 2');
}

#[test]
#[available_gas(20000000)]
fn test_shr_negative() {
    let value: i256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0_u256
        .into();
    let shift: i256 = 1_u256.into();

    let result = value.shr(shift);
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8_u256.into(),
        '0xF..F0 >> 1 should be 0xF..F8'
    );
}

#[test]
#[available_gas(20000000)]
fn test_shr_positive_out_of_bounds_should_be_zero() {
    let value: i256 = 1_u256.into();
    let shift: i256 = 2_u256.into();

    let result = value.shr(shift);
    assert(result == 0_u256.into(), '1 >> 2 should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_shr_negative_out_of_bounds_should_be_minus_1() {
    let value: i256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u256
        .into();
    let shift: i256 = 2_u256.into();

    let result = value.shr(shift);
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into(),
        '0xF..FE >> 2 should be -1'
    );
}

#[test]
#[available_gas(20000000)]
fn test_shr_positive_shift_256_should_be_zero() {
    let value: i256 = 1_u256.into();
    let shift: i256 = 256_u256.into();

    let result = value.shr(shift);
    assert(result == 0_u256.into(), '1 >> 256 should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_shr_negative_shift_256_should_be_minus_1() {
    let value: i256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u256
        .into();
    let shift: i256 = 256_u256.into();

    let result = value.shr(shift);
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into(),
        '0xF..FE >> 256 should be -1'
    );
}

#[test]
#[available_gas(20000000)]
fn test_shr_positive_shift_more_than_256_should_be_zero() {
    let value: i256 = 1_u256.into();
    let shift: i256 = 300_u256.into();

    let result = value.shr(shift);
    assert(result == 0_u256.into(), '1 >> 300 should be 0');
}

#[test]
#[available_gas(20000000)]
fn test_shr_negative_shift_more_than_256_should_be_minus_1() {
    let value: i256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u256
        .into();
    let shift: i256 = 300_u256.into();

    let result = value.shr(shift);
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into(),
        '0xF..FE >> 300 should be -1'
    );
}

#[test]
#[available_gas(20000000)]
fn test_shl_positive() {
    let value: i256 = 2_u256.into();
    let shift: i256 = 1_u256.into();

    let result = value.shl(shift);
    assert(result == 4_u256.into(), '2 << 1 should be 4');
}

#[test]
#[available_gas(20000000)]
fn test_shl_negative() {
    let value: i256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0_u256
        .into();
    let shift: i256 = 1_u256.into();

    let result = value.shl(shift);
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE0_u256.into(),
        '0xF..F0 << 1 should be 0xF..E0'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_shl_positive_out_of_bounds_should_panic() {
    let value: i256 = 512_u256.into();
    let shift: i256 = 250_u256.into();

    let result = value.shl(shift);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256_mul Overflow',))]
fn test_shl_negative_out_of_bounds_should_panic() {
    let value: i256 = 0xC000000000000000000000000000000000000000000000000000000000000000_u256
        .into();
    let shift: i256 = 2_u256.into();

    let result = value.shl(shift);
}
