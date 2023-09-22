use utils::i256::{i256, i256_neg, i256_signed_div_rem};
use utils::math::Bitshift;
use integer::BoundedInt;

const MAX_SIGNED_VALUE: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
const MIN_SIGNED_VALUE: u256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

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
    let val: i256 = MAX_SIGNED_VALUE.into();

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
fn test_i256_neg() {
    let max_u256 = BoundedInt::<u256>::max();
    let x = i256_neg(1_u256.into());
    // 0000_0001 turns into 1111_1110 + 1 = 1111_1111
    assert(x.value.low == max_u256.low && x.value.high == max_u256.high, 'i256_neg failed.');

    let x = i256_neg(0_u256.into());
    // 0000_0000 turns into 1111_1111 + 1 = 0000_0000
    assert(x == 0_u256.into(), 'i256_neg with zero failed.');

    let x = max_u256;
    // 1111_1111 turns into 0000_0000 + 1 = 0000_0001
    assert(i256_neg(x.into()) == 1_u256.into(), 'i256_neg with max_u256 failed.');
}

#[test]
#[available_gas(20000000)]
fn test_signed_div_rem() {
    let max_u256 = BoundedInt::<u256>::max();
    let max_i256 = i256 { value: max_u256 };
    // Division by -1
    assert(
        i256_signed_div_rem(
            i256 { value: 1 }, max_u256.try_into().unwrap()
        ) == (max_i256, 0_u256.into()),
        'Division by -1 failed - 1.'
    ); // 1 / -1 == -1
    assert(
        i256_signed_div_rem(
            max_i256, max_u256.try_into().unwrap()
        ) == (i256 { value: 1 }, 0_u256.into()),
        'Division by -1 failed - 2.'
    ); // -1 / -1 == 1
    assert(
        i256_signed_div_rem(
            i256 { value: 0 }, max_u256.try_into().unwrap()
        ) == (i256 { value: 0 }, 0_u256.into()),
        'Division by -1 failed - 3.'
    ); // 0 / -1 == 0

    // Simple Division
    assert(
        i256_signed_div_rem(
            i256 { value: 10 }, 2_u256.try_into().unwrap()
        ) == (i256 { value: 5 }, 0_u256.into()),
        'Simple Division failed - 1.'
    ); // 10 / 2 == 5
    assert(
        i256_signed_div_rem(
            i256 { value: 10 }, 3_u256.try_into().unwrap()
        ) == (i256 { value: 3 }, 1_u256.into()),
        'Simple Division failed - 2.'
    ); // 10 / 3 == 3 remainder 1

    // Dividing a Negative Number
    assert(
        i256_signed_div_rem(max_i256, 1_u256.try_into().unwrap()) == (max_i256, 0_u256.into()),
        'Dividing a neg num failed - 1.'
    ); // -1 / 1 == -1
    assert(
        i256_signed_div_rem(
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE },
            0x2_u256.try_into().unwrap()
        ) == (max_i256, 0_u256.into()),
        'Dividing a neg num failed - 2.'
    ); // -2 / 2 == -1
    // - 2**255 / 2 == - 2**254
    assert(
        i256_signed_div_rem(
            i256 { value: 0x8000000000000000000000000000000000000000000000000000000000000000 },
            0x2_u256.try_into().unwrap()
        ) == (
            i256 { value: 0xc000000000000000000000000000000000000000000000000000000000000000 },
            0_u256.into()
        ),
        'Dividing a neg num failed - 3.'
    );

    // Dividing by a Negative Number
    assert(
        i256_signed_div_rem(
            i256 { value: 0x4 },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u256
                .try_into()
                .unwrap()
        ) == (
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE },
            0_u256.into()
        ),
        'Div by a neg num failed - 1.'
    ); // 4 / -2 == -2
    assert(
        i256_signed_div_rem(
            i256 { value: MAX_SIGNED_VALUE },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                .try_into()
                .unwrap()
        ) == (i256 { value: (MIN_SIGNED_VALUE + 1) }, 0_u256.into()),
        'Div by a neg num failed - 2.'
    ); // MAX_VALUE (2**255 -1) / -1 == MIN_VALUE + 1
    assert(
        i256_signed_div_rem(
            i256 { value: 0x1 },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                .try_into()
                .unwrap()
        ) == (
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF },
            0_u256.into()
        ),
        'Div by a neg num failed - 3.'
    ); // 1 / -1 == -1

    // Both Dividend and Divisor Negative
    assert(
        i256_signed_div_rem(
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6 },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB_u256
                .try_into()
                .unwrap()
        ) == (i256 { value: 2 }, 0_u256.into()),
        'Div w/ both neg num failed - 1.'
    ); // -10 / -5 == 2
    assert(
        i256_signed_div_rem(
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6 },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5_u256
                .try_into()
                .unwrap()
        ) == (
            i256 { value: 0 },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6_u256.into()
        ),
        'Div w/ both neg num failed - 2.'
    ); // -10 / -11 == 0 remainder -10

    // Division with Remainder
    assert(
        i256_signed_div_rem(
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9 },
            0x3_u256.try_into().unwrap()
        ) == (
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into()
        ),
        'Div with rem failed - 1.'
    ); // -7 / 3 == -2 remainder -1
    assert(
        i256_signed_div_rem(
            i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF },
            0x2_u256.try_into().unwrap()
        ) == (
            i256 { value: 0 },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into()
        ),
        'Div with rem failed - 2.'
    ); // -1 / 2 == 0 remainder -1

    // Edge Case: Dividing Minimum Value by -1
    assert(
        i256_signed_div_rem(
            i256 { value: MIN_SIGNED_VALUE },
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                .try_into()
                .unwrap()
        ) == (i256 { value: MIN_SIGNED_VALUE }, 0_u256.into()),
        'Div w/ both neg num failed - 3.'
    ); // MIN / -1 == MIN because 2**255 is out of range
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256 is 0',))]
fn test_signed_div_rem_by_zero() {
    //     Zero Division
    assert(
        i256_signed_div_rem(
            i256 { value: 0 }, 0_u256.try_into().unwrap()
        ) == (i256 { value: 0 }, i256 { value: 0 }),
        'Zero Division failed - 1.'
    );
}
