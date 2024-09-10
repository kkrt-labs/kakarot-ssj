use core::circuit::CircuitElement as CE;
use core::circuit::CircuitInput as CI;

use core::circuit::{
    u384, CircuitElement, CircuitInput, circuit_add, circuit_sub, circuit_mul, circuit_inverse,
    EvalCircuitTrait, CircuitOutputsTrait, CircuitModulus, CircuitInputs
};
use core::num::traits::Zero;
use core::option::Option;
use core::starknet::{EthAddress};
use evm::errors::EVMError;
use evm::precompiles::Precompile;
use garaga::core::circuit::AddInputResultTrait2;
use utils::helpers::ToBytes;
use utils::helpers::load_word;


const BASE_COST: u64 = 150;
const U256_BYTES_LEN: usize = 32;

pub impl EcAdd of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x6.try_into().unwrap()
    }

    fn exec(mut input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = BASE_COST;

        let x1_bytes = *(input.multi_pop_front::<32>().unwrap());
        let x1: u256 = load_word(U256_BYTES_LEN, x1_bytes.unbox().span());

        let y1_bytes = *(input.multi_pop_front::<32>().unwrap());
        let y1: u256 = load_word(U256_BYTES_LEN, y1_bytes.unbox().span());

        let x2_bytes = *(input.multi_pop_front::<32>().unwrap());
        let x2: u256 = load_word(U256_BYTES_LEN, x2_bytes.unbox().span());

        let y2_bytes = *(input.multi_pop_front::<32>().unwrap());
        let y2: u256 = load_word(U256_BYTES_LEN, y2_bytes.unbox().span());

        let (x, y) = match ec_add(x1, y1, x2, y2) {
            Option::Some((x, y)) => { (x, y) },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('invalid ec_add parameters'));
            },
        };

        let mut result_bytes = array![];
        // Append x to the result bytes.
        let x_bytes = x.to_be_bytes_padded();
        result_bytes.append_span(x_bytes);
        // Append y to the result bytes.
        let y_bytes = y.to_be_bytes_padded();
        result_bytes.append_span(y_bytes);

        return Result::Ok((gas, result_bytes.span()));
    }
}


fn ec_add(x1: u256, y1: u256, x2: u256, y2: u256) -> Option<(u256, u256)> {
    if x1 == 0 && y1 == 0 {
        if x2 == 0 && y2 == 0 {
            // Both are points at infinity, return either of them.
            return Option::Some((x2, y2));
        } else {
            // Only first point is at infinity.
            let x2_u384: u384 = x2.into();
            let y2_u384: u384 = y2.into();
            if is_on_curve(x2_u384, y2_u384) {
                // Second point is on the curve, return it.
                return Option::Some((x2, y2));
            } else {
                // Second point is not on the curve, return None (error).
                return Option::None;
            }
        }
    } else {
        if x2 == 0 && y2 == 0 {
            // Only second point is at infinity.
            let x1_u384: u384 = x1.into();
            let y1_u384: u384 = y1.into();
            if is_on_curve(x1_u384, y1_u384) {
                // First point is on the curve, return it.
                return Option::Some((x1, y1));
            } else {
                // First point is not on the curve, return None (error).
                return Option::None;
            }
        } else {
            // None of the points are at infinity.
            let x1_u384: u384 = x1.into();
            let x2_u384: u384 = x2.into();
            let y1_u384: u384 = y1.into();
            let y2_u384: u384 = y2.into();

            if is_on_curve(x1_u384, y1_u384) && is_on_curve(x2_u384, y2_u384) {
                match ec_safe_add(x1_u384, y1_u384, x2_u384, y2_u384) {
                    Option::Some((
                        x, y
                    )) => Option::Some(
                        (
                            TryInto::<u384, u256>::try_into(x).unwrap(),
                            TryInto::<u384, u256>::try_into(y).unwrap()
                        )
                    ),
                    Option::None => Option::Some((0, 0)),
                }
            } else {
                // None of the points are infinity and at least one of them is not on the curve.
                return Option::None;
            }
        }
    }
}


// assumes that the points are on the curve and not the point at infinity.
// Returns None if the points are the same and opposite y coordinates (Point at infinity)
pub fn ec_safe_add(x1: u384, y1: u384, x2: u384, y2: u384) -> Option<(u384, u384)> {
    let same_x = eq_mod_p(x1, x2);

    if same_x {
        let opposite_y = eq_neg_mod_p(y1, y2);

        if opposite_y {
            return Option::None;
        } else {
            let (x, y) = double_ec_point_unchecked(x1, y1);
            return Option::Some((x, y));
        }
    } else {
        let (x, y) = add_ec_point_unchecked(x1, y1, x2, y2);
        return Option::Some((x, y));
    }
}


