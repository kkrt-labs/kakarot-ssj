// CREDITS: The implementation has been take from [aurora-engine](https://github.com/aurora-is-near/aurora-engine/tree/develop/engine-modexp)
use alexandria_data_structures::vec::VecTrait;
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::dict::Felt252DictTrait;
use core::num::traits::BitSize;
use core::option::OptionTrait;
use core::result::ResultTrait;
use core::traits::Destruct;
use core::traits::TryInto;

use super::arith::{
    big_wrapping_pow, mod_inv, compute_r_mod_n, join_as_double, in_place_shl, in_place_shr,
    in_place_add, in_place_mul_sub, big_wrapping_mul, monsq, monpro, borrowing_sub, carrying_add
};
use utils::checked_math::checked_mul::CheckedMul;
use utils::checked_math::checked_mul;
use utils::helpers::{FromBytes, U64Trait, Felt252VecTrait, U128Trait, BitLengthTrait, ByteSize};
use utils::math::{Bitshift, WrappingBitshift};

type Word = u64;
type DoubleWord = u128;
const WORD_BYTES: usize = 8;
const WORD_BITS: usize = 64;
const WORD_MAX: Word = 18446744073709551615;
// 2**64
const BASE: DoubleWord = 18446744073709551616;
const DOUBLE_WORD_MAX: DoubleWord = 340282366920938463463374607431768211455;
/// Multi-precision natural number, represented in base `Word::MAX + 1 = 2^WORD_BITS`.
/// The digits are stored in little-endian order, i.e. digits[0] is the least
/// significant digit.
#[derive(Destruct)]
struct MPNat {
    digits: Felt252Vec<u64>
}


#[generate_trait]
impl MPNatTraitImpl of MPNatTrait {
    fn from_big_endian(bytes: Span<u8>) -> MPNat {
        if bytes.is_empty() {
            return MPNat { digits: Felt252VecImpl::new() };
        }

        // Remainder on division by WORD_BYTES
        let r = bytes.len() & (WORD_BYTES - 1);
        let n_digits: usize = if r == 0 {
            bytes.len() / WORD_BYTES
        } else {
            // Need an extra digit for the remainder
            (bytes.len() / WORD_BYTES) + 1
        };

        let mut digits: Felt252Vec<u64> = Felt252VecImpl::new();
        // safe unwrap, since n_digits >= 0;
        digits.expand(n_digits).unwrap();

        // buffer to hold Word-sized slices of the input bytes
        let mut buf: Felt252Vec<u8> = Felt252VecImpl::new();
        // safe unwrap, since WORD_BYTES > 0
        buf.expand(WORD_BYTES).unwrap();

        let mut i = n_digits - 1;
        if r != 0 {
            // safe unwrap, since we know index is in bound + no overflow
            buf.copy_from_bytes_le((WORD_BYTES - r), bytes.slice(0, r)).unwrap();

            // safe unwrap, since we know that bytes won't overflow
            let word = buf.to_le_bytes().from_be_bytes().unwrap();
            digits.set(i, word);

            if i == 0 {
                // Special case where there is just one digit
                return MPNat { digits };
            }

            i -= 1;
        };

        let mut j = r;
        loop {
            let next_j = j + WORD_BYTES;
            // safe unwrap, since we know index is in bound + no overflow
            buf.copy_from_bytes_le(0, bytes.slice(j, next_j - j)).unwrap();

            // safe unwrap, since we know that bytes won't overflow
            let word: u64 = buf.to_le_bytes().from_be_bytes().unwrap();
            digits.set(i, word);

            if i == 0 {
                break;
            }

            i -= 1;
            j = next_j;
        };

        digits.remove_trailing_zeroes();
        MPNat { digits }
    }

