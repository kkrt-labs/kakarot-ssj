use core::circuit::u384;
use core::option::Option;
use core::starknet::{EthAddress};
use evm::errors::EVMError;
use evm::precompiles::Precompile;

use evm::precompiles::ec_add::{is_on_curve, double_ec_point_unchecked, ec_safe_add};
use utils::helpers::{load_word, ToBytes};

// const BN254_ORDER: u256 = 0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000001;

const BASE_COST: u64 = 6000;
const U256_BYTES_LEN: usize = 32;

pub impl EcMul of Precompile {
    fn address() -> EthAddress {
        0x7.try_into().unwrap()
    }

    fn exec(mut input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = BASE_COST;

        let x1_bytes = *(input.multi_pop_front::<32>().unwrap());
        let x1: u256 = load_word(U256_BYTES_LEN, x1_bytes.unbox().span());

        let y1_bytes = *(input.multi_pop_front::<32>().unwrap());
        let y1: u256 = load_word(U256_BYTES_LEN, y1_bytes.unbox().span());

        let s_bytes = *(input.multi_pop_front::<32>().unwrap());
        let s: u256 = load_word(U256_BYTES_LEN, s_bytes.unbox().span());

        let (x, y) = match ec_mul(x1, y1, s) {
            Option::Some((x, y)) => { (x, y) },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('invalid ec_mul parameters'));
            },
        };

        // Append x and y to the result bytes.
        let mut result_bytes = array![];
        let x_bytes = x.to_be_bytes_padded();
        result_bytes.append_span(x_bytes);
        let y_bytes = y.to_be_bytes_padded();
        result_bytes.append_span(y_bytes);

        return Result::Ok((gas, result_bytes.span()));
    }
}

// Returns Option::None in case of error.
fn ec_mul(x1: u256, y1: u256, s: u256) -> Option<(u256, u256)> {
    if x1 == 0 && y1 == 0 {
        // Input point is at infinity, return it
        return Option::Some((x1, y1));
    } else {
        // Point is not at infinity
        let x1_u384: u384 = x1.into();
        let y1_u384: u384 = y1.into();

        if is_on_curve(x1_u384, y1_u384) {
            if s == 0 {
                return Option::Some((0, 0));
            } else if s == 1 {
                return Option::Some((x1, y1));
            } else {
                // Point is on the curve.
                // s is >= 2.
                let bits = get_bits_little(s);
                let pt = ec_mul_inner((x1_u384, y1_u384), bits);
                match pt {
                    Option::Some((
                        x, y
                    )) => Option::Some((x.try_into().unwrap(), y.try_into().unwrap())),
                    Option::None => Option::Some((0, 0)),
                }
            }
        } else {
            // Point is not on the curve
            return Option::None;
        }
    }
}

// Returns the bits of the 256 bit number in little endian format.
fn get_bits_little(s: u256) -> Array<felt252> {
    let mut bits = ArrayTrait::new();
    let mut s_low = s.low;
    while s_low != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_low, 2);
        bits.append(r.into());
        s_low = q;
    };
    let mut s_high = s.high;

    while s_high != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_high, 2);
        bits.append(r.into());
        s_high = q;
    };
    bits
}


// Should not be called outside of ec_mul.
// Returns Option::None in case of point at infinity.
// The size of bits array must be at minimum 2 and the point must be on the curve.
fn ec_mul_inner(pt: (u384, u384), mut bits: Array<felt252>) -> Option<(u384, u384)> {
    let (x_o, y_o) = pt;
    let mut pt = Option::Some(pt);
    while let Option::Some(bit) = bits.pop_front() {
        match pt {
            Option::Some((xt, yt)) => pt = Option::Some(double_ec_point_unchecked(xt, yt)),
            Option::None => pt = Option::None,
        }

        if bit != 0 {
            match pt {
                Option::Some((xt, yt)) => pt = ec_safe_add(x_o, y_o, xt, yt),
                Option::None => pt = Option::Some((x_o, y_o)),
            };
        };
    };

    pt
}
