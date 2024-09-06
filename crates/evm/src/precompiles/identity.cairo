use core::starknet::EthAddress;
use evm::errors::EVMError;
use evm::model::vm::VM;
use evm::model::vm::VMTrait;
use evm::precompiles::Precompile;

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
    use core::clone::Clone;
    use core::result::ResultTrait;
    use core::starknet::testing::set_contract_address;
    use evm::instructions::system_operations::SystemOperationsTrait;

    use evm::memory::MemoryTrait;
    use evm::precompiles::identity::Identity;
    use evm::stack::StackTrait;
    use evm::test_utils::{
        VMBuilderTrait, MemoryTestUtilsTrait, native_token, other_starknet_address,
        setup_test_storages
    };
    use snforge_std::{start_mock_call, test_address};

    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    #[test]
    fn test_identity_precompile() {
        let calldata = [0x2A].span();

        let (gas, result) = Identity::exec(calldata).unwrap();

        assert_eq!(calldata, result);
        assert_eq!(gas, 18);
    }


    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    //TODO(sn-foundry): fix or delete
    #[test]
    fn test_identity_precompile_static_call() {
        setup_test_storages();
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0x3F).unwrap(); // retOffset
        vm.stack.push(0x20).unwrap(); // argsSize
        vm.stack.push(0x1F).unwrap(); // argsOffset
        vm.stack.push(0x4).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.memory.store_with_expansion(0x2A, 0x1F);

        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        vm.exec_staticcall().unwrap();

        let result = vm.memory.load(0x3F);
        assert_eq!(result, 0x2A);
    }
}
