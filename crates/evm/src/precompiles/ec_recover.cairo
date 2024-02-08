use core::traits::Into;
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::Precompile;
use evm::stack::StackTrait;
use starknet::{
    EthAddress, eth_signature::{recover_public_key, public_key_point_to_eth_address, Signature},
    secp256k1::{Secp256k1Point}
};
use utils::helpers::EthAddressExTrait;
use utils::helpers::U8SpanExTrait;
use utils::helpers::{U256Trait, BoolIntoNumeric, ToBytes, FromBytes};
use utils::traits::EthAddressIntoU256;

const EC_RECOVER_PRECOMPILE_GAS_COST: u128 = 3000;

impl EcRecover of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x1 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let gas: u128 = EC_RECOVER_PRECOMPILE_GAS_COST;

        let message_hash = input.slice(0, 32);
        let message_hash = match message_hash.from_be_bytes() {
            Option::Some(message_hash) => message_hash,
            Option::None => { return Result::Ok((gas, array![].span())); }
        };

        let v: Option<u256> = input.slice(32, 32).from_be_bytes();
        let y_parity = match v {
            Option::Some(v) => {
                let y_parity = v - 27;
                if (y_parity == 0 || y_parity == 1) {
                    y_parity == 1
                } else {
                    return Result::Ok((gas, array![].span()));
                }
            },
            Option::None => { return Result::Ok((gas, array![].span())); }
        };

        let r: Option<u256> = input.slice(64, 32).from_be_bytes();
        let r = match r {
            Option::Some(r) => r,
            Option::None => { return Result::Ok((gas, array![].span())); }
        };

        let s: Option<u256> = input.slice(96, 32).from_be_bytes();
        let s = match s {
            Option::Some(s) => s,
            Option::None => { return Result::Ok((gas, array![].span())); }
        };

        let signature = Signature { r, s, y_parity };

        let recovered_public_key =
            match recover_public_key::<Secp256k1Point>(message_hash, signature) {
            Option::Some(public_key_point) => public_key_point,
            Option::None => { return Result::Ok((gas, array![].span())); }
        };

        let eth_address: u256 = public_key_point_to_eth_address(recovered_public_key).into();
        let eth_address = eth_address.to_be_bytes_padded();

        return Result::Ok((gas, eth_address));
    }
}
