use evm::instructions::Sha3Trait;
use evm::tests::test_utils::setup_execution_context;
use evm::stack::StackTrait;
use option::OptionTrait;
use debug::PrintTrait;
use integer::BoundedInt;

use evm::context::{
    ExecutionContext, ExecutionContextTrait, CallContextTrait, BoxDynamicExecutionContextDestruct
};
use evm::memory::{InternalMemoryTrait, MemoryTrait};


#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_0_offset_0() {
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
fn test_sha3_with_size_5_offset_4() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
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
fn test_sha3_with_size_10_offset_10() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
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
fn test_sha3_with_size_0xFFFFF_offset_1000() {
    //https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code=%27sPutkrequired%20valugin%20memoryj32%200xFFFFFFFFffffz0wMSTOREwwsCallkopcodez4z0wSHA3%27~0000000zj1%20w%5Cns%2F%2F%20k%20thgjwPUSHge%20f~~%01fgjkswz~_
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
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
#[available_gas(20000000)]
fn test_sha3_with_size_1000000_offset_2() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1000000);
    ctx.stack.push(2);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_1_offset_960() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(960);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_1_offset_992() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(992);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_1_offset_1024() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(1024);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_1_offset_1984() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(1984);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_1_offset_2016() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(2016);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_1_offset_2048() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(1);
    ctx.stack.push(2048);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_0_offset_1024() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0);
    ctx.stack.push(1024);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_32_offset_2016() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(32);
    ctx.stack.push(2016);

    ctx.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    let result = ctx.stack.peek().unwrap();
    result.print();
    assert(
        result == 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_offset_plus_size_beyond_memory() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x20);
    ctx.stack.push(0x02);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x4c8266c7f1c12d2a0c99f03f5fb7314fcd4b762b34d58442fc0f23d2629b9dae
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x4c8266c7f1c12d2a0c99f03f5fb7314fcd4b762b34d58442fc0f23d2629b9dae, 'wrong result'
    );
}

#[test]
#[available_gas(20000000000)]
fn test_sha3_with_big_size() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
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
    // Resultat expected : 0x2022ae07f3a362b08ac0a4bcb785c830cb5c368dc0ce6972249c6abbc68a5291
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x2022ae07f3a362b08ac0a4bcb785c830cb5c368dc0ce6972249c6abbc68a5291, 'wrong result'
    );
}
