use core::circuit::u384;
use core::option::Option;
use core::starknet::{EthAddress};

use crate::errors::EVMError;
use crate::precompiles::Precompile;
use crate::precompiles::ec_operations::{is_on_curve, BN254_PRIME};
use utils::traits::bytes::{ToBytes, U8SpanExTrait, FromBytes};

const BASE_COST: u64 = 45000;
const U256_BYTES_LEN: usize = 32;
// pub impl EcPairing of Precompile {
//     fn address() -> EthAddress {
//         0x8.try_into().unwrap()
//     }

//     fn exec(mut input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
//         let gas = BASE_COST;

//         // Pad the input to 128 bytes to avoid out-of-bounds accesses
//         let mut input = input.pad_right_with_zeroes(96);

//         let x1: u256 = input.slice(0, 32).from_be_bytes().unwrap();

//         let y1: u256 = input.slice(32, 32).from_be_bytes().unwrap();

//         let s: u256 = input.slice(64, 32).from_be_bytes().unwrap();

//         let (x, y) = match ec_mul(x1, y1, s) {
//             Option::Some((x, y)) => { (x, y) },
//             Option::None => {
//                 return Result::Err(EVMError::InvalidParameter('invalid ec_mul parameters'));
//             },
//         };

//         // Append x and y to the result bytes.
//         let mut result_bytes = array![];
//         let x_bytes = x.to_be_bytes_padded();
//         result_bytes.append_span(x_bytes);
//         let y_bytes = y.to_be_bytes_padded();
//         result_bytes.append_span(y_bytes);

//         return Result::Ok((gas, result_bytes.span()));
//     }
// }

// #[cfg(test)]
// mod tests {
//     use super::ec_mul;

//     #[test]
//     fn test_ec_mul() {
//         let (x1, y1, s) = (1, 2, 2);
//         let (x, y) = ec_mul(x1, y1, s).expect('ec_mul failed');
//         assert_eq!(x, 0x030644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd3);
//         assert_eq!(y, 0x15ed738c0e0a7c92e7845f96b2ae9c0a68a6a449e3538fc7ff3ebf7a5a18a2c4);
//     }
// }

