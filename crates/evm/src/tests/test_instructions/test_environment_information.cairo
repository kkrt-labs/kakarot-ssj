use array::{ArrayTrait};
use evm::instructions::EnvironmentInformationTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::tests::test_utils::{
    setup_execution_context, setup_execution_context_with_bytecode,
    setup_execution_context_with_calldata, evm_address, callvalue
};
use evm::stack::StackTrait;

use starknet::EthAddressIntoFelt252;
use utils::traits::{EthAddressIntoU256};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR, RETURNDATA_OUT_OF_BOUNDS_ERROR};
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait
};
use utils::helpers::{
    u256_to_bytes_array, load_word, ArrayExtension, ArrayExtensionTrait, SpanExtension,
    SpanExtensionTrait
};
use integer::u32_overflowing_add;

// *************************************************************************
// 0x30: ADDRESS
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_address_basic() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_address();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop_eth_address().unwrap() == evm_address().into(), 'should be `evm_address`');
}

#[test]
#[available_gas(20000000)]
#[ignore]
fn test_address_nested_call() { // A (EOA) -(calls)-> B (smart contract) -(calls)-> C (smart contract)
// TODO: Once we have ability to do nested smart contract calls, check that in `C`s context `ADDRESS` should return address `B`
// ref: https://github.com/kkrt-labs/kakarot-ssj/issues/183
}

// *************************************************************************
// 0x34: CALLVALUE
// *************************************************************************

#[test]
#[available_gas(120000)]
fn test__exec_callvalue() {
    // Given
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_callvalue();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == callvalue(), 'should be `123456789');
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
    let mut ctx = setup_execution_context_with_calldata(calldata.span());
    let offset: u32 = 0;
    ctx.stack.push(offset.into());

    // When
    ctx.exec_calldataload();

    // Then
    let result: u256 = ctx.stack.pop().unwrap();
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
    let mut ctx = setup_execution_context_with_calldata(calldata.span());
    let offset: u32 = 31;
    ctx.stack.push(offset.into());

    // When
    ctx.exec_calldataload();

    // Then
    let result: u256 = ctx.stack.pop().unwrap();

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
    let mut ctx = setup_execution_context_with_calldata(calldata.span());
    let offset: u32 = calldata.len() + 1;
    ctx.stack.push(offset.into());

    // When
    ctx.exec_calldataload();

    // Then
    let result: u256 = ctx.stack.pop().unwrap();
    assert(result == 0, 'result should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_calldataload_with_offset_conversion_error() {
    // Given
    let calldata = u256_to_bytes_array(
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
    let mut ctx = setup_execution_context_with_calldata(calldata.span());
    let offset: u256 = 5000000000;
    ctx.stack.push(offset);

    // When
    let result = ctx.exec_calldataload();

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
    let mut ctx = setup_execution_context();
    let calldata: Span<u8> = ctx.call_context().calldata();

    // When
    ctx.exec_calldatasize();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == calldata.len().into(), 'stack top is not calldatasize');
}

// *************************************************************************
// 0x37: CALLDATACOPY
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_calldatacopy_type_conversion_error() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    // When
    let res = ctx.exec_calldatacopy();

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
    test_calldatacopy(32, 0, 8, array![4, 5, 6].span().pad_right(5));
}

#[test]
#[available_gas(20000000)]
fn test_calldatacopy_with_out_of_bound_bytes_multiple_words() {
    // For out of bound bytes, 0s will be copied.
    test_calldatacopy(32, 0, 34, array![4, 5, 6].span().pad_right(31));
}

fn test_calldatacopy(dest_offset: u32, offset: u32, mut size: u32, expected: Span<u8>) {
    // Given
    let mut ctx = setup_execution_context();
    let calldata: Span<u8> = ctx.call_context().calldata();

    ctx.stack.push(size.into());
    ctx.stack.push(offset.into());
    ctx.stack.push(dest_offset.into());

    // Memory initialization with a value to verify that if the offset + size is out of the bound bytes, 0's have been copied.
    // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
    let mut i = 0;
    loop {
        if i == (size / 32) + 1 {
            break;
        }

        ctx
            .memory
            .store(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                dest_offset + (i * 32)
            );

        let initial: u256 = ctx.memory.load_internal(dest_offset + (i * 32)).into();

        assert(
            initial == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            'memory has not been initialized'
        );

        i += 1;
    };

    // When
    ctx.exec_calldatacopy();

    // Then
    assert(ctx.stack.is_empty(), 'stack should be empty');

    let mut results: Array<u8> = ArrayTrait::new();
    ctx.memory.load_n_internal(size, ref results, dest_offset);

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
    let mut ctx = setup_execution_context_with_bytecode(bytecode);

    // When
    ctx.exec_codesize();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == bytecode.len().into(), 'wrong codesize');
}

// *************************************************************************
// 0x39: CODECOPY
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_codecopy_type_conversion_error() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context_with_bytecode(bytecode);

    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    // When
    let res = ctx.exec_codecopy();

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
    let mut ctx = setup_execution_context_with_bytecode(bytecode);

    if (size == 0) {
        size = bytecode.len() - offset;
    }

    ctx.stack.push(size.into());
    ctx.stack.push(offset.into());
    ctx.stack.push(dest_offset.into());

    ctx
        .memory
        .store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, dest_offset);
    let initial: u256 = ctx.memory.load_internal(dest_offset).into();
    assert(
        initial == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'memory has not been initialized'
    );

    // When
    ctx.exec_codecopy();

    // Then
    assert(ctx.stack.is_empty(), 'stack should be empty');

    let result: u256 = ctx.memory.load_internal(dest_offset).into();
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
    let mut ctx = setup_execution_context();

    // When
    ctx.exec_gasprice();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.peek().unwrap() == 10, 'stack top should be 10');
}

// *************************************************************************
// 0x3D: RETURNDATASIZE
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_returndatasize() {
    // Given
    let return_data: Array<u8> = array![1, 2, 3, 4, 5];
    let size = return_data.len();
    let mut ctx = setup_execution_context();
    ctx.set_return_data(return_data);

    ctx.exec_returndatasize();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == size.into(), 'wrong returndatasize');
}

// *************************************************************************
// 0x3E: RETURNDATACOPY
// *************************************************************************

#[test]
#[available_gas(20000000)]
fn test_returndata_copy_type_conversion_error() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    ctx.stack.push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    // When
    let res = ctx.exec_returndatacopy();

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
    let mut ctx = setup_execution_context();
    ctx
        .set_return_data(
            array![
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
            ]
        );

    let return_data: Span<u8> = ctx.return_data();

    if (size == 0) {
        size = return_data.len() - offset;
    }

    ctx.stack.push(size.into());
    ctx.stack.push(offset.into());
    ctx.stack.push(dest_offset.into());

    // When
    let res = ctx.exec_returndatacopy();

    // Then
    assert(ctx.stack.is_empty(), 'stack should be empty');

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

    let result: u256 = ctx.memory.load_internal(dest_offset).into();
    let mut results: Array<u8> = ArrayTrait::new();

    let mut i = 0;
    loop {
        if i == (size / 32) + 1 {
            break;
        }

        let result: u256 = ctx.memory.load_internal(dest_offset + (i * 32)).into();
        let result_span = u256_to_bytes_array(result).span();

        if ((i + 1) * 32 > size) {
            ArrayExtensionTrait::concat(ref results, result_span.slice(0, size - (i * 32)));
        } else {
            ArrayExtensionTrait::concat(ref results, result_span);
        }

        i += 1;
    };
    assert(results.span() == return_data.slice(offset, size), 'wrong data value');
}
