use core::starknet::SyscallResultTrait;
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use evm::precompiles::Precompile;
use starknet::{
    EthAddress, eth_signature::{recover_public_key, public_key_point_to_eth_address, Signature},
    secp256r1::{Secp256r1Point, secp256r1_new_syscall}, secp256_trait::is_valid_signature
};
use utils::helpers::{U256Trait, ToBytes, FromBytes};

const P256VERIFY_PRECOMPILE_GAS_COST: u128 = 3450;

impl P256Verify of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 11 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let gas: u128 = P256VERIFY_PRECOMPILE_GAS_COST;

        let message_hash = input.slice(0, 32);
        let message_hash = match message_hash.from_be_bytes() {
            Option::Some(message_hash) => message_hash,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
            }
        };

        let r: Option<u256> = input.slice(32, 32).from_be_bytes();
        let r = match r {
            Option::Some(r) => r,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
            }
        };

        let s: Option<u256> = input.slice(64, 32).from_be_bytes();
        let s = match s {
            Option::Some(s) => s,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
            }
        };

        let x: Option<u256> = input.slice(96, 32).from_be_bytes();
        let x = match x {
            Option::Some(x) => x,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
            }
        };

        let y: Option<u256> = input.slice(128, 32).from_be_bytes();
        let y = match y {
            Option::Some(y) => y,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
            }
        };

        let public_key: Option<Secp256r1Point> = secp256r1_new_syscall(x, y).unwrap_syscall();
        let public_key = match public_key {
            Option::Some(public_key) => public_key,
            Option::None => {
                return Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR));
            }
        };

        if !is_valid_signature(message_hash, r, s, public_key) {
            return Result::Ok((gas, array![0].span()));
        }

        return Result::Ok((gas, array![1].span()));
    }
}
