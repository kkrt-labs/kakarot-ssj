use contracts::kakarot_core::{interface::IExtendedKakarotCoreDispatcherImpl, KakarotCore};
use contracts::tests::test_data::counter_evm_bytecode;
use contracts::tests::utils::{
    deploy_kakarot_core, deploy_native_token, fund_account_with_native_token
};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR, RETURNDATA_OUT_OF_BOUNDS_ERROR};
use evm::instructions::EnvironmentInformationTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::model::contract_account::ContractAccountTrait;
use evm::stack::StackTrait;
use evm::tests::test_utils::{
    setup_machine, setup_machine_with_calldata, setup_machine_with_bytecode, evm_address, callvalue,
    setup_machine_with_nested_execution_context, other_evm_address, return_from_subcontext,
    native_token
};
use integer::u32_overflowing_add;
use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;

use starknet::{EthAddressIntoFelt252, contract_address_const, testing::set_contract_address};
use utils::helpers::{
    u256_to_bytes_array, load_word, ArrayExtension, ArrayExtTrait, SpanExtension, SpanExtTrait
};
use utils::traits::{EthAddressIntoU256};

// *************************************************************************
// 0x30: ADDRESS
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_address_basic() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_address();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop_eth_address().unwrap() == evm_address(), 'should be `evm_address`');
}

#[test]
#[available_gas(20000000)]
#[ignore]
fn test_address_nested_call() { // A (EOA) -(calls)-> B (smart contract) -(calls)-> C (smart contract)
// TODO: Once we have ability to do nested smart contract calls, check that in `C`s context `ADDRESS` should return address `B`
// ref: https://github.com/kkrt-labs/kakarot-ssj/issues/183
}

// *************************************************************************
// 0x31: BALANCE
// *************************************************************************
#[test]
#[available_gas(5000000)]
fn test_exec_balance_eoa() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    let eoa = kakarot_core.deploy_eoa(evm_address());

    fund_account_with_native_token(eoa, native_token);

    // And
    let mut machine = setup_machine();
    machine.stack.push(evm_address().into()).unwrap();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_balance();

    // Then
    assert(machine.stack.peek().unwrap() == native_token.balanceOf(eoa), 'wrong balance');
}

#[test]
#[available_gas(5000000)]
fn test_exec_balance_zero() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);

    // And
    let mut machine = setup_machine();
    machine.stack.push(evm_address().into()).unwrap();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_balance();

    // Then
    assert(machine.stack.peek().unwrap() == 0x00, 'wrong balance');
}

// TODO: implement balance once contracts accounts can be deployed
#[ignore]
#[test]
#[available_gas(5000000)]
fn test_exec_balance_contract_account() {
    // Given
    let native_token = deploy_native_token();
    let kakarot_core = deploy_kakarot_core(native_token.contract_address);
    // TODO: deploy contract account
    // and fund it

    // And
    let mut machine = setup_machine();
    machine.stack.push(evm_address().into()).unwrap();

    // When
    set_contract_address(kakarot_core.contract_address);
    machine.exec_balance();

    // Then
    panic_with_felt252('Not implemented yet');
}


// *************************************************************************
// 0x33: CALLER
// *************************************************************************
#[test]
#[available_gas(5000000)]
fn test_caller() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_caller();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == evm_address().into(), 'should be evm_address');
}


// *************************************************************************
// 0x32: ORIGIN
// *************************************************************************
#[test]
#[available_gas(20000000)]
fn test_origin() {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();

    // When
    machine.exec_origin();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == evm_address().into(), 'should be `evm_address`');

    // And
    assert(machine.caller() == other_evm_address(), 'should be another_evm_address');
}

#[test]
#[available_gas(20000000)]
fn test_origin_nested_ctx() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_origin();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == evm_address().into(), 'should be `evm_address`');
}


// *************************************************************************
// 0x34: CALLVALUE
// *************************************************************************

#[test]
#[available_gas(1200000)]
fn test_exec_callvalue() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_callvalue();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == callvalue(), 'should be `123456789');
}

// *************************************************************************
// 0x35: CALLDATALOAD
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_calldataload() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = setup_machine_with_calldata(calldata.span());
    let offset: u32 = 0;
    machine.stack.push(offset.into());

    // When
    machine.exec_calldataload();

    // Then
    let result: u256 = machine.stack.pop().unwrap();
    assert(
        result == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'wrong data value'
    );
}