// Check if a point is on the curve.
// Point at infinity (0,0) will return false.
pub fn is_on_curve(x: u384, y: u384) -> bool {
    let (b, _x, _y) = (CE::<CI<0>> {}, CE::<CI<1>> {}, CE::<CI<2>> {});

    // Compute (y^2 - (x^2 + b)) % p_bn254
    let x2 = circuit_mul(_x, _x);
    let y2 = circuit_mul(_y, _y);
    let y3 = circuit_mul(_y, y2);
    let rhs = circuit_add(x2, b);
    let check = circuit_sub(y3, rhs);

    let modulus = TryInto::<
        _, CircuitModulus
    >::try_into([0x6871ca8d3c208c16d87cfd47, 0xb85045b68181585d97816a91, 0x30644e72e131a029, 0x0])
        .unwrap(); // BN254 prime field modulus

    let mut circuit_inputs = (check,).new_inputs();
    // Prefill constants:
    circuit_inputs = circuit_inputs.next_2([3, 0, 0, 0]);
    // Fill inputs:
    circuit_inputs = circuit_inputs.next_2(x);
    circuit_inputs = circuit_inputs.next_2(y);

    let outputs = circuit_inputs.done_2().eval(modulus).unwrap();
    let zero_check: u384 = outputs.get_output(check);
    return zero_check.is_zero();
}


// Add two BN254 EC points without checking if:
// - the points are on the curve
// - the points are not the same
// - none of the points are the point at infinity
fn add_ec_point_unchecked(xP: u384, yP: u384, xQ: u384, yQ: u384) -> (u384, u384) {
    // INPUT stack
    let (_xP, _yP, _xQ, _yQ) = (CE::<CI<0>> {}, CE::<CI<1>> {}, CE::<CI<2>> {}, CE::<CI<3>> {});

    let num = circuit_sub(_yP, _yQ);
    let den = circuit_sub(_xP, _xQ);
    let inv_den = circuit_inverse(den);
    let slope = circuit_mul(num, inv_den);
    let slope_sqr = circuit_mul(slope, slope);

    let nx = circuit_sub(circuit_sub(slope_sqr, _xP), _xQ);
    let ny = circuit_sub(circuit_mul(slope, circuit_sub(_xP, nx)), _yP);

    let modulus = TryInto::<
        _, CircuitModulus
    >::try_into([0x6871ca8d3c208c16d87cfd47, 0xb85045b68181585d97816a91, 0x30644e72e131a029, 0x0])
        .unwrap(); // BN254 prime field modulus

    let mut circuit_inputs = (nx, ny,).new_inputs();
    // Fill inputs:
    circuit_inputs = circuit_inputs.next_2(xP); // in1
    circuit_inputs = circuit_inputs.next_2(yP); // in2
    circuit_inputs = circuit_inputs.next_2(xQ); // in3
    circuit_inputs = circuit_inputs.next_2(yQ); // in4

    let outputs = circuit_inputs.done_2().eval(modulus).unwrap();

    (outputs.get_output(nx), outputs.get_output(ny))
}

// Double BN254 EC point without checking if the point is on the curve
pub fn double_ec_point_unchecked(x: u384, y: u384) -> (u384, u384) {
    // CONSTANT stack
    let in0 = CE::<CI<0>> {}; // 0x3
    // INPUT stack
    let (_x, _y) = (CE::<CI<1>> {}, CE::<CI<2>> {});

    let x2 = circuit_mul(_x, _x);
    let num = circuit_mul(in0, x2);
    let den = circuit_add(_y, _y);
    let inv_den = circuit_inverse(den);
    let slope = circuit_mul(num, inv_den);
    let slope_sqr = circuit_mul(slope, slope);

    let nx = circuit_sub(circuit_sub(slope_sqr, _x), _x);
    let ny = circuit_sub(_y, circuit_mul(slope, circuit_sub(_x, nx)));

    let modulus = TryInto::<
        _, CircuitModulus
    >::try_into([0x6871ca8d3c208c16d87cfd47, 0xb85045b68181585d97816a91, 0x30644e72e131a029, 0x0])
        .unwrap(); // BN254 prime field modulus

    let mut circuit_inputs = (nx, ny,).new_inputs();
    // Prefill constants:
    circuit_inputs = circuit_inputs.next_2([0x3, 0x0, 0x0, 0x0]); // in0
    // Fill inputs:
    circuit_inputs = circuit_inputs.next_2(x); // in1
    circuit_inputs = circuit_inputs.next_2(y); // in2

    let outputs = circuit_inputs.done_2().eval(modulus).unwrap();

    (outputs.get_output(nx), outputs.get_output(ny))
}
// returns true if a == b mod p_bn254
fn eq_mod_p(a: u384, b: u384) -> bool {
    let in1 = CircuitElement::<CircuitInput<0>> {};
    let in2 = CircuitElement::<CircuitInput<1>> {};
    let sub = circuit_sub(in1, in2);

    let modulus = TryInto::<
        _, CircuitModulus
    >::try_into([0x6871ca8d3c208c16d87cfd47, 0xb85045b68181585d97816a91, 0x30644e72e131a029, 0x0])
        .unwrap(); // BN254 prime field modulus

    let outputs = (sub,).new_inputs().next_2(a).next_2(b).done_2().eval(modulus).unwrap();

    return outputs.get_output(sub).is_zero();
}

// returns true if a == -b mod p_bn254
fn eq_neg_mod_p(a: u384, b: u384) -> bool {
    let _a = CE::<CI<0>> {};
    let _b = CE::<CI<1>> {};
    let check = circuit_add(_a, _b);

    let modulus = TryInto::<
        _, CircuitModulus
    >::try_into([0x6871ca8d3c208c16d87cfd47, 0xb85045b68181585d97816a91, 0x30644e72e131a029, 0x0])
        .unwrap(); // BN254 prime field modulus

    let outputs = (check,).new_inputs().next_2(a).next_2(b).done_2().eval(modulus).unwrap();

    return outputs.get_output(check).is_zero();
}
