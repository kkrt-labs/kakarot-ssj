use evm::instructions::EnvironmentInformationTrait;
use evm::tests::test_utils::{setup_execution_context, evm_address, callvalue};
use evm::stack::StackTrait;
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
use evm::context::{BoxDynamicExecutionContextDestruct, ExecutionContextTrait, CallContextTrait};
use utils::helpers::{EthAddressIntoU256, u256_to_bytes_array};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};


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

#[test]
#[available_gas(20000000)]
fn test_calldata_load() {
    // Given
    let mut ctx = setup_execution_context();
    let call_data: Span<u8> = ctx.call_context().call_data();
    let call_data_len = call_data.len();

    let offset: u32 = 0;

    ctx.stack.push(offset.into());

    // When
    ctx.exec_calldataload();

    // Then
    let result: u256 = ctx.stack.pop().unwrap();
    let mut results: Array<u8> = u256_to_bytes_array(result);

    let mut i: u32 = 0;
    loop {
        if i > 31 {
            break;
        }

        if i + offset < call_data_len {
            assert(call_data[i + offset] == results[i], 'wrong byte value');
        } else {
            assert(*results[i] == 0, 'byte should be 0');
        }

        i += 1;
    }
}

#[test]
#[available_gas(20000000)]
fn test_calldata_load_with_offset() {
    // Given
    let mut ctx = setup_execution_context();
    let call_data: Span<u8> = ctx.call_context().call_data();
    let call_data_len = call_data.len();

    let offset: u32 = call_data_len - 2;

    ctx.stack.push(offset.into());

    // When
    ctx.exec_calldataload();

    // Then
    let result: u256 = ctx.stack.pop().unwrap();
    let mut results: Array<u8> = u256_to_bytes_array(result);

    let mut i: u32 = 0;
    loop {
        if i > 31 {
            break;
        }

        if i + offset < call_data_len {
            assert(call_data[i + offset] == results[i], 'wrong byte value');
        } else {
            assert(*results[i] == 0, 'byte should be 0');
        }

        i += 1;
    }
}

#[test]
#[available_gas(20000000)]
fn test_calldata_load_with_offset_beyond_calldata() {
    // Given
    let mut ctx = setup_execution_context();
    let call_data: Span<u8> = ctx.call_context().call_data();
    let call_data_len = call_data.len();

    let offset: u32 = call_data_len + 1;

    ctx.stack.push(offset.into());

    // When
    ctx.exec_calldataload();

    // Then
    let result: u256 = ctx.stack.pop().unwrap();
    assert(result == 0, 'result should be 0');
}


#[test]
#[available_gas(20000000)]
fn test_calldata_load_with_offset_conversion_error() {
    // Given
    let mut ctx = setup_execution_context();
    let call_data: Span<u8> = ctx.call_context().call_data();
    let call_data_len = call_data.len();

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
