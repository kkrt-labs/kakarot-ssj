// CREDITS: The implementation has been take from [aurora-engine](https://github.com/aurora-is-near/aurora-engine/tree/develop/engine-modexp)
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::option::OptionTrait;
use core::traits::TryInto;

use integer::{u64_wide_mul, u64_overflowing_add, u64_overflowing_sub, u128_overflowing_add};
use keccak::u128_split;
use super::mpnat::{MPNat, Word, DoubleWord, WORD_BITS, BASE, DOUBLE_WORD_MAX, WORD_MAX};
use utils::helpers::{Felt252VecTrait, U128Trait};
use utils::math::WrappingBitshift;
use utils::math::{Bitshift, WrappingMul};

use utils::traits::BoolIntoNumeric;

// Computes the "Montgomery Product" of two numbers.
// See Coarsely Integrated Operand Scanning (CIOS) Method in
// https://www.microsoft.com/en-us/research/wp-content/uploads/1996/01/j37acmon.pdf
// In short, computes `xy (r^-1) mod n`, where `r = 2^(8*4*s)` and `s` is the number of
// digits needs to represent `n`. `n_prime` has the property that `r(r^(-1)) - nn' = 1`.
// Note: This algorithm only works if `xy < rn` (generally we will either have both `x < n`, `y < n`
// or we will have `x < r`, `y < n`).
fn monpro(ref x: MPNat, ref y: MPNat, ref n: MPNat, n_prime: Word, ref out: Felt252Vec<Word>) {
    let s = out.len() - 2;

    let mut i = 0;
    loop {
        if i == s {
            break;
        }

        let mut c = 0;
        let mut j = 0;

        loop {
            if j == s {
                break;
            }

            let (prod, carry) = shifted_carrying_mul(
                out[j], x.digits.get(j).unwrap_or(0), y.digits.get(i).unwrap_or(0), c,
            );
            out.set(j, prod);
            c = carry;

            j += 1;
        };

        let (sum, carry) = carrying_add(out[s], c, false);
        out.set(s, sum);
        out.set(s + 1, carry.into());

        let m = out[0].wrapping_mul(n_prime);
        let (_, carry) = shifted_carrying_mul(out[0], m, n.digits.get(0).unwrap_or(0), 0);
        c = carry;

        let mut j = 1;
        loop {
            if j == s {
                break;
            }

            let (prod, carry) = shifted_carrying_mul(out[j], m, n.digits.get(j).unwrap_or(0), c);
            out.set(j - 1, prod);
            c = carry;

            j += 1;
        };

        let (sum, carry) = carrying_add(out[s], c, false);
        out.set(s - 1, sum);
        out.set(s, out[s + 1] + (carry.into())); // overflow impossible at this stage

        i += 1;
    };

    // Result is only in the first s + 1 words of the output.
    out.set(s + 1, 0);

    let mut j = s + 1;
    let should_return = loop {
        if j == 0 {
            break false;
        }

        let i = j - 1;

        if out[i] > n.digits.get(i).unwrap_or(0) {
            break false;
        } else if out[i] < n.digits.get(i).unwrap_or(0) {
            break true;
        }

        j -= 1;
    };

    if should_return {
        return;
    }

    let mut b = false;
    let mut i: u32 = 0;
    loop {
        if i == s || i == out.len {
            break;
        }

        let out_digit = out[i];

        let (diff, borrow) = borrowing_sub(out_digit, n.digits.get(i).unwrap_or(0), b);
        out.set(i, diff);
        b = borrow;

        i += 1;
    };

    let (diff, _) = borrowing_sub(out[s], 0, b);
    out.set(s, diff);
}