    /// Makes `self` have the same number of digits as `other` by
    /// pushing 0s or dropping higher order digits as needed.
    /// This is equivalent to reducing `self` modulo `2^(WORD_BITS*k)` where
    /// `k` is the number of digits in `other`.
    fn sub_to_same_size(ref self: MPNat, ref other: MPNat) {
        self.digits.remove_trailing_zeroes();

        let n = other.digits.len();
        let s = self.digits.len();
        let m = if n >= s {
            return;
        } else {
            s - n
        };

        let other_most_sig: DoubleWord = other.digits[other.digits.len() - 1].into();

        if self.digits.len() == 2 { // This is the smallest case since `n >= 1` and `m > 0`
            // implies that `self.digits.len() >= 2`.
            // In this case we can use DoubleWord-sized arithmetic
            // to get the answer directly.
            let self_most_sig = self.digits.pop().unwrap();
            let a = join_as_double(self_most_sig, self.digits[0]);
            let b = other_most_sig;
            self.digits.set(0, (a % b).as_u64());
            return;
        };

        if n == 1 {
            // The divisor is only 1 digit, so the long-division
            // algorithm is easy.
            let k = self.digits.len() - 1;
            let mut i = k;
            loop {
                if i == 0 {
                    break;
                };

                i -= 1;

                let self_most_sig = self.digits.pop().unwrap();
                let self_second_sig = self.digits[i];
                let r = join_as_double(self_most_sig, self_second_sig) % other_most_sig;
                self.digits.set(i, r.as_u64());
            };

            return;
        }

        // At this stage we know that `n >= 2` and `self.digits.len() >= 3`.
        // The smaller cases are covered in the if-statements above.

        // The algorithm below only works well when the divisor's
        // most significant digit is at least `BASE / 2`.
        // If it is too small then we "normalize" by multiplying
        // both numerator and denominator by a common factor
        // and run the algorithm on those numbers.
        // See Knuth The Art of Computer Programming vol. 2 section 4.3 for details.
        let shift: u32 = other_most_sig.as_u64().count_leading_zeroes().into();
        if shift > 0 {
            // Normalize self
            let overflow = in_place_shl(ref self.digits, shift);
            self.digits.push(overflow);

            // Normalize other
            let mut normalized = other.digits.duplicate();
            in_place_shl(ref normalized, shift);

            let mut v = MPNat { digits: normalized };
            // Run algorithm on normalized values
            self.sub_to_same_size(ref v);

            // need to de-normalize to get the correct result
            in_place_shr(ref self.digits, shift);

            return;
        };

        let other_second_sig: DoubleWord = other.digits[n - 2].into();
        let mut self_most_sig: Word = 0;

        let mut i = m + 1;

        loop {
            if i == 0 {
                break;
            }

            let j = i - 1;

            let self_second_sig = self.digits[self.digits.len() - 1];
            let self_third_sig = self.digits[self.digits.len() - 2];

            let a = join_as_double(self_most_sig, self_second_sig);
            let mut q_hat = a / other_most_sig;
            let mut r_hat = a % other_most_sig;

            loop {
                let a = q_hat * other_second_sig;
                let b = join_as_double(r_hat.as_u64(), self_third_sig);
                if q_hat >= BASE || a > b {
                    q_hat -= 1;
                    r_hat += other_most_sig;
                    if BASE <= r_hat {
                        break;
                    }
                } else {
                    break;
                }
            };

            //TODO: optimize with [#720](https://github.com/kkrt-labs/kakarot-ssj/issues/720)
            let mut a = self.digits.clone_slice(j, self.digits.len() - j);

            let mut borrow = in_place_mul_sub(ref a, ref other.digits, q_hat.as_u64());
            self.digits.insert_vec(j, ref a).unwrap();
            if borrow > self_most_sig {
                // q_hat was too large, add back one multiple of the modulus
                //TODO: optimize with [#720](https://github.com/kkrt-labs/kakarot-ssj/issues/720)
                let mut a = self.digits.clone_slice(j, self.digits.len() - j);
                in_place_add(ref a, ref other.digits);
                self.digits.insert_vec(j, ref a).unwrap();
                borrow -= 1;
            }

            self_most_sig = self.digits.pop().unwrap();

            i -= 1;
        };

        self.digits.push(self_most_sig);
    }

    fn is_power_of_two(ref self: MPNat) -> bool {
        // A multi-precision number is a power of 2 iff exactly one digit
        // is a power of 2 and all others are zero.

        let mut found_power_of_two = false;

        let mut i = 0;
        loop {
            if i == self.digits.len() {
                break found_power_of_two;
            }

            let d = self.digits[i];
            let is_p2 = if d != 0 {
                (d & (d - 1)) == 0
            } else {
                false
            };

            if ((!is_p2 && d != 0) || (is_p2 && found_power_of_two)) {
                break false;
            } else if is_p2 {
                found_power_of_two = true;
            }

            i += 1;
        }
    }

    fn is_odd(ref self: MPNat) -> bool {
        // when the value is 0
        if self.digits.len() == 0 {
            return false;
        };

        // A binary number is odd iff its lowest order bit is set.
        self.digits[0] & 1 == 1
    }

