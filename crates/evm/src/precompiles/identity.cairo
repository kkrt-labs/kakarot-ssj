use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::Precompile;
use starknet::EthAddress;

const BASE_COST: u128 = 15;
const COST_PER_WORD: u128 = 3;

impl Identity of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        EthAddress { address: 0x4 }
    }

    fn exec(input: Span<u8>) -> Result<(u128, Span<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        return Result::Ok((gas, input));
    }
}

#[cfg(test)]
mod tests {
    use contracts::test_utils::{setup_contracts_for_testing};
    use core::clone::Clone;
    use core::result::ResultTrait;
    use evm::instructions::system_operations::SystemOperationsTrait;

    use evm::memory::MemoryTrait;
    use evm::precompiles::identity::Identity;
    use evm::stack::StackTrait;
    use evm::test_utils::{VMBuilderTrait, native_token, other_starknet_address};
    use starknet::testing::set_contract_address;

    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    #[test]
    fn test_identity_precompile() {
        let calldata = array![0x2A].span();

        let (gas, result) = Identity::exec(calldata).unwrap();

        assert_eq!(calldata, result);
        assert_eq!(gas, 18);
    }


    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    #[test]
    fn test_identity_precompile_static_call() {
        let (_, _) = setup_contracts_for_testing();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0x3F).unwrap(); // retOffset
        vm.stack.push(0x20).unwrap(); // argsSize
        vm.stack.push(0x1F).unwrap(); // argsOffset
        vm.stack.push(0x4).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.memory.store(0x2A, 0x1F);

        vm.exec_staticcall().unwrap();

        let result = vm.memory.load(0x3F);
        assert_eq!(result, 0x2A);
    }
}
