use array::{ArrayTrait};
use evm::instructions::EnvironmentInformationTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::tests::test_utils::{
    setup_execution_context, setup_execution_context_with_bytecode, evm_address, callvalue
};
use evm::stack::StackTrait;
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
use utils::helpers::{EthAddressIntoU256, u256_to_bytes_array};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use evm::context::{
    ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct, CallContextTrait
};

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
    assert(ctx.stack.pop().unwrap() == evm_address().into(), 'should be `evm_address`');
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
fn test_calldata_copy_type_conversion_error() {
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
fn test_calldata_copy_basic() {
    test_calldata_copy(32, 0, 0);
}

#[test]
#[available_gas(20000000)]
fn test_calldata_copy_with_offset() {
    test_calldata_copy(32, 2, 0);
}

#[test]
#[available_gas(20000000)]
fn test_calldata_copy_with_out_of_bound_bytes() {
    test_calldata_copy(32, 0, 8);
}

#[test]
#[available_gas(20000000)]
// This test will failed due to bug #275, waiting for resolution
fn test_calldata_copy_with_out_of_bound_bytes_multiple_words() {
    test_calldata_copy(32, 0, 34);
}

fn test_calldata_copy(dest_offset: u32, offset: u32, mut size: u32) {
    // Given
    let mut ctx = setup_execution_context();
    let calldata: Span<u8> = ctx.call_context().call_data();

    if (size == 0) {
        size = calldata.len() - offset;
    }

    ctx.stack.push(size.into());
    ctx.stack.push(offset.into());
    ctx.stack.push(dest_offset.into());

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

    let mut i = 0;
    loop {
        if i == (size / 32) + 1 {
            break;
        }

        let result: u256 = ctx.memory.load_internal(dest_offset + (i * 32)).into();
        let mut results: Array<u8> = u256_to_bytes_array(result);

        let mut x = 0;
        loop {
            if (x == 32 || x + (i * 32) == size) {
                break;
            }

            // For out of bound bytes, 0s will be copied.
            if (x + (i * 32) + offset >= calldata.len()) {
                assert(*results[x] == 0, 'wrong data value');
            } else {
                assert(*results[x] == *calldata[x + (i * 32) + offset], 'wrong data value');
            }

            x += 1;
        };

        i += 1;
    };
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

    // When
    ctx.exec_returndatasize();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == size.into(), 'wrong returndatasize');
}