// Equivalent to `monpro(x, x, n, n_prime, out)`, but more efficient.
fn monsq(ref x: MPNat, ref n: MPNat, n_prime: Word, ref out: Felt252Vec<Word>) {
    let s = n.digits.len();

    big_sq(ref x, ref out);
    let mut i = 0;

    loop {
        if i == s {
            break false;
        }

        let mut c: Word = 0;
        let m = out[i].wrapping_mul(n_prime);

        let mut j = 0;
        loop {
            if j == s {
                break;
            }

            let (prod, carry) = shifted_carrying_mul(
                out[i + j], m, n.digits.get(j).unwrap_or(0), c
            );
            out.set(i + j, prod);
            c = carry;

            j += 1;
        };

        let mut j = i + s;
        loop {
            if c == 0 {
                break;
            }
            let (sum, carry) = carrying_add(out[j], c, false);
            out.set(j, sum);
            c = carry.into();

            j += 1;
        };

        i += 1;
    };

    // Only keep the last `s + 1` digits in `out`.
    let mut new_vec: Felt252Vec<u64> = out.clone_slice(s, s + 1);

    // safe unwrap, since new_vec.len <= out.len
    new_vec.expand(out.len).unwrap();
    out = new_vec;

    let mut k = s + 1;
    let should_return = loop {
        if k == 0 {
            break false;
        }

        let i = k - 1;

        if out[i] < n.digits.get(i).unwrap_or(0) {
            break true;
        }
        if out[i] > n.digits.get(i).unwrap_or(0) {
            break false;
        }

        k -= 1;
    };

    if should_return {
        return;
    }

    let mut b = false;
    let mut i = 0;
    loop {
        if i == s || i == out.len {
            break;
        }

        let out_digit = out[i];
        let (diff, borrow) = borrowing_sub(out_digit, n.digits.get(i).unwrap_or(0), b);
        out.set(i, diff);
        b = borrow;

        i += 1;
    };

    let (diff, _) = borrowing_sub(out[s], 0, b);
    out.set(s, diff);
}


/// Computes `base ^ exp`, ignoring overflow.
pub fn big_wrapping_pow(
    ref base: MPNat, exp: Span<u8>, ref scratch_space: Felt252Vec<Word>
) -> MPNat {
    let mut digits = Felt252VecImpl::new();
    digits.resize(scratch_space.len(), 0);
    let mut result = MPNat { digits };
    result.digits.set(0, 1);

    let mut i = 0;
    loop {
        if i == exp.len() {
            break;
        }

        let b = *exp[i];
        let mut mask: u8 = 128;

        loop {
            if mask <= 0 {
                break;
            }

            let digits = result.digits.duplicate();
            let mut tmp = MPNat { digits };

            big_wrapping_mul(ref result, ref tmp, ref scratch_space);
            result.digits.copy_from_vec_le(ref scratch_space).unwrap();
            scratch_space.reset(); // zero-out the scatch space

            if (b & mask) != 0 {
                big_wrapping_mul(ref result, ref base, ref scratch_space);
                result.digits.copy_from_vec_le(ref scratch_space).unwrap();
                scratch_space.reset(); // zero-out the scatch space
            }

            mask = mask.wrapping_shr(1);
        };

        i += 1;
    };

    result
}

/// Computes `(x * y) mod 2^(WORD_BITS*out.len())`.
fn big_wrapping_mul(ref x: MPNat, ref y: MPNat, ref out: Felt252Vec<Word>) {
    let s = out.len();
    let mut i = 0;

    loop {
        if i == s {
            break;
        }

        let mut c: Word = 0;

        let mut j = 0;
        loop {
            if j == (s - i) {
                break;
            }

            let (prod, carry) = shifted_carrying_mul(
                out[i + j], x.digits.get(j).unwrap_or(0), y.digits.get(i).unwrap_or(0), c
            );
            c = carry;
            out.set(i + j, prod);

            j += 1;
        };

        i += 1;
    }
}

// Given x odd, computes `x^(-1) mod 2^32`.
// See `MODULAR-INVERSE` in https://link.springer.com/content/pdf/10.1007/3-540-46877-3_21.pdf
fn mod_inv(x: Word) -> Word {
    let mut y = 1;
    let mut i = 2;

    loop {
        if i == WORD_BITS {
            break;
        }

        let mask: u64 = 1_u64.wrapping_shl(i.into()) - 1;
        let xy = x.wrapping_mul(y) & mask;
        let q = 1_u64.wrapping_shl((i - 1).into());
        if xy >= q {
            y += q;
        }
        i += 1;
    };

    let xy = x.wrapping_mul(y);
    let q = 1_u64.wrapping_shl((WORD_BITS - 1).into());
    if xy >= q {
        y += q;
    }
    y
}