    // Koç's algorithm for inversion mod 2^k
    // https://eprint.iacr.org/2017/411.pdf
    fn koc_2017_inverse(ref aa: MPNat, k: usize) -> MPNat {
        let length = k / WORD_BITS;
        let mut digits = Felt252VecImpl::new();
        digits.resize(length + 1, 0);
        let mut b = MPNat { digits };

        b.digits.set(0, 1);

        let mut a = MPNat { digits: aa.digits.duplicate(), };
        a.digits.resize(length + 1, 0);

        let mut neg: bool = false;

        let mut digits = Felt252VecImpl::new();
        digits.resize(length + 1, 0);
        let mut res = MPNat { digits };

        let (mut wordpos, mut bitpos) = (0, 0);

        let mut i = 0;
        loop {
            if i == k {
                break;
            }

            let x = b.digits[0] & 1;
            if x != 0 {
                if !neg {
                    // b = a - b
                    //TODO: optimize with [#720](https://github.com/kkrt-labs/kakarot-ssj/issues/720)
                    let mut tmp = MPNat { digits: a.digits.duplicate(), };
                    in_place_mul_sub(ref tmp.digits, ref b.digits, 1);
                    b = tmp;
                    neg = true;
                } else {
                    // b = b - a
                    in_place_add(ref b.digits, ref a.digits);
                }
            }

            in_place_shr(ref b.digits, 1);

            res.digits.set(wordpos, res.digits[wordpos] | (x.shl(bitpos.into())));

            bitpos += 1;
            if bitpos == WORD_BITS {
                bitpos = 0;
                wordpos += 1;
            }

            i += 1;
        };

        res
    }


    /// Computes `self ^ exp mod modulus`. `exp` must be given as big-endian bytes.
    fn modpow(ref self: MPNat, exp: Span<u8>, ref modulus: MPNat) -> MPNat {
        // exp must be stripped because it is iterated over in
        // big_wrapping_pow and modpow_montgomery, and a large
        // zero-padded exp leads to performance issues.
        let (exp, exp_is_zero) = MPNatTrait::strip_leading_zeroes(exp);

        if exp_is_zero {
            if modulus.digits.len() == 1 && modulus.digits[0] == 1 {
                let mut digits = Felt252VecImpl::new();
                digits.push(0);

                return MPNat { digits };
            } else {
                let mut digits = Felt252VecImpl::new();
                digits.push(1);

                return MPNat { digits };
            }
        }

        if exp.len() <= (ByteSize::<usize>::byte_size()) {
            let exp_as_number: usize = exp.from_le_bytes().unwrap();

            match self.digits.len().checked_mul(exp_as_number) {
                Option::Some(max_output_digits) => {
                    if (modulus.digits.len() > max_output_digits) {
                        // Special case: modulus is larger than `base ^ exp`, so division is not relevant
                        let mut scratch_space: Felt252Vec<Word> = Felt252VecImpl::new();
                        scratch_space.expand(max_output_digits).unwrap();

                        return big_wrapping_pow(ref self, exp, ref scratch_space);
                    }
                },
                Option::None => {}
            };
        }

        if modulus.is_power_of_two() { // return
            return self.modpow_with_power_of_two(exp, ref modulus);
        } else if modulus.is_odd() {
            return self.modpow_montgomery(exp, ref modulus);
        }

        // If the modulus is not a power of two and not an odd number then
        // it is a product of some power of two with an odd number. In this
        // case we will use the Chinese remainder theorem to get the result.
        // See http://www.people.vcu.edu/~jwang3/CMSC691/j34monex.pdf

        let trailing_zeros = modulus.digits.count_leading_zeroes();
        let additional_zero_bits: usize = modulus
            .digits[trailing_zeros]
            .count_trailing_zeroes()
            .into();

        let mut power_of_two = {
            let mut digits = Felt252VecImpl::new();
            digits.resize(trailing_zeros + 1, 0);
            let mut tmp = MPNat { digits };
            tmp.digits.set(trailing_zeros, 1_u64.shl(additional_zero_bits.into()));
            tmp
        };

        let power_of_two_mask = power_of_two.digits[power_of_two.digits.len() - 1] - 1;
        let mut odd = {
            let num_digits = modulus.digits.len() - trailing_zeros;
            let mut digits = Felt252VecImpl::new();
            digits.resize(num_digits, 0);
            let mut tmp = MPNat { digits };
            if additional_zero_bits > 0 {
                tmp.digits.set(0, modulus.digits[trailing_zeros].shr(additional_zero_bits.into()));
                let mut i = 1;
                loop {
                    if i == num_digits {
                        break;
                    }

                    let d = modulus.digits[trailing_zeros + i];
                    tmp
                        .digits
                        .set(
                            i - 1,
                            tmp.digits[i
                                - 1]
                                + (d & power_of_two_mask)
                                    .shl((WORD_BITS - additional_zero_bits).into())
                        );
                    tmp.digits.set(i, d.shr(additional_zero_bits.into()));

                    i += 1;
                };
            } else {
                let mut slice = modulus
                    .digits
                    .clone_slice(trailing_zeros, modulus.digits.len() - trailing_zeros);
                tmp.digits.insert_vec(0, ref slice).unwrap();
            }
            if tmp.digits.len() > 0 {
                loop {
                    if tmp.digits[tmp.digits.len() - 1] != 0 {
                        break;
                    };

                    tmp.digits.pop().unwrap();
                };
            };
            tmp
        };

        let mut base_copy = MPNat { digits: self.digits.duplicate(), };
        let mut x1 = base_copy.modpow_montgomery(exp, ref odd);
        let mut x2 = self.modpow_with_power_of_two(exp, ref power_of_two);

        let mut odd_inv = MPNatTrait::koc_2017_inverse(
            ref odd, trailing_zeros * WORD_BITS + additional_zero_bits
        );

        let s = power_of_two.digits.len();
        let mut scratch: Felt252Vec<Word> = Felt252VecImpl::new();
        scratch.resize(s, 0);

        let mut diff = {
            let mut b = false;
            let mut i = 0;
            loop {
                if i == scratch.len() || i == s {
                    break;
                }

                let (diff, borrow) = borrowing_sub(
                    x2.digits.get(i).unwrap_or(0), x1.digits.get(i).unwrap_or(0), b,
                );

                scratch.set(i, diff);
                b = borrow;

                i += 1;
            };

            MPNat { digits: scratch }
        };

        let mut y = {
            let mut out: Felt252Vec<Word> = Felt252VecImpl::new();
            out.resize(s, 0);
            big_wrapping_mul(ref diff, ref odd_inv, ref out);

            out.set(out.len() - 1, out[out.len() - 1] & power_of_two_mask);
            MPNat { digits: out }
        };

        // Re-use allocation for efficiency
        let mut digits = diff.digits;
        let s = modulus.digits.len();
        digits.reset();
        digits.resize(s, 0);
        big_wrapping_mul(ref odd, ref y, ref digits);
        let mut c = false;

        let mut i = 0;
        loop {
            if i == digits.len() {
                break;
            };

            let out_digit = digits[i];

            let (sum, carry) = carrying_add(x1.digits.get(i).unwrap_or(0), out_digit, c);
            c = carry;
            digits.set(i, sum);

            i += 1;
        };

        MPNat { digits }
    }

