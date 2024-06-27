use alexandria_math::sha256::sha256;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::Precompile;
use starknet::EthAddress;

const BASE_COST: u128 = 60;
const COST_PER_WORD: u128 = 12;

impl Sha256 of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x2 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        let mut input_array = array![];
        input_array.append_span(input);
        let result = sha256(input_array);

        return Result::Ok((gas, result.span()));
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
