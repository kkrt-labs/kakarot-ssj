use utils::u256_signed_math::{u256_neg, u256_signed_div_rem, ALL_ONES, MAX_U256};
use integer::u256_safe_div_rem;
use debug::PrintTrait;
use traits::{Into, TryInto};
use option::OptionTrait;

const MAX_SIGNED_VALUE: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
const MIN_SIGNED_VALUE: u256 = 0x8000000000000000000000000000000000000000000000000000000000000000;


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
    // Division by -1
    assert(
        u256_signed_div_rem(1, MAX_U256.try_into().unwrap()) == (MAX_U256, 0),
        'Division by -1 failed - 1.'
    ); // 1 / -1 == -1
    assert(
        u256_signed_div_rem(MAX_U256, MAX_U256.try_into().unwrap()) == (1, 0),
        'Division by -1 failed - 2.'
    ); // -1 / -1 == 1
    assert(
        u256_signed_div_rem(0, MAX_U256.try_into().unwrap()) == (0, 0), 'Division by -1 failed - 3.'
    ); // 0 / -1 == 0

    // Simple Division
    assert(
        u256_signed_div_rem(10, 2_u256.try_into().unwrap()) == (5, 0), 'Simple Division failed - 1.'
    ); // 10 / 2 == 5
    assert(
        u256_signed_div_rem(10, 3_u256.try_into().unwrap()) == (3, 1), 'Simple Division failed - 2.'
    ); // 10 / 3 == 3 remainder 1

    // Dividing a Negative Number
    assert(
        u256_signed_div_rem(MAX_U256, 1_u256.try_into().unwrap()) == (MAX_U256, 0),
        'Dividing a neg num failed - 1.'
    ); // -1 / 1 == -1
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
            0x2_u256.try_into().unwrap()
        ) == (MAX_U256, 0),
        'Dividing a neg num failed - 2.'
    ); // -2 / 2 == -1
    // - 2**255 / 2 == - 2**254
    assert(
        u256_signed_div_rem(
            0x8000000000000000000000000000000000000000000000000000000000000000,
            0x2_u256.try_into().unwrap()
        ) == (0xc000000000000000000000000000000000000000000000000000000000000000, 0),
        'Dividing a neg num failed - 3.'
    );

    // Dividing by a Negative Number
    assert(
        u256_signed_div_rem(
            0x4,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u256
                .try_into()
                .unwrap()
        ) == (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE, 0),
        'Div by a neg num failed - 1.'
    ); // 4 / -2 == -2
    assert(
        u256_signed_div_rem(
            MAX_SIGNED_VALUE,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                .try_into()
                .unwrap()
        ) == (MIN_SIGNED_VALUE + 1, 0),
        'Div by a neg num failed - 2.'
    ); // MAX_VALUE (2**255 -1) / -1 == MIN_VALUE + 1
    assert(
        u256_signed_div_rem(
            0x1,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                .try_into()
                .unwrap()
        ) == (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0),
        'Div by a neg num failed - 3.'
    ); // 1 / -1 == -1

    // Both Dividend and Divisor Negative
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB_u256
                .try_into()
                .unwrap()
        ) == (2, 0),
        'Div w/ both neg num failed - 1.'
    ); // -10 / -5 == 2
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5_u256
                .try_into()
                .unwrap()
        ) == (0, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6),
        'Div w/ both neg num failed - 2.'
    ); // -10 / -11 == 0 remainder -10

    // Division with Remainder
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9,
            0x3_u256.try_into().unwrap()
        ) == (
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        ),
        'Div with rem failed - 1.'
    ); // -7 / 3 == -2 remainder -1
    assert(
        u256_signed_div_rem(
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            0x2_u256.try_into().unwrap()
        ) == (0, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        'Div with rem failed - 2.'
    ); // -1 / 2 == 0 remainder -1

    // Edge Case: Dividing Minimum Value by -1
    assert(
        u256_signed_div_rem(
            MIN_SIGNED_VALUE,
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                .try_into()
                .unwrap()
        ) == (MIN_SIGNED_VALUE, 0),
        'Div w/ both neg num failed - 3.'
    ); // MIN / -1 == MIN because 2**255 is out of range
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256 is 0',))]
fn test_signed_div_rem_by_zero() {
    //     Zero Division
    assert(
        u256_signed_div_rem(0, 0_u256.try_into().unwrap()) == (0, 0), 'Zero Division failed - 1.'
    );
}