#[test]
#[available_gas(20000000)]
fn test_calldataload_with_offset() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = setup_machine_with_calldata(calldata.span());
    let offset: u32 = 31;
    machine.stack.push(offset.into());

    // When
    machine.exec_calldataload();

    // Then
    let result: u256 = machine.stack.pop().unwrap();

    assert(
        result == 0xFF00000000000000000000000000000000000000000000000000000000000000,
        'wrong results'
    );
}

#[test]
#[available_gas(20000000)]
fn test_calldataload_with_offset_beyond_calldata() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = setup_machine_with_calldata(calldata.span());
    let offset: u32 = calldata.len() + 1;
    machine.stack.push(offset.into());

    // When
    machine.exec_calldataload();

    // Then
    let result: u256 = machine.stack.pop().unwrap();
    assert(result == 0, 'result should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_calldataload_with_offset_conversion_error() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut machine = setup_machine_with_calldata(calldata.span());
    let offset: u256 = 5000000000;
    machine.stack.push(offset);

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
#[available_gas(20000000)]
fn test_calldata_size() {
    // Given
    let mut machine = setup_machine();
    let calldata: Span<u8> = machine.calldata();

    // When
    machine.exec_calldatasize();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == calldata.len().into(), 'stack top is not calldatasize');
}

// *************************************************************************
// 0x37: CALLDATACOPY
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_calldatacopy_type_conversion_error() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

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
#[available_gas(20000000)]
fn test_calldatacopy_basic() {
    test_calldatacopy(32, 0, 3, array![4, 5, 6].span());
}

#[test]
#[available_gas(20000000)]
fn test_calldatacopy_with_offset() {
    test_calldatacopy(32, 2, 1, array![6].span());
}

#[test]
#[available_gas(20000000)]
fn test_calldatacopy_with_out_of_bound_bytes() {
    // For out of bound bytes, 0s will be copied.
    let mut expected = array![4, 5, 6];
    expected.append_n(0, 5);

    test_calldatacopy(32, 0, 8, expected.span());
}

#[test]
#[available_gas(20000000)]
fn test_calldatacopy_with_out_of_bound_bytes_multiple_words() {
    // For out of bound bytes, 0s will be copied.
    let mut expected = array![4, 5, 6];
    expected.append_n(0, 31);

    test_calldatacopy(32, 0, 34, expected.span());
}

fn test_calldatacopy(dest_offset: u32, offset: u32, mut size: u32, expected: Span<u8>) {
    // Given
    let mut machine = setup_machine();
    let calldata: Span<u8> = machine.calldata();

    machine.stack.push(size.into());
    machine.stack.push(offset.into());
    machine.stack.push(dest_offset.into());

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
    machine.exec_calldatacopy();

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
#[available_gas(20000000)]
fn test_codesize() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    // When
    machine.exec_codesize();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == bytecode.len().into(), 'wrong codesize');
}

// *************************************************************************
// 0x39: CODECOPY
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_codecopy_type_conversion_error() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

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
#[available_gas(20000000)]
fn test_codecopy_basic() {
    test_codecopy(32, 0, 0);
}

#[test]
#[available_gas(20000000)]
fn test_codecopy_with_offset() {
    test_codecopy(32, 2, 0);
}

#[test]
#[available_gas(20000000)]
fn test_codecopy_with_out_of_bound_bytes() {
    test_codecopy(32, 0, 8);
}

#[test]
#[available_gas(20000000)]
fn test_codecopy_with_out_of_bound_offset() {
    test_codecopy(0, 0xFFFFFFFE, 2);
}

fn test_codecopy(dest_offset: u32, offset: u32, mut size: u32) {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut machine = setup_machine_with_bytecode(bytecode);

    if (size == 0) {
        size = bytecode.len() - offset;
    }

    machine.stack.push(size.into());
    machine.stack.push(offset.into());
    machine.stack.push(dest_offset.into());

    machine
        .memory
        .store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, dest_offset);
    let initial: u256 = machine.memory.load_internal(dest_offset).into();
    assert(
        initial == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'memory has not been initialized'
    );

    // When
    machine.exec_codecopy();

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
#[available_gas(20000000)]
fn test_gasprice() {
    // Given
    let mut machine = setup_machine();

    // When
    machine.exec_gasprice();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.peek().unwrap() == 0xaaaaaa, 'stack top should be 0xaaaaaa');
}

