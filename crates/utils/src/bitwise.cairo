use utils::math::{pow, pow_felt252};
use math::Oneable;
use zeroable::Zeroable;

// @notice Bitwise left shift
// @param num The number to be shifted
// @param shift The number of bits to shift
// @return The left shifted number
fn left_shift<
    T,
    impl TZeroable: Zeroable<T>,
    impl TAdd: Add<T>,
    impl TSub: Sub<T>,
    impl TMul: Mul<T>,
    impl TOneable: Oneable<T>,
    impl TCopy: Copy<T>,
    impl TDrop: Drop<T>
// TODO refactor shift type from T to usize
>(
    num: T, shift: T
) -> T {
    let two = TOneable::one() + TOneable::one();
    num * pow(two, shift)
}

fn left_shift_felt252(num: felt252, shift: felt252) -> felt252 {
    num * pow_felt252(2, shift)
}

// @notice Bitwise right shift
// @param num The number to be shifted
// @param shift The number of bits to shift
// @return The right shifted number
fn right_shift<
    T,
    impl TZeroable: Zeroable<T>,
    impl TAdd: Add<T>,
    impl TSub: Sub<T>,
    impl TMul: Mul<T>,
    impl TDiv: Div<T>,
    impl TOneable: Oneable<T>,
    impl TCopy: Copy<T>,
    impl TDrop: Drop<T>
// TODO refactor shift type from T to usize
>(
    num: T, shift: T
) -> T {
    let two = TOneable::one() + TOneable::one();
    num / pow(two, shift)
}

// @notice Bit length of a number
// @param num The number to be measured
// @return The number of bits in the number
fn bit_length<
    T,
    impl TZeroable: Zeroable<T>,
    impl TPartialOrd: PartialOrd<T>,
    impl TAddImpl: Add<T>,
    impl TSub: Sub<T>,
    impl TMul: Mul<T>,
    impl TOneable: Oneable<T>,
    impl TCopy: Copy<T>,
    impl TDrop: Drop<T>
>(
    num: T
) -> T {
    let mut bit_position = TZeroable::zero();
    let mut cur_n = TOneable::one();
    loop {
        if cur_n > num {
            break ();
        };
        bit_position = bit_position + TOneable::one();
        cur_n = left_shift(cur_n, TOneable::one());
    };
    bit_position
}
