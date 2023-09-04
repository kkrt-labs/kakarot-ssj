use evm::instructions::MemoryOperationsTrait;
use evm::tests::test_utils::setup_execution_context;
use evm::stack::StackTrait;
use evm::memory::{MemoryTrait};
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};

// 0x51 - MLOAD

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('MLOAD not implement yet',))]
fn test_exec_mload() {
    let data: Array<(u256, u256, u256, u32)> = array![
        // (memory_value, input, expected_value, expected_memory_size)

        // Geth: no test ?!

        // Kakarot cairo0
        (0x1, 0, 0x1, 32),
        (0x1, 16, 0x100000000000000000000000000000000, 64),
        (0x1, 684, 0x0, 736),
        // evm.codes
        (0xFF, 0, 0xFF, 32),
        (0xFF, 1, 0xFF00, 64)
    ];

    let mut i = 0;
    loop {
        if (i == data.len()) {
            break;
        }

        let test_case: (u256, u256, u256, u32) = *data[i];
        let (memory_value, input, expected_value, expected_memory_size) = test_case;

        assert_mload(memory_value, input, expected_value, expected_memory_size);

        i += 1;
    }
}

fn assert_mload(memory_value: u256, input: u256, expected_value: u256, expected_memory_size: u32) {
    // Given
    let mut ctx = setup_execution_context();
    ctx.memory.store(memory_value, 0);

    ctx.stack.push(input);

    // When
    ctx.exec_mload();

    // Then
    assert(ctx.stack.len() == 1, 'stack should have one element');
    assert(ctx.stack.pop().unwrap() == expected_value, 'mload failed');
    assert(ctx.memory.bytes_len == expected_memory_size, 'memory size error');
}
