use core::circuit::CircuitInputs;
use core::iter::IntoIterator;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::Precompile;
use utils::helpers::{FromBytes, ToBytes};
use core::sha256::compute_sha256_u32_array;
use utils::helpers::Bitshift;
use starknet::EthAddress;

const BASE_COST: u128 = 60;
const COST_PER_WORD: u128 = 12;

impl Sha256 of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x2 }
    }

    fn exec(mut input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        let mut sha256_input: Array<u32> = array![];
        while let Option::Some(bytes4) = input.multi_pop_front::<4>() {
            let bytes4 = (*bytes4).unbox();
            sha256_input.append(FromBytes::from_be_bytes(bytes4.span()).unwrap());
        };
        let (last_input_word, last_input_num_bytes) = if input.len() == 0 {
            (0, 0)
        } else {
            let mut last_input_word: u32 = 0;
            let mut last_input_num_bytes: u32 = 0;
            while let Option::Some(byte) = input.pop_front() {
                last_input_word = last_input_word.shl(8) + (*byte).into();
                last_input_num_bytes += 1;
            };
            (last_input_word, last_input_num_bytes)
        };
        let result_words_32: [u32; 8] = compute_sha256_u32_array(
            sha256_input, last_input_word, last_input_num_bytes
        );
        let mut result_bytes = array![];
        for word in result_words_32
            .span() {
                let word_bytes = (*word).to_be_bytes();
                result_bytes.append_span(word_bytes);
            };

        return Result::Ok((gas, result_bytes.span()));
    }
}

#[cfg(test)]
mod tests {
    use contracts::test_utils::{setup_contracts_for_testing};
    use core::result::ResultTrait;
    use evm::instructions::system_operations::SystemOperationsTrait;

    use evm::memory::MemoryTrait;
    use evm::precompiles::sha256::Sha256;
    use evm::stack::StackTrait;
    use evm::test_utils::{VMBuilderTrait, native_token, other_starknet_address};
    use starknet::testing::set_contract_address;
    use utils::helpers::{FromBytes};

    //source:
    //<https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcallZSizeZ_1XSizeb1FX_2jaddressY4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Y1j//%20v%5Cnq%20thVj%20wb~0x_Offset~Zb20jretYvPUSHXjargsWt%20Ve%20%01VWXYZ_bjqvw~_>
    #[test]
    fn test_sha_256_precompile() {
        let calldata = array![0xFF];

        let (gas, result) = Sha256::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;

        assert_eq!(result, expected_result);
        assert_eq!(gas, 72);
    }

    #[test]
    fn test_sha_256_precompile_full_word() {
        let calldata = ToBytes::to_bytes(
            0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89
        );

        let (gas, result) = Sha256::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;

        assert_eq!(result, expected_result);
        assert_eq!(gas, 72);
    }


    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcallZSizeZ_1XSizeb1FX_2jaddressY4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Y1j//%20v%5Cnq%20thVj%20wb~0x_Offset~Zb20jretYvPUSHXjargsWt%20Ve%20%01VWXYZ_bjqvw~_>
    #[test]
    fn test_sha_256_precompile_static_call() {
        let (_, _) = setup_contracts_for_testing();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0x20).unwrap(); // retOffset
        vm.stack.push(0x1).unwrap(); // argsSize
        vm.stack.push(0x1F).unwrap(); // argsOffset
        vm.stack.push(0x2).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.memory.store(0xFF, 0x0);

        vm.exec_staticcall().unwrap();

        let result = vm.memory.load(0x20);
        let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;
        assert_eq!(result, expected_result);
    }
}