/// Computes R mod n, where R = 2^(WORD_BITS*k) and k = n.digits.len()
/// Note that if R = qn + r, q must be smaller than 2^WORD_BITS since `2^(WORD_BITS) * n > R`
/// (adding a whole additional word to n is too much).
/// Uses the two most significant digits of n to approximate the quotient,
/// then computes the difference to get the remainder. It is possible that this
/// quotient is too big by 1; we can catch that case by looking for overflow
/// in the subtraction.
fn compute_r_mod_n(ref n: MPNat, ref out: Felt252Vec<Word>) {
    let k = n.digits.len();

    if k == 1 {
        let r = BASE;
        let result = r % (n.digits[0].into());
        out.set(0, result.as_u64());
        return;
    }

    let approx_n = join_as_double(n.digits[k - 1], n.digits[k - 2]);
    let approx_q = DOUBLE_WORD_MAX / approx_n;
    let mut approx_q: Word = approx_q.as_u64();

    loop {
        let mut c = 0;
        let mut b = false;

        let mut i: usize = 0;
        loop {
            if i == n.digits.len || i == out.len {
                break;
            }

            let n_digit = n.digits[i];

            let (prod, carry) = carrying_mul(approx_q, n_digit, c);
            c = carry;

            let (diff, borrow) = borrowing_sub(0, prod, b);
            b = borrow;
            out.set(i, diff);

            i += 1;
        };

        let (_, borrow) = borrowing_sub(1, c, b);
        if borrow {
            // approx_q was too large so `R - approx_q*n` overflowed.
            // try again with approx_q -= 1
            approx_q -= 1;
        } else {
            break;
        }
    }
}

/// Computes `a + xy + c` where any overflow is captured as the "carry",
/// the second part of the output. The arithmetic in this function is
/// guaranteed to never overflow because even when all 4 variables are
/// equal to `Word::MAX` the output is smaller than `DoubleWord::MAX`.
fn shifted_carrying_mul(a: Word, x: Word, y: Word, c: Word) -> (Word, Word) {
    let res: DoubleWord = a.into() + u64_wide_mul(x, y) + c.into();
    let (top_word, bottom_word) = u128_split(res);
    (bottom_word, top_word)
}

/// Computes `xy + c` where any overflow is captured as the "carry",
/// the second part of the output. The arithmetic in this function is
/// guaranteed to never overflow because even when all 3 variables are
/// equal to `Word::MAX` the output is smaller than `DoubleWord::MAX`.
fn carrying_mul(x: Word, y: Word, c: Word) -> (Word, Word) {
    let wide = u64_wide_mul(x, y) + c.into();
    let (top_word, bottom_word) = u128_split(wide);
    (bottom_word, top_word)
}

// Computes `x + y` with "carry the 1" semantics
fn carrying_add(x: Word, y: Word, carry: bool) -> (Word, bool) {
    let (a, b) = match u64_overflowing_add(x, y) {
        Result::Ok(x) => (x, false),
        Result::Err(x) => (x, true)
    };
    let (c, d) = match u64_overflowing_add(a, carry.into()) {
        Result::Ok(x) => (x, false),
        Result::Err(x) => (x, true)
    };
    (c, b | d)
}

// Computes `x - y` with "borrow from your neighbour" semantics
pub fn borrowing_sub(x: Word, y: Word, borrow: bool) -> (Word, bool) {
    let (a, b) = match u64_overflowing_sub(x, y) {
        Result::Ok(x) => (x, false),
        Result::Err(x) => (x, true)
    };
    let (c, d) = match u64_overflowing_sub(a, borrow.into()) {
        Result::Ok(x) => (x, false),
        Result::Err(x) => (x, true)
    };

    (c, b | d)
}

fn join_as_double(hi: Word, lo: Word) -> DoubleWord {
    let hi: DoubleWord = hi.into();
    lo.into() | (hi.wrapping_shl(WORD_BITS.into())).into()
}

