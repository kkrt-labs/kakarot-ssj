//! Utilities for kakarot standard library.
use array::ArrayTrait;
use option::OptionTrait;

mod helpers;

/// Panic with a custom message.
/// # Arguments
/// * `msg` - The message to panic with. Must be a short string to fit in a felt252.
fn panic_with(err: felt252) {
    let mut data = ArrayTrait::new();
    data.append(err);
    panic(data);
}

/// Convert a `felt252` to a `NonZero` type.
/// # Arguments
/// * `felt252` - The `felt252` to convert.
/// # Returns
/// * `Option::<NonZero::<felt252>>` - The `felt252` as a `NonZero` type.
/// * `Option::<NonZero::<felt252>>::None` - If `felt252` is 0.
fn to_non_zero(felt252: felt252) -> Option::<NonZero<felt252>> {
    let res = felt252_is_zero(felt252);
    match res {
        zeroable::IsZeroResult::Zero(()) => Option::<NonZero<felt252>>::None(()),
        zeroable::IsZeroResult::NonZero(val) => Option::<NonZero<felt252>>::Some(val),
    }
}


/// Force conversion from `felt252` to `u128`.
fn unsafe_felt252_to_u128(a: felt252) -> u128 {
    let res = integer::u128_try_from_felt252(a);
    res.unwrap()
}

/// Perform euclidean division on `felt252` types.
fn unsafe_euclidean_div_no_remainder(a: felt252, b: felt252) -> felt252 {
    let a_u128 = unsafe_felt252_to_u128(a);
    let b_u128 = unsafe_felt252_to_u128(b);
    integer::u128_to_felt252(a_u128 / b_u128)
}

fn unsafe_euclidean_div(a: felt252, b: felt252) -> (felt252, felt252) {
    let a_u128 = unsafe_felt252_to_u128(a);
    let b_u128 = unsafe_felt252_to_u128(b);
    (integer::u128_to_felt252(a_u128 / b_u128), integer::u128_to_felt252(a_u128 % b_u128))
}

fn max(a: usize, b: usize) -> usize {
    if a > b {
        return a;
    } else {
        return b;
    }
}

// Raise a number to a power.
/// * `base` - The number to raise.
/// * `exp` - The exponent.
/// # Returns
/// * `felt252` - The result of base raised to the power of exp.
fn pow(base: u128, exp: u128) -> u128 {
    if exp == 0 {
        return 1;
    } else {
        return base * pow(base, exp - 1);
    }
}

/// Panic with a custom code.
/// # Arguments
/// * `code` - The code to panic with. Must be a short string to fit in a felt252.
fn panic_with_code(code: felt252) {
    let mut data = ArrayTrait::new();
    data.append(code);
    panic(data);
}
