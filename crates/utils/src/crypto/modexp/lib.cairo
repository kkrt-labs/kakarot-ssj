// CREDITS: The implementation has been take from
// [aurora-engine](https://github.com/aurora-is-near/aurora-engine/tree/develop/engine-modexp)

use crate::crypto::modexp::mpnat::MPNatTrait;
use crate::felt_vec::{Felt252VecTrait};

/// Computes `(base ^ exp) % modulus`, where all values are given as big-endian
/// encoded bytes.
pub fn modexp(base: Span<u8>, exp: Span<u8>, modulus: Span<u8>) -> Span<u8> {
    println!("Start: MPNAT::from_big_endian operation");
    let mut x = MPNatTrait::from_big_endian(base);
    let mut m = MPNatTrait::from_big_endian(modulus);
    println!("End: MPNAT::from_big_endian operation");

    if m.digits.len == 1 && m.digits[0] == 0 {
        return [].span();
    }

    println!("Start: modpow operation");
    let mut result = x.modpow(exp, ref m);
    println!("End: modpow operation");
    result.digits.to_be_bytes()
}