/// Computes `x^2`, storing the result in `out`.
fn big_sq(ref x: MPNat, ref out: Felt252Vec<Word>) {
    let s = x.digits.len();
    let mut i = 0;

    loop {
        if i == s {
            break;
        }

        let (product, carry) = shifted_carrying_mul(out[i + i], x.digits[i], x.digits[i], 0);
        out.set(i + i, product);
        let mut c: DoubleWord = carry.into();

        let mut j = i + 1;

        loop {
            if j >= s {
                break;
            }

            let mut new_c: DoubleWord = 0;
            let res: DoubleWord = (x.digits[i].into()) * (x.digits[j].into());
            let (res, overflow) = match u128_overflowing_add(res, res) {
                Result::Ok(res) => { (res, false) },
                Result::Err(res) => { (res, true) }
            };
            if overflow {
                new_c += BASE;
            }

            let (res, overflow) = match u128_overflowing_add(out[i + j].into(), res) {
                Result::Ok(res) => { (res, false) },
                Result::Err(res) => { (res, true) }
            };

            if overflow {
                new_c += BASE;
            }
            let (res, overflow) = match u128_overflowing_add(res, c) {
                Result::Ok(res) => { (res, false) },
                Result::Err(res) => { (res, true) }
            };
            if overflow {
                new_c += BASE;
            }
            out.set(i + j, res.as_u64());
            c = new_c + ((res.wrapping_shr(WORD_BITS.into())));

            j += 1;
        };

        let (sum, carry) = carrying_add(out[i + s], c.as_u64(), false);
        out.set(i + s, sum);
        out.set(i + s + 1, (c.wrapping_shr(WORD_BITS.into()) + (carry.into())).as_u64());

        i += 1;
    }
}

// Performs `a <<= shift`, returning the overflow
fn in_place_shl(ref a: Felt252Vec<Word>, shift: u32) -> Word {
    let mut c: Word = 0;
    let carry_shift = WORD_BITS - shift;

    let mut i = 0;
    loop {
        if i == a.len {
            break;
        }

        let a_digit = a[i];
        let carry = a_digit.wrapping_shr(carry_shift.into());
        let a_digit = a_digit.wrapping_shl(shift.into()) | c;
        a.set(i, a_digit);

        c = carry;

        i += 1;
    };

    c
}

// Performs `a >>= shift`, returning the overflow
fn in_place_shr(ref a: Felt252Vec<Word>, shift: u32) -> Word {
    let mut b: Word = 0;
    let borrow_shift = WORD_BITS - shift;

    let mut i = a.len;
    loop {
        if i == 0 {
            break;
        }

        let j = i - 1;

        let a_digit = a[j];
        let borrow = a_digit.wrapping_shl(borrow_shift.into());
        let a_digit = a_digit.wrapping_shr(shift.into()) | b;
        a.set(j, a_digit);

        b = borrow;

        i -= 1;
    };

    b
}

// Performs a += b, returning if there was overflow
pub fn in_place_add(ref a: Felt252Vec<Word>, ref b: Felt252Vec<Word>) -> bool {
    let mut c = false;

    let mut i = 0;

    loop {
        if i == a.len() || i == b.len() {
            break;
        }

        let a_digit = a[i];
        let b_digit = b[i];

        let (sum, carry) = carrying_add(a_digit, b_digit, c);
        a.set(i, sum);
        c = carry;

        i += 1;
    };

    c
}

// Performs `a -= xy`, returning the "borrow".
fn in_place_mul_sub(ref a: Felt252Vec<Word>, ref x: Felt252Vec<Word>, y: Word) -> Word {
    // a -= x*0 leaves a unchanged, so return early
    if y == 0 {
        return 0;
    }

    // carry is between -big_digit::MAX and 0, so to avoid overflow we store
    // offset_carry = carry + big_digit::MAX
    let mut offset_carry = WORD_MAX;

    let mut i = 0;

    loop {
        if i == a.len() || i == x.len() {
            break;
        }

        let a_digit = a[i];
        let x_digit = x[i];

        // We want to calculate sum = x - y * c + carry.
        // sum >= -(big_digit::MAX * big_digit::MAX) - big_digit::MAX
        // sum <= big_digit::MAX
        // Offsetting sum by (big_digit::MAX << big_digit::BITS) puts it in DoubleBigDigit range.
        let offset_sum = join_as_double(WORD_MAX, a_digit)
            - WORD_MAX.into()
            + offset_carry.into()
            - ((x_digit.into()) * (y.into()));

        let new_offset_carry = (offset_sum.wrapping_shr(WORD_BITS.into())).as_u64();
        let new_x = offset_sum.as_u64();
        offset_carry = new_offset_carry;
        a.set(i, new_x);

        i += 1;
    };

    // Return the borrow.
    WORD_MAX - offset_carry
}