    // Computes `self ^ exp mod modulus` using Montgomery multiplication.
    // See https://www.microsoft.com/en-us/research/wp-content/uploads/1996/01/j37acmon.pdf
    fn modpow_montgomery(ref self: MPNat, exp: Span<u8>, ref modulus: MPNat) -> MPNat {
        // n_prime satisfies `r * (r^(-1)) - modulus * n' = 1`, where
        // `r = 2^(WORD_BITS*modulus.digits.len())`.
        let n_prime = WORD_MAX - mod_inv(modulus.digits[0]) + 1;
        let s = modulus.digits.len;

        let mut digits = Felt252VecImpl::new();
        // safe unwrap, since intiail length is 0;
        digits.expand(s).unwrap();
        let mut x_bar = MPNat { digits };
        // Initialize result as `r mod modulus` (Montgomery form of 1)
        compute_r_mod_n(ref modulus, ref x_bar.digits);

        // Reduce base mod modulus
        self.sub_to_same_size(ref modulus);

        // Need to compute a_bar = base * r mod modulus;
        // First directly multiply base * r to get a 2s-digit number,
        // then reduce mod modulus.
        let mut a_bar = {
            let mut digits = Felt252VecImpl::new();
            digits.expand(2 * s).unwrap();
            let mut tmp = MPNat { digits };
            big_wrapping_mul(ref self, ref x_bar, ref tmp.digits);
            tmp.sub_to_same_size(ref modulus);
            tmp
        };

        // scratch space for monpro algorithm
        let mut scratch: Felt252Vec<Word> = Felt252VecImpl::new();
        scratch.expand(2 * s + 1).unwrap();
        let monpro_len = s + 2;

        let mut i = 0;
        loop {
            if i == exp.len() {
                break;
            }

            let b = *exp[i];

            let mut mask: u8 = 1.shl(7);

            loop {
                if mask == 0 {
                    break;
                };

                monsq(ref x_bar, ref modulus, n_prime, ref scratch);
                let mut slice = scratch.clone_slice(0, s);
                x_bar.digits.copy_from_vec_le(ref slice).unwrap();
                scratch.reset();

                if b & mask != 0 {
                    let mut slice = scratch.clone_slice(0, monpro_len);
                    monpro(ref x_bar, ref a_bar, ref modulus, n_prime, ref slice);
                    scratch.insert_vec(0, ref slice).unwrap();

                    let mut slice = scratch.clone_slice(0, s);
                    x_bar.digits.copy_from_vec_le(ref slice).unwrap();
                    scratch.reset();
                }
                mask = mask.shr(1);
            };

            i += 1;
        };

        // Convert out of Montgomery form by computing monpro with 1
        let mut one = {
            // We'll reuse the memory space from a_bar for efficiency.
            let mut digits = a_bar.digits;
            digits.reset();
            digits.set(0, 1);
            MPNat { digits }
        };

        let mut slice = scratch.clone_slice(0, monpro_len);
        monpro(ref x_bar, ref one, ref modulus, n_prime, ref slice);
        scratch.insert_vec(0, ref slice).unwrap();

        scratch.resize(s, 0);
        MPNat { digits: scratch }
    }

