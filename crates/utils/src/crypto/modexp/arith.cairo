use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::option::OptionTrait;
use core::traits::TryInto;

//todo: remove
use debug::PrintTrait;
use integer::{u64_wide_mul, u64_overflowing_add, u64_overflowing_sub, u128_overflowing_add};
use keccak::u128_split;
use super::mpnat::{MPNat, Word, DoubleWord, WORD_BITS, BASE, DOUBLE_WORD_MAX, WORD_MAX};
use utils::helpers::{Felt252VecTrait, U128Trait};
use utils::math::WrappingBitshift;
use utils::math::{Bitshift, u64_wrapping_mul};

//todo: remove
use utils::tests::test_modexp_arith::Felt252TestTrait;
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
    's'.print();
    s.print();
    // Using a range loop as opposed to `out.iter_mut().enumerate().take(s)`
    // does make a meaningful performance difference in this case.
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

            'input for prod_c'.print();
            out[j].print();
            x.digits.get(j).unwrap_or(0).print();
            y.digits.get(i).unwrap_or(0).print();
            c.print();
            let (prod, carry) = shifted_carrying_mul(
                out[j], x.digits.get(j).unwrap_or(0), y.digits.get(i).unwrap_or(0), c,
            );
            out.set(j, prod);
            c = carry;

            j += 1;

            'prod, carry'.print();
            prod.print();
            carry.print();
        };

        let (sum, carry) = carrying_add(out[s], c, false);
        out.set(s, sum);
        out.set(s + 1, carry.into());
        'sum+_carry'.print();
        sum.print();
        carry.print();

        let m = u64_wrapping_mul(out[0], n_prime);
        let (_, carry) = shifted_carrying_mul(out[0], m, n.digits.get(0).unwrap_or(0), 0);
        c = carry;

        'mpro_0'.print();
        out.print_dict();

        let mut j = 1;
        loop {
            if j == s {
                break;
            }

            let (prod, carry) = shifted_carrying_mul(out[j], m, n.digits.get(j).unwrap_or(0), c);
            out.set(j - 1, prod);
            c = carry;
            'carry'.print();
            c.print();

            j += 1;
        };

        let (sum, carry) = carrying_add(out[s], c, false);
        out.set(s - 1, sum);
        out.set(s, out[s + 1] + (carry.into())); // overflow impossible at this stage
        'mp_1'.print();
        out.print_dict();

        i += 1;
    };

    // Result is only in the first s + 1 words of the output.
    out.set(s + 1, 0);

    let mut j = s;
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

    //todo: remove
    'final'.print();
    out.print_dict();

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

        'borrow_input'.print();
        out_digit.print();
        n.digits.get(i).unwrap_or(0).print();
        b.print();
        let (diff, borrow) = borrowing_sub(out_digit, n.digits.get(i).unwrap_or(0), b);
        'diff & borrow'.print();
        diff.print();
        borrow.print();
        out.set(i, diff);
        b = borrow;

        i += 1;
    };

    //todo: remove
    'after_final'.print();
    out.print_dict();

    let (diff, _) = borrowing_sub(out[s], 0, b);
    out.set(s, diff);
}

