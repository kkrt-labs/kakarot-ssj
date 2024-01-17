use utils::crypto::modexp::mpnat::MPNatTrait;
use utils::helpers::Felt252VecTrait;
use utils::helpers::Felt252VecU64Trait;
use utils::tests::test_modexp_arith::Felt252TestTrait;

/// Computes `(base ^ exp) % modulus`, where all values are given as big-endian
/// encoded bytes.
pub fn modexp(base: Span<u8>, exp: Span<u8>, modulus: Span<u8>) -> Span<u8> {
    let mut x = MPNatTrait::from_big_endian(base);
    let mut m = MPNatTrait::from_big_endian(modulus);

    println!("m here is");
    m.digits.print_dict();

    if m.digits.len == 1 && m.digits[0] == 0 {
        return array![].span();
    }

    let mut result = x.modpow(exp, ref m);
    println!("resultr....");
    result.digits.print_dict();
    println!("result len ... {}", result.digits.len);
    result.digits.to_be_bytes()
}
