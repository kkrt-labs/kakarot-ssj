use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore};
use contracts::tests::test_data::counter_evm_bytecode;
use contracts::tests::test_utils::{
    setup_contracts_for_testing, fund_account_with_native_token, deploy_contract_account
};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR, RETURNDATA_OUT_OF_BOUNDS_ERROR};
use evm::instructions::EnvironmentInformationTrait;
use evm::machine::{Machine, MachineTrait};
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::model::contract_account::ContractAccountTrait;
use evm::model::{Account, AccountType};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use evm::tests::test_utils::{
    MachineBuilderTestTrait, evm_address, callvalue, return_from_subcontext, native_token,
    other_address, gas_price, gas_limit
};
use integer::u32_overflowing_add;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;

use starknet::testing::set_contract_address;
use utils::helpers::{u256_to_bytes_array, ArrayExtTrait};
use utils::traits::{EthAddressIntoU256};

// *************************************************************************
// 0x30: ADDRESS
// *************************************************************************

#[test]
fn test_address_basic() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    machine.exec_address().expect('exec_address failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop_eth_address().unwrap() == evm_address(), 'should be `evm_address`');
}

#[test]
#[ignore]
fn test_address_nested_call() { // A (EOA) -(calls)-> B (smart contract) -(calls)-> C (smart contract)
// TODO: Once we have ability to do nested smart contract calls, check that in `C`s context `ADDRESS` should return address `B`
// ref: https://github.com/kkrt-labs/kakarot-ssj/issues/183
}

// *************************************************************************
// 0x31: BALANCE
// *************************************************************************
#[test]
fn test_exec_balance_eoa() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let eoa = kakarot_core.deploy_eoa(evm_address());

    fund_account_with_native_token(eoa, native_token, 0x1);

    // And
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    machine.stack.push(evm_address().into()).unwrap();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_balance().expect('exec_balance failed');

    // Then
    assert(machine.stack.peek().unwrap() == native_token.balanceOf(eoa), 'wrong balance');
}

#[test]
fn test_exec_balance_zero() {
    // Given
    let (_, kakarot_core) = setup_contracts_for_testing();

    // And
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    machine.stack.push(evm_address().into()).unwrap();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_balance().expect('exec_balance failed');

    // Then
    assert(machine.stack.peek().unwrap() == 0x00, 'wrong balance');
}

#[test]
fn test_exec_balance_contract_account() {
    // Given
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let mut ca_address = deploy_contract_account(evm_address(), array![].span());

    fund_account_with_native_token(ca_address.starknet, native_token, 0x1);

    // And
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    machine.stack.push(evm_address().into()).unwrap();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_balance().expect('exec_balance failed');

    // Then
    assert(machine.stack.peek().unwrap() == 0x1, 'wrong balance');
}


// *************************************************************************
// 0x33: CALLER
// *************************************************************************
#[test]
fn test_caller() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    machine.exec_caller().expect('exec_caller failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == evm_address().into(), 'should be evm_address');
}


// *************************************************************************
// 0x32: ORIGIN
// *************************************************************************
#[test]
fn test_origin() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();

    // When
    machine.exec_origin().expect('exec_origin failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == evm_address().into(), 'should be `evm_address`');

    // And
    assert(machine.caller() == other_address(), 'should be another_evm_address');
}

#[test]
fn test_origin_nested_ctx() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    machine.exec_origin().expect('exec_origin failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == evm_address().into(), 'should be `evm_address`');
}


// *************************************************************************
// 0x34: CALLVALUE
// *************************************************************************

