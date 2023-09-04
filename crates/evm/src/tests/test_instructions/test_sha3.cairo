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
fn test_sha3_with_size_32() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x20);
    ctx.stack.push(0x00);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x1b00e6bf2213698a78d172620d2852921faf54cf9645342bdb34ca455f69d44
    let result = ctx.stack.peek().unwrap();

    result.print();
    assert(
        result == 0x1b00e6bf2213698a78d172620d2852921faf54cf9645342bdb34ca455f69d44, 'wrong result'
    );
}


#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_different_than_32() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x04);
    ctx.stack.push(0x00);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x388880d56bbbf972c2ce97caeabfaf73cf1665aea364a2b06441a925d47db63e
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x388880d56bbbf972c2ce97caeabfaf73cf1665aea364a2b06441a925d47db63e, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_32_and_offset() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x20);
    ctx.stack.push(0x02);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 4c8266c7f1c12d2a0c99f03f5fb7314fcd4b762b34d58442fc0f23d2629b9dae
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x4c8266c7f1c12d2a0c99f03f5fb7314fcd4b762b34d58442fc0f23d2629b9dae, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_different_than_32_and_offset() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x02);
    ctx.stack.push(0x02);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xc142f597160775368dce2d1d8d9d847ee26f05edd4b6f00ef2451c3cab95e1a0
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xc142f597160775368dce2d1d8d9d847ee26f05edd4b6f00ef2451c3cab95e1a0, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_0() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x00);
    ctx.stack.push(0x00);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_0_and_offset() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x00);
    ctx.stack.push(0x02);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_offset_beyond_memory() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x20);
    ctx.stack.push(0x21);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563
    let result = ctx.stack.peek().unwrap();
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
#[available_gas(20000000)]
fn test_sha3_with_size_128() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x80);
    ctx.stack.push(0x00);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x20);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x40);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x60);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x425c8158d6661daea881641c267cb0bf9e551e12af9c1fa7737ef3b219ab0eed
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x425c8158d6661daea881641c267cb0bf9e551e12af9c1fa7737ef3b219ab0eed, 'wrong result'
    );
}

#[test]
#[available_gas(20000000)]
fn test_sha3_with_size_133() {
    // Given
    let bytecode: Span<u8> = array![1, 2, 3, 4, 5].span();
    let mut ctx = setup_execution_context();

    ctx.stack.push(0x85);
    ctx.stack.push(0x00);

    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x20);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x40);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x60);
    ctx.memory.store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, 0x80);

    // When
    ctx.exec_sha3();

    // Then
    // Resultat expected : 0x73cfd6eb245c512d8247245573437a38db4e265a6945f119df30cc9ed2bac584
    let result = ctx.stack.peek().unwrap();
    assert(
        result == 0x73cfd6eb245c512d8247245573437a38db4e265a6945f119df30cc9ed2bac584, 'wrong result'
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
