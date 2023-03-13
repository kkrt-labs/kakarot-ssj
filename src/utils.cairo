//! Utilities for kakarot standard library.
use array::ArrayTrait;
use option::OptionTrait;

/// Panic with a custom message.
/// # Arguments
/// * `msg` - The message to panic with. Must be a short string to fit in a felt.
fn panic_with(err: felt) {
    let mut data = ArrayTrait::new();
    data.append(err);
    panic(data);
}

/// Convert a `felt` to a `NonZero` type.
/// # Arguments
/// * `felt` - The `felt` to convert.
/// # Returns
/// * `Option::<NonZero::<felt>>` - The `felt` as a `NonZero` type.
/// * `Option::<NonZero::<felt>>::None` - If `felt` is 0.
fn to_non_zero(felt: felt) -> Option::<NonZero::<felt>> {
    let res = felt_is_zero(felt);
    match res {
        IsZeroResult::Zero(()) => Option::<NonZero::<felt>>::None(()),
        IsZeroResult::NonZero(val) => Option::<NonZero::<felt>>::Some(val),
    }
}


/// Force conversion from `felt` to `u128`.
fn unsafe_felt_to_u128(a: felt) -> u128 {
    let res = integer::u128_try_from_felt(a);
    res.unwrap()
}

/// Perform euclidean division on `felt` types.
fn unsafe_euclidean_div_no_remainder(a: felt, b: felt) -> felt {
    let a_u128 = unsafe_felt_to_u128(a);
    let b_u128 = unsafe_felt_to_u128(b);
    integer::u128_to_felt(a_u128 / b_u128)
}

fn unsafe_euclidean_div(a: felt, b: felt) -> (felt, felt) {
    let a_u128 = unsafe_felt_to_u128(a);
    let b_u128 = unsafe_felt_to_u128(b);
    (integer::u128_to_felt(a_u128 / b_u128), integer::u128_to_felt(a_u128 % b_u128))
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
/// * `felt` - The result of base raised to the power of exp.
fn pow(base: felt, exp: felt) -> felt {
    // Check if out of gas.
    // TODO: Remove when automatically handled by compiler.
    match gas::get_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = ArrayTrait::new();
            data.append('OOG');
            panic(data);
        }
    }

    match exp {
        0 => 1,
        _ => base * pow(base, exp - 1),
    }
}

/// Panic with a custom code.
/// # Arguments
/// * `code` - The code to panic with. Must be a short string to fit in a felt.
fn panic_with_code(code: felt) {
    let mut data = ArrayTrait::new();
    data.append(code);
    panic(data);
}