#[test]
fn test_exec_callvalue() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    machine.exec_callvalue().expect('exec_callvalue failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == callvalue(), 'should be `123456789');
}

// *************************************************************************
// 0x35: CALLDATALOAD
// *************************************************************************

#[test]
fn test_calldataload() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_calldata(calldata.span())
        .build();

    let offset: u32 = 0;
    machine.stack.push(offset.into()).expect('push failed');

    // When
    machine.exec_calldataload().expect('exec_calldataload failed');

    // Then
    let result: u256 = machine.stack.pop().unwrap();
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'wrong data value'
    );
}

#[test]
fn test_calldataload_with_offset() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );

    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_calldata(calldata.span())
        .build();

    let offset: u32 = 31;
    machine.stack.push(offset.into()).expect('push failed');

    // When
    machine.exec_calldataload().expect('exec_calldataload failed');

    // Then
    let result: u256 = machine.stack.pop().unwrap();

    assert(
        result == 0xFF00000000000000000000000000000000000000000000000000000000000000,
        'wrong results'
    );
}

#[test]
fn test_calldataload_with_offset_beyond_calldata() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_calldata(calldata.span())
        .build();

    let offset: u32 = calldata.len() + 1;
    machine.stack.push(offset.into()).expect('push failed');

    // When
    machine.exec_calldataload().expect('exec_calldataload failed');

    // Then
    let result: u256 = machine.stack.pop().unwrap();
    assert(result == 0, 'result should be 0');
}

#[test]
fn test_calldataload_with_function_selector() {
    // Given
    let calldata = array![0x6d, 0x4c, 0xe6, 0x3c];
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_calldata(calldata.span())
        .build();

    let offset: u32 = 0;
    machine.stack.push(offset.into()).expect('push failed');

    // When
    machine.exec_calldataload().expect('exec_calldataload failed');

    // Then
    let result: u256 = machine.stack.pop().unwrap();
    assert(
        result == 0x6d4ce63c00000000000000000000000000000000000000000000000000000000, 'wrong result'
    );
}


#[test]
fn test_calldataload_with_offset_conversion_error() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_calldata(calldata.span())
        .build();
    let offset: u256 = 5000000000;
    machine.stack.push(offset).expect('push failed');

    // When
    let result = machine.exec_calldataload();

    // Then
    assert(result.is_err(), 'should return error');
    assert(
        result.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'should return ConversionError'
    );
}

// *************************************************************************
// 0x36: CALLDATASIZE
// *************************************************************************

#[test]
fn test_calldata_size() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let calldata: Span<u8> = machine.calldata();

    // When
    machine.exec_calldatasize().expect('exec_calldatasize failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == calldata.len().into(), 'stack top is not calldatasize');
}

// *************************************************************************
// 0x37: CALLDATACOPY
// *************************************************************************

#[test]
fn test_calldatacopy_type_conversion_error() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');
    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');
    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');

    // When
    let res = machine.exec_calldatacopy();

    // Then
    assert(res.is_err(), 'should return error');
    assert(
        res.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'should return ConversionError'
    );
}

#[test]
fn test_calldatacopy_basic() {
    test_calldatacopy(32, 0, 3, array![4, 5, 6].span());
}

#[test]
fn test_calldatacopy_with_offset() {
    test_calldatacopy(32, 2, 1, array![6].span());
}

#[test]
fn test_calldatacopy_with_out_of_bound_bytes() {
    // For out of bound bytes, 0s will be copied.
    let mut expected = array![4, 5, 6];
    expected.append_n(0, 5);

    test_calldatacopy(32, 0, 8, expected.span());
}

#[test]
fn test_calldatacopy_with_out_of_bound_bytes_multiple_words() {
    // For out of bound bytes, 0s will be copied.
    let mut expected = array![4, 5, 6];
    expected.append_n(0, 31);

    test_calldatacopy(32, 0, 34, expected.span());
}

fn test_calldatacopy(dest_offset: u32, offset: u32, mut size: u32, expected: Span<u8>) {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let _calldata: Span<u8> = machine.calldata();

    machine.stack.push(size.into()).expect('push failed');
    machine.stack.push(offset.into()).expect('push failed');
    machine.stack.push(dest_offset.into()).expect('push failed');

    // Memory initialization with a value to verify that if the offset + size is out of the bound bytes, 0's have been copied.
    // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
    let mut i = 0;
    loop {
        if i == (size / 32) + 1 {
            break;
        }

        machine
            .memory
            .store(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                dest_offset + (i * 32)
            );

        let initial: u256 = machine.memory.load_internal(dest_offset + (i * 32)).into();

        assert(
            initial == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            'memory has not been initialized'
        );

        i += 1;
    };

    // When
    machine.exec_calldatacopy().expect('exec_calldatacopy failed');

    // Then
    assert(machine.stack.is_empty(), 'stack should be empty');

    let mut results: Array<u8> = ArrayTrait::new();
    machine.memory.load_n_internal(size, ref results, dest_offset);

    assert(results.span() == expected, 'wrong data value');
}

// *************************************************************************
// 0x38: CODESIZE
// *************************************************************************

#[test]
fn test_codesize() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    // When
    machine.exec_codesize().expect('exec_codesize failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == bytecode.len().into(), 'wrong codesize');
}

// *************************************************************************
// 0x39: CODECOPY
// *************************************************************************

#[test]
fn test_codecopy_type_conversion_error() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');
    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');
    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');

    // When
    let res = machine.exec_codecopy();

    // Then
    assert(res.is_err(), 'should return error');
    assert(
        res.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'should return ConversionError'
    );
}

#[test]
fn test_codecopy_basic() {
    test_codecopy(32, 0, 0);
}

#[test]
fn test_codecopy_with_offset() {
    test_codecopy(32, 2, 0);
}

#[test]
fn test_codecopy_with_out_of_bound_bytes() {
    test_codecopy(32, 0, 8);
}

#[test]
fn test_codecopy_with_out_of_bound_offset() {
    test_codecopy(0, 0xFFFFFFFE, 2);
}

fn test_codecopy(dest_offset: u32, offset: u32, mut size: u32) {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();

    let mut machine = MachineBuilderTestTrait::new_with_presets().with_bytecode(bytecode).build();

    if (size == 0) {
        size = bytecode.len() - offset;
    }

    machine.stack.push(size.into()).expect('push failed');
    machine.stack.push(offset.into()).expect('push failed');
    machine.stack.push(dest_offset.into()).expect('push failed');

    machine
        .memory
        .store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, dest_offset);
    let initial: u256 = machine.memory.load_internal(dest_offset).into();
    assert(
        initial == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'memory has not been initialized'
    );

    // When
    machine.exec_codecopy().expect('exec_codecopy failed');

    // Then
    assert(machine.stack.is_empty(), 'stack should be empty');

    let result: u256 = machine.memory.load_internal(dest_offset).into();
    let mut results: Array<u8> = u256_to_bytes_array(result);

    let mut i = 0;
    loop {
        if (i == size) {
            break;
        }

        // For out of bound bytes, 0s will be copied.
        if (i + offset >= bytecode.len()) {
            assert(*results[i] == 0, 'wrong data value');
        } else {
            assert(*results[i] == *bytecode[i + offset], 'wrong data value');
        }

        i += 1;
    };
}

// *************************************************************************
// 0x3A: GASPRICE
// *************************************************************************

#[test]
fn test_gasprice() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    // When
    machine.exec_gasprice().expect('exec_gasprice failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == gas_price().into(), 'stack top should be gas_price');
}

// *************************************************************************
// 0x3B - EXTCODESIZE
// *************************************************************************
#[test]
fn test_exec_extcodesize_eoa() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let (_, kakarot_core) = setup_contracts_for_testing();
    let _expected_eoa_starknet_address = kakarot_core.deploy_eoa(evm_address);
    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodesize().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected code size 0');
}


#[test]
fn test_exec_extcodesize_ca_empty() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // The bytecode remains empty, and we expect the empty hash in return
    let _ca_address = deploy_contract_account(evm_address(), array![].span());

    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodesize().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected code size 0');
}


#[test]
fn test_exec_extcodesize_ca_with_bytecode() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // The bytecode stored is the bytecode of a Counter.sol smart contract
    deploy_contract_account(evm_address(), counter_evm_bytecode());

    machine.stack.push(evm_address.into()).expect('push failed');
    // When
    machine.exec_extcodesize().unwrap();

    // Then
    assert(
        machine.stack.peek() // extcodesize(Counter.sol) := 275 (source: remix)
        .unwrap() == 473,
        'expected counter SC code size'
    );
}


#[test]
fn test_exec_extcodecopy_ca() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // The bytecode stored is the bytecode of a Counter.sol smart contract
    deploy_contract_account(evm_address(), counter_evm_bytecode());

    // size
    machine.stack.push(50).expect('push failed');
    // offset
    machine.stack.push(200).expect('push failed');
    // destOffset (memory offset)
    machine.stack.push(20).expect('push failed');
    machine.stack.push(evm_address.into()).unwrap();

    // When
    machine.exec_extcodecopy().unwrap();

    // Then
    let mut bytecode_slice = array![];
    machine.memory.load_n(50, ref bytecode_slice, 20);
    assert(bytecode_slice.span() == counter_evm_bytecode().slice(200, 50), 'wrong bytecode');
}

// *************************************************************************
// 0x3C - EXTCODECOPY
// *************************************************************************
#[test]
fn test_exec_extcodecopy_ca_offset_out_of_bounds() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // The bytecode stored is the bytecode of a Counter.sol smart contract
    deploy_contract_account(evm_address(), counter_evm_bytecode());

    // size
    machine.stack.push(5).expect('push failed');
    // offset
    machine.stack.push(5000).expect('push failed');
    // destOffset
    machine.stack.push(20).expect('push failed');
    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodecopy().unwrap();
    // Then
    let mut bytecode_slice = array![];
    machine.memory.load_n(5, ref bytecode_slice, 20);
    assert(bytecode_slice.span() == array![0, 0, 0, 0, 0].span(), 'wrong bytecode');
}

fn test_exec_extcodecopy_eoa() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let (_, kakarot_core) = setup_contracts_for_testing();
    kakarot_core.deploy_eoa(evm_address);

    // size
    machine.stack.push(5).expect('push failed');
    // offset
    machine.stack.push(5000).expect('push failed');
    // destOffset
    machine.stack.push(20).expect('push failed');
    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodecopy().unwrap();

    // Then
    let mut bytecode_slice = array![];
    machine.memory.load_n(5, ref bytecode_slice, 20);
    assert(bytecode_slice.span() == array![0, 0, 0, 0, 0].span(), 'wrong bytecode');
}


fn test_exec_extcodecopy_account_none() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // size
    machine.stack.push(5).expect('push failed');
    // offset
    machine.stack.push(5000).expect('push failed');
    // destOffset
    machine.stack.push(20).expect('push failed');
    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodecopy().unwrap();

    // Then
    let mut bytecode_slice = array![];
    machine.memory.load_n(5, ref bytecode_slice, 20);
    assert(bytecode_slice.span() == array![0, 0, 0, 0, 0].span(), 'wrong bytecode');
}


#[test]
fn test_returndatasize() {
    // Given
    let return_data: Array<u8> = array![1, 2, 3, 4, 5];
    let size = return_data.len();

    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();

    return_from_subcontext(ref machine, return_data.span());

    machine.exec_returndatasize().expect('exec_returndatasize failed');

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == size.into(), 'wrong returndatasize');
}

// *************************************************************************
// 0x3E: RETURNDATACOPY
// *************************************************************************

#[test]
fn test_returndata_copy_type_conversion_error() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');
    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');
    machine
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        .expect('push failed');

    // When
    let res = machine.exec_returndatacopy();

    // Then
    assert(
        res.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'should return ConversionError'
    );
}

#[test]
fn test_returndata_copy_overflowing_add_error() {
    test_returndata_copy(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
}

#[test]
fn test_returndata_copy_basic() {
    test_returndata_copy(32, 0, 0);
}

#[test]
fn test_returndata_copy_with_offset() {
    test_returndata_copy(32, 2, 0);
}

#[test]
fn test_returndata_copy_with_out_of_bound_bytes() {
    test_returndata_copy(32, 30, 10);
}

#[test]
fn test_returndata_copy_with_multiple_words() {
    test_returndata_copy(32, 0, 33);
}

fn test_returndata_copy(dest_offset: u32, offset: u32, mut size: u32) {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets()
        .with_nested_execution_context()
        .build();
    // Set the return data of the current context

    let return_data = array![
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36
    ];

    return_from_subcontext(ref machine, return_data.span());
    let return_data: Span<u8> = machine.return_data();

    if (size == 0) {
        size = return_data.len() - offset;
    }

    machine.stack.push(size.into()).expect('push failed');
    machine.stack.push(offset.into()).expect('push failed');
    machine.stack.push(dest_offset.into()).expect('push failed');

    // When
    let res = machine.exec_returndatacopy();

    // Then
    assert(machine.stack.is_empty(), 'stack should be empty');

    match u32_overflowing_add(offset, size) {
        Result::Ok(x) => {
            if (x > return_data.len()) {
                assert(
                    res.unwrap_err() == EVMError::ReturnDataError(RETURNDATA_OUT_OF_BOUNDS_ERROR),
                    'should return out of bounds'
                );
                return;
            }
        },
        Result::Err(_) => {
            assert(
                res.unwrap_err() == EVMError::ReturnDataError(RETURNDATA_OUT_OF_BOUNDS_ERROR),
                'should return out of bounds'
            );
            return;
        }
    }

    let _result: u256 = machine.memory.load_internal(dest_offset).into();
    let mut results: Array<u8> = ArrayTrait::new();

    let mut i = 0;
    loop {
        if i == (size / 32) + 1 {
            break;
        }

        let result: u256 = machine.memory.load_internal(dest_offset + (i * 32)).into();
        let result_span = u256_to_bytes_array(result).span();

        if ((i + 1) * 32 > size) {
            ArrayExtTrait::concat(ref results, result_span.slice(0, size - (i * 32)));
        } else {
            ArrayExtTrait::concat(ref results, result_span);
        }

        i += 1;
    };
    assert(results.span() == return_data.slice(offset, size), 'wrong data value');
}

// *************************************************************************
// 0x3F: EXTCODEHASH
// *************************************************************************
#[test]
fn test_exec_extcodehash_precompile() {
    // Given
    let evm_address = 0x05.try_into().unwrap();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let (_, kakarot_core) = setup_contracts_for_testing();
    kakarot_core.deploy_eoa(evm_address);
    machine.stack.push(evm_address.into()).expect('push failed');
    set_contract_address(kakarot_core.contract_address);

    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected 0');
}

#[test]
fn test_exec_extcodehash_selfdestructed() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // The bytecode remains empty, and we expect the empty hash in return
    let mut ca_address = deploy_contract_account(evm_address, array![].span());
    let account = Account {
        account_type: AccountType::ContractAccount,
        address: ca_address,
        code: array![].span(),
        nonce: 1,
        balance: 1,
        selfdestruct: false
    };
    account.selfdestruct().expect('CA selfdestruct failed');

    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(
        machine
            .stack
            .peek()
            .unwrap() == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,
        'expected empty hash'
    );
}

#[test]
fn test_exec_extcodehash_eoa() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    let (_, kakarot_core) = setup_contracts_for_testing();
    kakarot_core.deploy_eoa(evm_address);
    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(
        machine
            .stack
            .peek()
            .unwrap() == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,
        'expected empty hash'
    );
}


#[test]
fn test_exec_extcodehash_ca_empty() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();
    // The bytecode remains empty, and we expect the empty hash in return
    deploy_contract_account(evm_address(), array![].span());

    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(
        machine
            .stack
            .peek()
            .unwrap() == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,
        'expected empty hash'
    );
}

#[test]
fn test_exec_extcodehash_unknown_account() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    machine.stack.push(evm_address.into()).expect('push failed');

    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected stack top to be 0');
}

#[test]
fn test_exec_extcodehash_ca_with_bytecode() {
    // Given
    let evm_address = evm_address();
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();

    setup_contracts_for_testing();

    // The bytecode stored is the bytecode of a Counter.sol smart contract
    deploy_contract_account(evm_address(), counter_evm_bytecode());

    machine.stack.push(evm_address.into()).expect('push failed');
    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(
        machine
            .stack
            .peek()
            // extcodehash(Counter.sol) := 0x82abf19c13d2262cc530f54956af7e4ec1f45f637238ed35ed7400a3409fd275 (source: remix)
            // <https://emn178.github.io/online-tools/keccak_256.html?input=608060405234801561000f575f80fd5b506004361061004a575f3560e01c806306661abd1461004e578063371303c01461006c5780636d4ce63c14610076578063b3bcfa8214610094575b5f80fd5b61005661009e565b60405161006391906100f7565b60405180910390f35b6100746100a3565b005b61007e6100bd565b60405161008b91906100f7565b60405180910390f35b61009c6100c5565b005b5f5481565b60015f808282546100b4919061013d565b92505081905550565b5f8054905090565b60015f808282546100d69190610170565b92505081905550565b5f819050919050565b6100f1816100df565b82525050565b5f60208201905061010a5f8301846100e8565b92915050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f610147826100df565b9150610152836100df565b925082820190508082111561016a57610169610110565b5b92915050565b5f61017a826100df565b9150610185836100df565b925082820390508181111561019d5761019c610110565b5b9291505056fea26469706673582212207e792fcff28a4bf0bad8675c5bc2288b07835aebaa90b8dc5e0df19183fb72cf64736f6c63430008160033&input_type=hex>
            .unwrap() == 0xec976f44607e73ea88910411e3da156757b63bea5547b169e1e0d733443f73b0,
        'expected counter SC code hash'
    );
}

#[test]
fn test_exec_extcodehash_precompiles() {
    // Given
    let mut machine = MachineBuilderTestTrait::new_with_presets().build();
    setup_contracts_for_testing();

    let mut i = 0;
    loop {
        if i == 0x10 {
            break;
        }
        machine.stack.push(i.into()).expect('push failed');
        // When
        machine.exec_extcodehash().unwrap();

        // Then
        assert(machine.stack.pop().unwrap() == 0, 'expected 0 for precompiles');
        i += 1;
    };
}
