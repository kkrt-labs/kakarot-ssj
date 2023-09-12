use evm::instructions::Sha3Trait;
use evm::tests::test_utils::setup_execution_context;
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::stack::StackTrait;
use option::OptionTrait;
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};

use debug::PrintTrait;

#[test]
#[available_gas(20000000)]
fn test_sha3_size_0_offset_0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x00);
    ctx.stack.push(0x00);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();

    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
}


#[test]
#[available_gas(20000000)]
fn test_sha3_size_5_offset_4() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x05);
    ctx.stack.push(0x04);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xc41589e7559804ea4a2080dad19d876a024ccb05117835447d72ce08c1d020ec, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_10_offset_10() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(10);
    ctx.stack.push(10);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x6bd2dd6bd408cbee33429358bf24fdc64612fbf8b1b4db604518f40ffd34b607, 'wrong result'
    );
}

#[test]
#[available_gas(1000000000000000)]
fn test_sha3_size_0xFFFFF_offset_1000() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0xFFFFF);
    ctx.stack.push(1000);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xbe6f1b42b34644f918560a07f959d23e532dea5338e4b9f63db0caeb608018fa, 'wrong result'
    );
}

#[test]
#[available_gas(1000000000000000)]
fn test_sha3_size_1000000_offset_2() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(1000000);
    ctx.stack.push(2);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x4aa461ae9513f3b03ae397740ade979809dd02ae2c14e101b32842fbee21f0a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_1_offset_2048() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(2048);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_0_offset_1024() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0);
    ctx.stack.push(1024);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_32_offset_2016() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(32);
    ctx.stack.push(2016);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_32_offset_0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(32);
    ctx.stack.push(0);

    ctx.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x567d6b045256961aee949d6bb4d5f814c5b42e6b8bb49a833e8e89fbcddee86c, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_31_offset_0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(31);
    ctx.stack.push(0);

    ctx.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x4b13f212816c02cc818ba4802e81a4ac1904d2c920fe8d8cf3e4f05233a57d2e, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_size_33_offset_0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(33);
    ctx.stack.push(0);

    ctx.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xa6fa3edfabbe64b6ce26120b21ac9b8191005115d5e7e03fa58ec9cc74c0f2f4, 'wrong result'
    );
}

#[test]
#[available_gas(20000000000)]
fn test_sha3_size_0x0C80_offset_0() {
    // Given
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x0C80);
    ctx.stack.push(0x00);

    let mut memDst: u32 = 0;
    loop {
        if memDst > 0x0C80 {
            break;
        }
        ctx
            .memory
            .store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, memDst);
        memDst += 0x20;
    };

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x2022ae07f3a362b08ac0a4bcb785c830cb5c368dc0ce6972249c6abbc68a5291, 'wrong result'
    );
}