// *************************************************************************
// 0x3B - EXTCODESIZE
// *************************************************************************
#[test]
#[available_gas(20000000)]
fn test_exec_extcodesize_eoa() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    let expected_eoa_starknet_address = kakarot_core.deploy_eoa(evm_address);
    machine.stack.push(evm_address.into());
    set_contract_address(kakarot_core.contract_address);

    // When
    machine.exec_extcodesize().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected code size 0');
}


#[test]
#[available_gas(20000000)]
fn test_exec_extcodesize_ca_empty() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    set_contract_address(kakarot_core.contract_address);

    // The bytecode remains empty, and we expect the empty hash in return
    let mut contract_account = ContractAccountTrait::new(evm_address);

    machine.stack.push(evm_address.into());

    // When
    machine.exec_extcodesize().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected code size 0');
}


#[test]
#[available_gas(20000000000)]
fn test_exec_extcodesize_ca_with_bytecode() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    set_contract_address(kakarot_core.contract_address);

    // Set nonce of CA to 1 so that it appears as an existing account
    // The bytecode stored is the bytecode of a Counter.sol smart contract
    let mut contract_account = ContractAccountTrait::new(evm_address);
    contract_account.increment_nonce().unwrap();
    contract_account.store_bytecode(counter_evm_bytecode());

    machine.stack.push(evm_address.into());
    // When
    machine.exec_extcodesize().unwrap();

    // Then
    assert(
        machine.stack.peek() // extcodesize(Counter.sol) := 275 (source: remix)
        .unwrap() == 275,
        'expected counter SC code size'
    );
}

#[test]
#[available_gas(2000000000)]
fn test_exec_extcodecopy_ca() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    set_contract_address(kakarot_core.contract_address);
    // Set nonce of CA to 1 so that it appears as an existing account
    // The bytecode stored is the bytecode of a Counter.sol smart contract
    let mut contract_account = ContractAccountTrait::new(evm_address);
    contract_account.increment_nonce().unwrap();
    contract_account.store_bytecode(counter_evm_bytecode());

    // size
    machine.stack.push(50).unwrap();
    // offset
    machine.stack.push(200).unwrap();
    // destOffset (memory offset)
    machine.stack.push(20).unwrap();
    machine.stack.push(evm_address.into()).unwrap();

    // When
    machine.exec_extcodecopy().unwrap();

    // Then
    let mut bytecode_slice = array![];
    machine.memory.load_n(50, ref bytecode_slice, 20);
    assert(bytecode_slice.span() == counter_evm_bytecode().slice(200, 50), 'wrong bytecode');
}

#[test]
#[available_gas(20000000)]
fn test_exec_extcodecopy_ca_offset_out_of_bounds() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    set_contract_address(kakarot_core.contract_address);

    // Set nonce of CA to 1 so that it appears as an existing account
    // The bytecode stored is the bytecode of a Counter.sol smart contract
    let mut contract_account = ContractAccountTrait::new(evm_address);
    contract_account.increment_nonce().unwrap();
    contract_account.store_bytecode(counter_evm_bytecode());

    // size
    machine.stack.push(5);
    // offset
    machine.stack.push(5000);
    // destOffset
    machine.stack.push(20);
    machine.stack.push(evm_address.into());

    set_contract_address(kakarot_core.contract_address);

    // When
    machine.exec_extcodecopy().unwrap();
    // Then
    let mut bytecode_slice = array![];
    machine.memory.load_n(5, ref bytecode_slice, 20);
    assert(bytecode_slice.span() == array![0, 0, 0, 0, 0].span(), 'wrong bytecode');
}


#[test]
#[available_gas(20000000)]
fn test_returndatasize() {
    // Given
    let return_data: Array<u8> = array![1, 2, 3, 4, 5];
    let size = return_data.len();
    let mut machine = setup_machine_with_nested_execution_context();
    return_from_subcontext(ref machine, return_data.span());

    machine.exec_returndatasize();

    // Then
    assert(machine.stack.len() == 1, 'stack should have one element');
    assert(machine.stack.pop().unwrap() == size.into(), 'wrong returndatasize');
}