    fn modpow_with_power_of_two(ref self: MPNat, exp: Span<u8>, ref modulus: MPNat) -> MPNat {
        // We know `modulus` is a power of 2. So reducing is as easy as bit shifting.
        // We also know the modulus is non-zero because 0 is not a power of 2.

        // First reduce self to be the same size as the modulus
        self.force_same_size(ref modulus);

        // The modulus is a power of 2 but that power may not be a multiple of a whole word.
        // We can clear out any higher order bits to fix this.
        let modulus_mask = modulus.digits[modulus.digits.len() - 1] - 1;
        self.digits.set(self.digits.len() - 1, self.digits[self.digits.len() - 1] & modulus_mask);

        // We know that `totient(2^k) = 2^(k-1)`, therefore by Euler's theorem
        // we can also reduce the exponent mod `2^(k-1)`. Effectively this means
        // throwing away bytes to make `exp` shorter. Note: Euler's theorem only applies
        // if the base and modulus are coprime (which in this case means the base is odd).
        let exp = if self.is_odd() && (exp.len() > WORD_BYTES * modulus.digits.len()) {
            let i = exp.len() - WORD_BYTES * modulus.digits.len();
            exp.slice(i, exp.len() - i)
        } else {
            exp
        };

        let mut scratch_space = Felt252VecImpl::new();
        // safe unwrap, since the initial length is 0
        scratch_space.expand(modulus.digits.len()).unwrap();

        let mut result = big_wrapping_pow(ref self, exp, ref scratch_space);

        // The modulus is a power of 2 but that power may not be a multiple of a whole word.
        // We can clear out any higher order bits to fix this.

        result
            .digits
            .set(result.digits.len() - 1, result.digits[result.digits.len() - 1] & modulus_mask);

        result
    }


    /// Makes `self` have the same number of digits as `other` by
    /// pushing 0s or dropping higher order digits as needed.
    /// This is equivalent to reducing `self` modulo `2^(WORD_BITS*k)` where
    /// `k` is the number of digits in `other`.
    fn force_same_size(ref self: MPNat, ref other: MPNat) {
        self.digits.resize(other.digits.len, 0);
    }

    /// stips leading zeroes from little endian bytes
    /// # Arguments
    /// * `input` a Span<u8> in little endian
    /// # Returns
    /// * (Span<8>, bool), where span is the resulting Span after removing trailing zeroes, and the boolean indicates if all bytes were zero
    fn strip_leading_zeroes(v: Span<u8>) -> (Span<u8>, bool) {
        let mut arr: Array<u8> = Default::default();

        let mut i = 0;
        let mut num_of_trailing_zeroes = 0;
        loop {
            if (i == v.len()) || (*v[i] != 0) {
                break;
            }

            i += 1;
            num_of_trailing_zeroes += 1;
        };

        if num_of_trailing_zeroes == 0 {
            return (v, false);
        }

        if num_of_trailing_zeroes == v.len() {
            return (arr.span(), true);
        }

        arr.append_span(v.slice(num_of_trailing_zeroes, v.len() - num_of_trailing_zeroes));
        (arr.span(), false)
    }
}
