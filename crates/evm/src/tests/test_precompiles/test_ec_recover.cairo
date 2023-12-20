use contracts::tests::test_utils::setup_contracts_for_testing;
use core::array::ArrayTrait;
use evm::instructions::system_operations::SystemOperationsTrait;
use evm::memory::InternalMemoryTrait;
use evm::memory::MemoryTrait;

use evm::precompiles::ec_recover::EcRecoverPrecompileTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{VMBuilderTrait, native_token, other_starknet_address};
use utils::helpers::U256Trait;

// source -> https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='jFirsNplace_parameters%20in%20memoryZ456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3whash~Y~28wvX2YZ9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608wrX4YZ4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852adawsX6YqqjDo_call~32JSizeX80JOffsetX8VSize~VOffset~1waddressW4QFFFFFFFFwgasqSTATICCALLqqjPut_resulNalonKon_stackqPOPX80qMLOAD'~W1%20w%20jq%5Cnj//%20_%20thKZW32QY0qMSTOREX~0xWqPUSHV0wargsQ%200xNt%20Ke%20Jwret%01JKNQVWXYZ_jqw~_
#[test]
fn test_ec_recover_precompile() {
    let (_, _) = setup_contracts_for_testing();

    let mut vm = VMBuilderTrait::new_with_presets().build();

    let msg_hash = U256Trait::to_padded_bytes(
        0x456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3
    );
    let v = U256Trait::to_padded_bytes(28);
    let r = U256Trait::to_padded_bytes(
        0x9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608
    );
    let s = U256Trait::to_padded_bytes(
        0x4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852ada
    );

    let mut calldata = array![];
    calldata.append_span(msg_hash);
    calldata.append_span(v);
    calldata.append_span(r);
    calldata.append_span(s);

    vm.message.data = calldata.span();

    let gas_before = vm.gas_left;
    EcRecoverPrecompileTrait::exec(ref vm).unwrap();
    let gas_after = vm.gas_left;

    let result = U256Trait::from_bytes(vm.return_data).unwrap();
    assert_eq!(result, 0x7156526fbd7a3c72969b54f64e42c10fbb768c8a);
    assert_eq!(gas_before - gas_after, 3000);
}

// source -> https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='jFirsNplace_parameters%20in%20memoryZ456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3whash~Y~28wvX2YZ9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608wrX4YZ4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852adawsX6YqqjDo_call~32JSizeX80JOffsetX8VSize~VOffset~1waddressW4QFFFFFFFFwgasqSTATICCALLqqjPut_resulNalonKon_stackqPOPX80qMLOAD'~W1%20w%20jq%5Cnj//%20_%20thKZW32QY0qMSTOREX~0xWqPUSHV0wargsQ%200xNt%20Ke%20Jwret%01JKNQVWXYZ_jqw~_
#[test]
fn test_ec_precompile_static_call() {
    let (_, _) = setup_contracts_for_testing();

    let mut vm = VMBuilderTrait::new_with_presets().build();

    vm
        .memory
        .store(0x456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3, 0x0); // msg_hash
    vm.memory.store(0x1C, 0x20); // v
    vm.memory.store(0x9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608, 0x40); // r
    vm.memory.store(0x4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852ada, 0x60); // s

    vm.stack.push(0x20).unwrap(); // retSize
    vm.stack.push(0x80).unwrap(); // retOffset
    vm.stack.push(0x80).unwrap(); // argsSize
    vm.stack.push(0x0).unwrap(); // argsOffset
    vm.stack.push(0x1).unwrap(); // address
    vm.stack.push(0xFFFFFFFF).unwrap(); // gas

    vm.exec_staticcall().unwrap();

    let result = vm.memory.load(0x80);
    assert_eq!(result, 0x7156526fbd7a3c72969b54f64e42c10fbb768c8a);
}
