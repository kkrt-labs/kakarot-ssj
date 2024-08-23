use core::RangeCheck;
use core::circuit::CircuitElement as CE;
use core::circuit::CircuitInput as CI;

use core::circuit::{
    RangeCheck96, AddMod, MulMod, u384, u96, CircuitElement, CircuitInput, circuit_add, circuit_sub,
    circuit_mul, circuit_inverse, EvalCircuitResult, EvalCircuitTrait, CircuitOutputsTrait,
    CircuitModulus, AddInputResultTrait, CircuitInputs, CircuitInputAccumulator
};


use core::internal::BoundedInt;
use core::option::Option;
use core::starknet::SyscallResultTrait;
use core::starknet::{EthAddress};
use evm::errors::{EVMError};
use evm::precompiles::Precompile;
use garaga::core::circuit::AddInputResultTrait2;
use garaga::utils::u384_eq_zero;
use utils::helpers::{U256Trait, ToBytes, FromBytes};


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
                        (u384_circuit_output_to_u256(x), u384_circuit_output_to_u256(y))
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
fn ec_safe_add(x1: u384, y1: u384, x2: u384, y2: u384) -> Option<(u384, u384)> {
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
fn is_on_curve(x: u384, y: u384) -> bool {
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
    return u384_eq_zero(zero_check);
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
fn double_ec_point_unchecked(x: u384, y: u384) -> (u384, u384) {
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

    return u384_eq_zero(outputs.get_output(sub));
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

    return u384_eq_zero(outputs.get_output(check));
}
type ConstValue<const VALUE: felt252> = BoundedInt<VALUE, VALUE>;
const POW64: felt252 = 0x10000000000000000;
const POW32: felt252 = 0x100000000;
const POW96: felt252 = 0x1000000000000000000000000;
const POW32_TYPED: ConstValue<POW32> = 0x100000000;
const NZ_POW32_TYPED: NonZero<ConstValue<POW32>> = 0x100000000;

const NZ_POW64_TYPED: NonZero<ConstValue<POW64>> = 0x10000000000000000;


trait DivRemHelper<Lhs, Rhs> {
    type DivT;
    type RemT;
}
impl DivRemU96By64 of DivRemHelper<u96, ConstValue<POW64>> {
    type DivT = BoundedInt<0, { POW32 - 1 }>;
    type RemT = BoundedInt<0, { POW64 - 1 }>;
}

impl DivRemU96By32 of DivRemHelper<u96, ConstValue<POW32>> {
    type DivT = BoundedInt<0, { POW64 - 1 }>;
    type RemT = BoundedInt<0, { POW32 - 1 }>;
}

extern fn bounded_int_div_rem<Lhs, Rhs, impl H: DivRemHelper<Lhs, Rhs>>(
    lhs: Lhs, rhs: NonZero<Rhs>,
) -> (H::DivT, H::RemT) implicits(RangeCheck) nopanic;


// Cuts a u384 into a u256.
// Must be used on circuit outputs ran with a p <=256 bits
// so that the outputs are guaranteed to be less than p.
fn u384_circuit_output_to_u256(x: u384) -> u256 {
    // limb3_96 || limb2_96 || limb1_96 || limb0_96
    let (q_limb1_64, r_limb1_32) = bounded_int_div_rem(x.limb1, NZ_POW32_TYPED);
    // limb3_96 || limb2_96 || q_limb1_64 || r_limb1_32 || limb0_96
    let low: felt252 = (r_limb1_32.into() * POW96) + x.limb0.into();
    // limb3_96 || limb2_96 || q_limb1_64 || low_128
    let (_q_limb2_32, r_limb2_64) = bounded_int_div_rem(x.limb2, NZ_POW64_TYPED);
    // limb3_96 || q_limb2_32 || r_limb2_64 || q_limb1_64 || low_128

    let high: felt252 = (r_limb2_64.into() * POW64) + q_limb1_64.into();

    return u256 { low: low.try_into().unwrap(), high: high.try_into().unwrap() };
}

#[cfg(test)]
mod tests {
    use super::{
        u384_circuit_output_to_u256, eq_mod_p, eq_neg_mod_p, double_ec_point_unchecked,
        add_ec_point_unchecked, is_on_curve, u384, POW32, POW64, POW96
    };
    use utils::helpers::{U256Trait, ToBytes, FromBytes};

    #[test]
    fn test_u384_circuit_output_to_u256() {
        let x = u384 { limb0: 0x1, limb1: 0x0, limb2: 0x0, limb3: 0x0 };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x1, high: 0x0 });
        let x = u384 { limb0: 0x0, limb1: 0x0, limb2: 0x0, limb3: 0x0 };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x0, high: 0x0 });
        let x = u384 { limb0: 0xc77661, limb1: 0x0, limb2: 0x0, limb3: 0x0 };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0xc77661, high: 0x0 });
        let x = u384 { limb0: 0xa1f1ae97, limb1: 0x0, limb2: 0x0, limb3: 0x0 };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0xa1f1ae97, high: 0x0 });

        let x = u384 { limb0: 0x6dbd0f5925f2ea8792be851d, limb1: 0x60, limb2: 0x0, limb3: 0x0 };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x606dbd0f5925f2ea8792be851d, high: 0x0 });

        let x = u384 { limb0: 0x288ad273930c8e07bee0b040, limb1: 0x9a80, limb2: 0x0, limb3: 0x0 };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x9a80288ad273930c8e07bee0b040, high: 0x0 });

        let x = u384 {
            limb0: 0x79f59cab560d347406f8f978, limb1: 0x32355e68, limb2: 0x0, limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x32355e6879f59cab560d347406f8f978, high: 0x0 });

        let x = u384 {
            limb0: 0xf7c12fd7cd43a2091356f287, limb1: 0x5670d3784d, limb2: 0x0, limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x70d3784df7c12fd7cd43a2091356f287, high: 0x56 });

        let x = u384 {
            limb0: 0x4def54e61b4eee26c407edc8, limb1: 0x6a3d1d0cac6d, limb2: 0x0, limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x1d0cac6d4def54e61b4eee26c407edc8, high: 0x6a3d });

        let x = u384 {
            limb0: 0xa666c4bd0b0f6ac7bfc6697,
            limb1: 0x55354b07685a19836f45e3,
            limb2: 0x0,
            limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x836f45e30a666c4bd0b0f6ac7bfc6697, high: 0x55354b07685a19 });

        let x = u384 {
            limb0: 0xf99e6e4a89d4c4bf4eeb5764,
            limb1: 0xba69422bccfb0bf07a497f6b,
            limb2: 0x0,
            limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0x7a497f6bf99e6e4a89d4c4bf4eeb5764, high: 0xba69422bccfb0bf0 });

        let x = u384 {
            limb0: 0xa18fd325c835625f53342a9f,
            limb1: 0x3f862f6ff3d3c356f4262ef4,
            limb2: 0xda,
            limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(y, u256 { low: 0xf4262ef4a18fd325c835625f53342a9f, high: 0xda3f862f6ff3d3c356 });

        let x = u384 {
            limb0: 0x4332f4d7188cef59cbdef8db,
            limb1: 0xbb3e59509bf71bec4abd71f1,
            limb2: 0x4bb761b32d048,
            limb3: 0x0
        };
        let y = u384_circuit_output_to_u256(x);
        assert_eq!(
            y,
            u256 { low: 0x4abd71f14332f4d7188cef59cbdef8db, high: 0x4bb761b32d048bb3e59509bf71bec }
        );
    }
}
