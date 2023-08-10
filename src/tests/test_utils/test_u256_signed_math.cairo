use kakarot::utils::u256_signed_math::{u256_not, u256_neg, u256_signed_div_rem, ALL_ONES, MAX_U256};
use integer::u256_safe_div_rem;
use debug::PrintTrait;

const MAX_SIGNED_VALUE: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
const MIN_SIGNED_VALUE: u256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

#[test]
#[available_gas(20000000)]
fn test_u256_not() {
    let x = u256_not(1);
    /// 0000_0001 turns into 1111_1110
    assert(x == u256 { low: ALL_ONES - 1, high: ALL_ONES }, 'u256_not failed.');

    let x = u256_not(0);
    /// 0000_0000 turns into 1111_1111
    assert(x == MAX_U256, 'u256_not with zero failed.');

    let x = MAX_U256;
    /// 1111_1111 turns into 0000_0000
    assert(u256_not(x) == 0, 'u256_not with MAX_U256 failed.');
}


#[test]
#[available_gas(20000000)]
fn test_u256_neg() {
    let x = u256_neg(1);
    // 0000_0001 turns into 1111_1110 + 1 = 1111_1111
    assert(x.low == MAX_U256.low && x.high == MAX_U256.high, 'u256_neg failed.');

    let x = u256_neg(0);
    // 0000_0000 turns into 1111_1111 + 1 = 0000_0000
    assert(x == 0, 'u256_neg with zero failed.');

    let x = MAX_U256;
    // 1111_1111 turns into 0000_0000 + 1 = 0000_0001
    assert(u256_neg(x) == 1, 'u256_neg with MAX_U256 failed.');
}


#[test]
#[available_gas(20000000)]
fn test_signed_div_rem() {
    //     Zero Division
    assert(u256_signed_div_rem(0, 0) == (0, 0), 'Zero Division failed - 1.');
    assert(u256_signed_div_rem(0xc0ffee, 0) == (0, 0), 'Zero Division failed - 2.');

    // Division by -1
    assert(
        u256_signed_div_rem(1, MAX_U256) == (MAX_U256, 0), 'Division by -1 failed - 1.'
    ); // 1 / -1 == -1
    assert(
        u256_signed_div_rem(MAX_U256, MAX_U256) == (1, 0), 'Division by -1 failed - 2.'
    ); // -1 / -1 == 1
    assert(u256_signed_div_rem(0, MAX_U256) == (0, 0), 'Division by -1 failed - 3.'); // 0 / -1 == 0

    // Simple Division
    assert(u256_signed_div_rem(10, 2) == (5, 0), 'Simple Division failed - 1.'); // 10 / 2 == 5
    assert(
        u256_signed_div_rem(10, 3) == (3, 1), 'Simple Division failed - 2.'
    ); // 10 / 3 == 3 remainder 1

    // Dividing a Negative Number
    assert(
        u256_signed_div_rem(MAX_U256, 1) == (MAX_U256, 0), 'Dividing a neg num failed - 1.'
    ); // -1 / 1 == -1
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE, 0x2
        ) == (MAX_U256, 0),
        'Dividing a neg num failed - 2.'
    ); // -2 / 2 == -1
    // - 2**255 / 2 == - 2**254
    assert(
        u256_signed_div_rem(
            0x8000000000000000000000000000000000000000000000000000000000000000, 0x2
        ) == (0xc000000000000000000000000000000000000000000000000000000000000000, 0),
        'Dividing a neg num failed - 3.'
    );

    // Dividing by a Negative Number
    assert(
        u256_signed_div_rem(
            0x4, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
        ) == (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE, 0),
        'Div by a neg num failed - 1.'
    ); // 4 / -2 == -2
    assert(
        u256_signed_div_rem(
            MAX_SIGNED_VALUE, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        ) == (MIN_SIGNED_VALUE + 1, 0),
        'Div by a neg num failed - 2.'
    ); // MAX_VALUE (2**255 -1) / -1 == MIN_VALUE + 1
    assert(
        u256_signed_div_rem(
            0x1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        ) == (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0),
        'Div by a neg num failed - 3.'
    ); // 1 / -1 == -1

    // Both Dividend and Divisor Negative
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB
        ) == (2, 0),
        'Div w/ both neg num failed - 1.'
    ); // -10 / -5 == 2
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5
        ) == (0, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6),
        'Div w/ both neg num failed - 2.'
    ); // -10 / -11 == 0 remainder -10

    // Division with Remainder
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9, 0x3
        ) == (
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        ),
        'Div with rem failed - 1.'
    ); // -7 / 3 == -2 remainder -1
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0x2
        ) == (0, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        'Div with rem failed - 2.'
    ); // -1 / 2 == 0 remainder -1

    // Edge Case: Dividing Minimum Value by -1
    assert(
        u256_signed_div_rem(
            MIN_SIGNED_VALUE, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        ) == (MIN_SIGNED_VALUE, 0),
        'Div w/ both neg num failed - 3.'
    ); // MIN / -1 == MIN because 2**255 is out of range
}