// *************************************************************************
// 0x3E: RETURNDATACOPY
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_type_conversion_error() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    machine.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    // When
    let res = machine.exec_returndatacopy();

    // Then
    assert(
        res.unwrap_err() == EVMError::TypeConversionError(TYPE_CONVERSION_ERROR),
        'should return ConversionError'
    );
}

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_overflowing_add_error() {
    test_returndata_copy(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
}

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_basic() {
    test_returndata_copy(32, 0, 0);
}

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_with_offset() {
    test_returndata_copy(32, 2, 0);
}

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_with_out_of_bound_bytes() {
    test_returndata_copy(32, 30, 10);
}

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_with_multiple_words() {
    test_returndata_copy(32, 0, 33);
}

fn test_returndata_copy(dest_offset: u32, offset: u32, mut size: u32) {
    // Given
    let mut machine = setup_machine_with_nested_execution_context();
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

    machine.stack.push(size.into());
    machine.stack.push(offset.into());
    machine.stack.push(dest_offset.into());

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
        Result::Err(x) => {
            assert(
                res.unwrap_err() == EVMError::ReturnDataError(RETURNDATA_OUT_OF_BOUNDS_ERROR),
                'should return out of bounds'
            );
            return;
        }
    }

    let result: u256 = machine.memory.load_internal(dest_offset).into();
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
#[available_gas(20000000)]
fn test_exec_extcodehash_eoa() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    let expected_eoa_starknet_address = kakarot_core.deploy_eoa(evm_address);
    machine.stack.push(evm_address.into());
    set_contract_address(kakarot_core.contract_address);

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
#[available_gas(20000000)]
fn test_exec_extcodehash_ca_empty() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    set_contract_address(kakarot_core.contract_address);

    // Set nonce of CA to 1 so that it appears as an existing account
    // The bytecode remains empty, and we expect the empty hash in return
    let mut contract_account = ContractAccountTrait::new(evm_address);
    contract_account.increment_nonce().unwrap();

    machine.stack.push(evm_address.into());

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
#[available_gas(20000000)]
fn test_exec_extcodehash_ca_uninitialized() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());

    machine.stack.push(evm_address.into());
    set_contract_address(kakarot_core.contract_address);

    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(machine.stack.peek().unwrap() == 0, 'expected stack top to be 0');
}

#[test]
#[available_gas(20000000000)]
fn test_exec_extcodehash_ca_with_bytecode() {
    // Given
    let evm_address = evm_address();
    let mut machine = setup_machine();
    let kakarot_core = deploy_kakarot_core(native_token());
    set_contract_address(kakarot_core.contract_address);

    // Set nonce of CA to 1 so that it appears as an existing account
    // The bytecode stored is the bytecode of a Counter.sol smart contract
    let mut contract_account = ContractAccountTrait::new(evm_address);
    contract_account.increment_nonce().unwrap();
    contract_account.store_bytecode(counter_evm_bytecode());

    machine.stack.push(evm_address.into());
    // When
    machine.exec_extcodehash().unwrap();

    // Then
    assert(
        machine
            .stack
            .peek()
            // extcodehash(Counter.sol) := 0x82abf19c13d2262cc530f54956af7e4ec1f45f637238ed35ed7400a3409fd275 (source: remix)
            // <https://emn178.github.io/online-tools/keccak_256.html?input=6080604052348015600f57600080fd5b506004361060465760003560e01c806306661abd14604b578063371303c01460655780636d4ce63c14606d578063b3bcfa82146074575b600080fd5b605360005481565b60405190815260200160405180910390f35b606b607a565b005b6000546053565b606b6091565b6001600080828254608a919060b7565b9091555050565b6001600080828254608a919060cd565b634e487b7160e01b600052601160045260246000fd5b8082018082111560c75760c760a1565b92915050565b8181038181111560c75760c760a156fea2646970667358221220f379b9089b70e8e00da8545f9a86f648441fdf27ece9ade2c71653b12fb80c7964736f6c63430008120033&input_type=hex>
            .unwrap() == 0x82abf19c13d2262cc530f54956af7e4ec1f45f637238ed35ed7400a3409fd275,
        'expected counter SC code hash'
    );
}
