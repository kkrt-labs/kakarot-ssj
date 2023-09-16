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
