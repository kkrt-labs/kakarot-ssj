use core::starknet::SyscallResultTrait;
use core::starknet::{
    EthAddress, eth_signature::{recover_public_key, public_key_point_to_eth_address, Signature},
    secp256r1::{Secp256r1Point, secp256r1_new_syscall}, secp256_trait::is_valid_signature
};
use evm::errors::{EVMError};
use evm::precompiles::Precompile;
use utils::helpers::{U256Trait, ToBytes, FromBytes};

const P256VERIFY_PRECOMPILE_GAS_COST: u128 = 3450;

impl P256Verify of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x100 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let gas: u128 = P256VERIFY_PRECOMPILE_GAS_COST;

        if input.len() != 160 {
            return Result::Ok((gas, [].span()));
        }

        let message_hash = input.slice(0, 32);
        let message_hash = match message_hash.from_be_bytes() {
            Option::Some(message_hash) => message_hash,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let r: Option<u256> = input.slice(32, 32).from_be_bytes();
        let r = match r {
            Option::Some(r) => r,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let s: Option<u256> = input.slice(64, 32).from_be_bytes();
        let s = match s {
            Option::Some(s) => s,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let x: Option<u256> = input.slice(96, 32).from_be_bytes();
        let x = match x {
            Option::Some(x) => x,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let y: Option<u256> = input.slice(128, 32).from_be_bytes();
        let y = match y {
            Option::Some(y) => y,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let public_key: Option<Secp256r1Point> = secp256r1_new_syscall(x, y).unwrap_syscall();
        let public_key = match public_key {
            Option::Some(public_key) => public_key,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        if !is_valid_signature(message_hash, r, s, public_key) {
            return Result::Ok((gas, [].span()));
        }

        return Result::Ok((gas, [1].span()));
    }
}

#[cfg(test)]
mod tests {
    use contracts::test_utils::setup_contracts_for_testing;
    use core::array::ArrayTrait;
    use evm::instructions::system_operations::SystemOperationsTrait;
    use evm::memory::InternalMemoryTrait;
    use evm::memory::MemoryTrait;

    use evm::precompiles::p256verify::P256Verify;
    use evm::stack::StackTrait;
    use evm::test_utils::{VMBuilderTrait};
    use utils::helpers::{U256Trait, ToBytes, FromBytes};


    // source:
    // <https://github.com/ethereum/go-ethereum/pull/27540/files#diff-3548292e7ee4a75fc8146397c6baf5c969f6fe6cd9355df322cdb4f11103e004>
    #[test]
    fn test_p256verify_precompile() {
        let msg_hash = 0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d_u256
            .to_be_bytes_padded();
        let r = 0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac_u256
            .to_be_bytes_padded();
        let s = 0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60_u256
            .to_be_bytes_padded();
        let x = 0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3_u256
            .to_be_bytes_padded();
        let y = 0x7618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(r);
        calldata.append_span(s);
        calldata.append_span(x);
        calldata.append_span(y);

        let (gas, result) = P256Verify::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        assert_eq!(result, 0x01);
        assert_eq!(gas, 3450);
    }

    // source:
    // <https://github.com/ethereum/go-ethereum/pull/27540/files#diff-3548292e7ee4a75fc8146397c6baf5c969f6fe6cd9355df322cdb4f11103e004>
    #[test]
    fn test_p256verify_precompile_static_call() {
        let (_, _) = setup_contracts_for_testing();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .memory
            .store(
                0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d, 0x0
            ); // msg_hash
        vm
            .memory
            .store(0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac, 0x20); // r
        vm
            .memory
            .store(0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60, 0x40); // s
        vm
            .memory
            .store(0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3, 0x60); // x
        vm
            .memory
            .store(0x7618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e, 0x80); // y

        vm.stack.push(0x01).unwrap(); // retSize
        vm.stack.push(0xa0).unwrap(); // retOffset
        vm.stack.push(0xa0).unwrap(); // argsSize
        vm.stack.push(0x0).unwrap(); // argsOffset
        vm.stack.push(0x100).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.exec_staticcall().unwrap();

        let mut result = Default::default();
        vm.memory.load_n(0x1, ref result, 0xa0);

        assert_eq!(result, array![0x01]);
    }

    #[test]
    fn test_p256verify_precompile_input_too_short() {
        let msg_hash = 0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d_u256
            .to_be_bytes_padded();
        let r = 0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac_u256
            .to_be_bytes_padded();
        let s = 0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60_u256
            .to_be_bytes_padded();
        let x = 0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(r);
        calldata.append_span(s);
        calldata.append_span(x);

        let (gas, result) = P256Verify::exec(calldata.span()).unwrap();

        assert_eq!(result, [].span());
        assert_eq!(gas, 3450);
    }

    #[test]
    fn test_p256verify_precompile_input_too_short_static_call() {
        let (_, _) = setup_contracts_for_testing();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .memory
            .store(
                0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d, 0x0
            ); // msg_hash
        vm
            .memory
            .store(0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac, 0x20); // r
        vm
            .memory
            .store(0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60, 0x40); // s
        vm
            .memory
            .store(0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3, 0x60); // x

        vm.stack.push(0x01).unwrap(); // retSize
        vm.stack.push(0x80).unwrap(); // retOffset
        vm.stack.push(0x80).unwrap(); // argsSize
        vm.stack.push(0x0).unwrap(); // argsOffset
        vm.stack.push(0x100).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.exec_staticcall().unwrap();

        let mut result = Default::default();
        vm.memory.load_n(0x1, ref result, 0x80);

        assert_eq!(result, array![0]);
    }
}