// Equivalent to `monpro(x, x, n, n_prime, out)`, but more efficient.
fn monsq(ref x: MPNat, ref n: MPNat, n_prime: Word, ref out: Felt252Vec<Word>) {
    let s = n.digits.len();

    big_sq(ref x, ref out);
    //todo: remove
    '0_'.print();
    out.print_dict();
    let mut i = 0;

    loop {
        if i == s {
            break false;
        }

        let mut c: Word = 0;
        let m = u64_wrapping_mul(out[i], n_prime);

        let mut j = 0;
        loop {
            if j == s {
                break;
            }

            'c_here'.print();
            c.print();
            let (prod, carry) = shifted_carrying_mul(
                out[i + j], m, n.digits.get(j).unwrap_or(0), c
            );
            //todo: remove
            'prod'.print();
            prod.print();
            carry.print();
            out.set(i + j, prod);
            '1_'.print();
            out.print_dict();
            c = carry;

            j += 1;
        };

        let mut j = i + s;
        loop {
            if c <= 0 {
                break;
            }
            let (sum, carry) = carrying_add(out[j], c, false);
            out.set(j, sum);
            c = carry.into();

            //todo: remove
            '2_'.print();
            out.print_dict();

            j += 1;
        };

        i += 1;
    };

    // Only keep the last `s + 1` digits in `out`.
    let mut i = 0;
    loop {
        if i == s + 1 {
            break;
        };

        out.set(i, out[i + s]);

        i += 1;
    };
    //todo: remove
    '3_'.print();
    out.print_dict();

    let mut i = s + 1;
    loop {
        if i == out.len {
            break;
        };

        // todo(harsh): can this set an index which doesn't exist?
        out.set(i, 0);

        i += 1;
    };

    //todo: remove
    '4_'.print();
    out.print_dict();

    let mut k = s;
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

    //todo: remove
    '5_'.print();
    out.print_dict();

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
    'scratch_space_init'.print();
    scratch_space.print_dict();

    let mut digits = Felt252VecImpl::new();
    digits.resize(scratch_space.len(), 0);
    println!("I reach here as well");
    let mut result = MPNat { digits };
    result.digits.set(0, 1);

    'base'.print();
    base.digits.print_dict();
    'exp'.print();
    let mut i = 0;
    loop {
        if i == exp.len()
        {
            break;
        }

        (*exp[i]).print();
        i+=1;
    };

    let mut i = 0;
    loop {
        if i == exp.len() {
            break;
        }

        let b = *exp[i];
        let mut mask: u8 = 1_u8.wrapping_shl(7);

        println!("or stuck here?");

        loop {
            if mask <= 0 {
                break;
            }

            let digits = result.digits.duplicate();
            let mut tmp = MPNat { digits };

        println!("or stuck here 1");

            big_wrapping_mul(ref result, ref tmp, ref scratch_space);
                        'scratch_space >>'.print();
            scratch_space.print_dict();
        println!("or stuck here 2");
            result.digits.copy_from_vec(ref scratch_space).unwrap();
            scratch_space.reset(); // zero-out the scatch space
        println!("or stuck here 3");

            ' b_mask'.print();
            b.print();
            mask.print();
            if (b & mask) != 0 {
                'result_base_scartch_space'.print();
                result.digits.print_dict();
                '-----'.print();
                base.digits.print_dict();
                '-----'.print();
                scratch_space.print_dict();
                '-----'.print();
                big_wrapping_mul(ref result, ref base, ref scratch_space);
                        'scratch_space --'.print();
            scratch_space.print_dict();
                result.digits.copy_from_vec(ref scratch_space).unwrap();
                'result --'.print();
                result.digits.print_dict();
                scratch_space.reset(); // zero-out the scatch space
            }

            mask = mask.wrapping_shr(1);
        println!("or stuck here 4");

            'stuck here?'.print();
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

            let (prod, carry) = shifted_carrying_mul(out[i + j], x.digits.get(j).unwrap_or(0),
            y.digits.get(i).unwrap_or(0),
            c);
            c = carry;
            out.set(i + j, prod);

            j+=1;
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
        let xy = u64_wrapping_mul(x, y) & mask;
        let q = 1_u64.wrapping_shl((i - 1).into());
        if xy >= q {
            y += q;
        }
        i += 1;
    };

    let xy = u64_wrapping_mul(x, y);
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

    'c_0'.print();

    if k == 1 {
        let r = BASE;
        let result = r % (n.digits[0].into());
        out.set(0, result.as_u64());
        return;
    }

        'c_1'.print();

    'n_digits_approx_n'.print();
    n.digits[k - 1].print();
    n.digits[k - 2].print();
    let approx_n = join_as_double(n.digits[k - 1], n.digits[k - 2]);
    'c_2'.print();
    'approx_n'.print();
    approx_n.print();
    let approx_q = DOUBLE_WORD_MAX / approx_n;
    let mut approx_q: Word = approx_q.as_u64();



    loop {
        let mut c = 0;
        let mut b = false;

        let mut i: usize = 0;
        loop {
            'n_len, out.len'.print();
            n.digits.len().print();
            out.len().print();
            if i == n.digits.len || i == out.len {
                break;
            }

            let n_digit = n.digits[i];

            'c_3'.print();
            'prod_carry_inputs'.print();
            approx_q.print();
            n_digit.print();
            c.print();
            let (prod, carry) = carrying_mul(approx_q, n_digit, c);
            'prod_carry'.print();
            prod.print();
            carry.print();
            c  = carry;

                            'c_4'.print();

            let (diff, borrow) = borrowing_sub(0, prod, b);
            b = borrow;
            out.set(i, diff);

                                        'c_5'.print();
            i += 1;
        };

        'borrow_inputs'.print();
        c.print();
        b.print();
        let (_, borrow) = borrowing_sub(1, c, b);
        'borrow_is'.print();
        borrow.print();
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

        'o_x_x_0'.print();
        out[i + i].print(); x.digits[i].print(); x.digits[i].print();
        let (product, carry) = shifted_carrying_mul(out[i + i], x.digits[i], x.digits[i], 0);
        out.set(i + i, product);
        let mut c: DoubleWord = carry.into();

        'bgs_out_0'.print();
        out.print_dict();

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

        'bgs_out_end'.print();
        out.print_dict();

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
