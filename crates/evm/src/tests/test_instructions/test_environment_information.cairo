use array::{ArrayTrait};
use evm::context::{BoxDynamicExecutionContextDestruct, ExecutionContextTrait, CallContextTrait};
use evm::instructions::EnvironmentInformationTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::tests::test_utils::{setup_execution_context, evm_address, callvalue};
use evm::stack::StackTrait;
use option::OptionTrait;
use starknet::EthAddressIntoFelt252;
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

fn test_calldata_copy(dest_offset: u32, offset: u32, mut size: u32) {
    // Given
    let mut ctx = setup_execution_context();
    let call_data: Span<u8> = ctx.call_context().call_data();

    if (size == 0) {
        size = call_data.len() - offset;
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
    ctx.exec_calldatacopy();

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
        if (i + offset >= call_data.len()) {
            assert(*results[i] == 0, 'wrong data value');
        } else {
            assert(*results[i] == *call_data[i + offset], 'wrong data value');
        }

        i += 1;
    };
}
