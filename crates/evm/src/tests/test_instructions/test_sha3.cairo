use evm::context::{ExecutionContext, ExecutionContextTrait,};
use evm::errors::{EVMError, TYPE_CONVERSION_ERROR};
use evm::instructions::Sha3Trait;
use evm::instructions::sha3::internal;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_machine;

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_0_offset_0() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0x00);
    machine.stack.push(0x00);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();

    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
    assert(machine.memory.size() == 32, 'wrong memory size');
}


#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_5_offset_4() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0x05);
    machine.stack.push(0x04);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0xc41589e7559804ea4a2080dad19d876a024ccb05117835447d72ce08c1d020ec, 'wrong result'
    );
    assert(machine.memory.size() == 64, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_10_offset_10() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(10);
    machine.stack.push(10);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x6bd2dd6bd408cbee33429358bf24fdc64612fbf8b1b4db604518f40ffd34b607, 'wrong result'
    );
    assert(machine.memory.size() == 64, 'wrong memory size');
}

#[test]
#[available_gas(1000000000000000)]
fn test_exec_sha3_size_0xFFFFF_offset_1000() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0xFFFFF);
    machine.stack.push(1000);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0xbe6f1b42b34644f918560a07f959d23e532dea5338e4b9f63db0caeb608018fa, 'wrong result'
    );
    assert(machine.memory.size() == (((0xFFFFF + 1000) + 31) / 32) * 32, 'wrong memory size');
}

#[test]
#[available_gas(1000000000000000)]
fn test_exec_sha3_size_1000000_offset_2() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(1000000);
    machine.stack.push(2);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x4aa461ae9513f3b03ae397740ade979809dd02ae2c14e101b32842fbee21f0a, 'wrong result'
    );
    assert(machine.memory.size() == (((1000000 + 2) + 31) / 32) * 32, 'wrong memory size');
}

#[test]
#[available_gas(1000000000000000)]
fn test_exec_sha3_size_1000000_offset_23() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(1000000);
    machine.stack.push(2);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);
    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x4aa461ae9513f3b03ae397740ade979809dd02ae2c14e101b32842fbee21f0a, 'wrong result'
    );
    assert(machine.memory.size() == (((1000000 + 23) + 31) / 32) * 32, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_1_offset_2048() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(1);
    machine.stack.push(2048);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a, 'wrong result'
    );
    assert(machine.memory.size() == (((2048 + 1) + 31) / 32) * 32, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_0_offset_1024() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0);
    machine.stack.push(1024);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470, 'wrong result'
    );
    assert(machine.memory.size() == 1024, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_32_offset_2016() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(32);
    machine.stack.push(2016);

    machine.memory.store(0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563, 'wrong result'
    );
    assert(machine.memory.size() == (((2016 + 32) + 31) / 32) * 32, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_32_offset_0() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(32);
    machine.stack.push(0);

    machine.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x567d6b045256961aee949d6bb4d5f814c5b42e6b8bb49a833e8e89fbcddee86c, 'wrong result'
    );
    assert(machine.memory.size() == 32, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_31_offset_0() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(31);
    machine.stack.push(0);

    machine.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x4b13f212816c02cc818ba4802e81a4ac1904d2c920fe8d8cf3e4f05233a57d2e, 'wrong result'
    );
    assert(machine.memory.size() == 32, 'wrong memory size');
}

#[test]
#[available_gas(20000000)]
fn test_exec_sha3_size_33_offset_0() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(33);
    machine.stack.push(0);

    machine.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0xa6fa3edfabbe64b6ce26120b21ac9b8191005115d5e7e03fa58ec9cc74c0f2f4, 'wrong result'
    );
    assert(machine.memory.size() == 64, 'wrong memory size');
}

#[test]
#[available_gas(20000000000)]
fn test_exec_sha3_size_0x0C80_offset_0() {
    // Given
    let mut machine = setup_machine();

    machine.stack.push(0x0C80);
    machine.stack.push(0x00);

    let mut mem_dst: u32 = 0;
    loop {
        if mem_dst > 0x0C80 {
            break;
        }
        machine
            .memory
            .store(0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, mem_dst);
        mem_dst += 0x20;
    };

    // When
    machine.exec_sha3();

    // Then
    let result = machine.stack.peek().unwrap();
    assert(
        result == 0x2022ae07f3a362b08ac0a4bcb785c830cb5c368dc0ce6972249c6abbc68a5291, 'wrong result'
    );
    assert(machine.memory.size() == 0x0C80 + 32, 'wrong memory size');
}

#[test]
#[available_gas(20000000000)]
fn test_internal_fill_array_with_memory_words() {
    // Given
    let mut machine = setup_machine();
    let mut to_hash: Array<u64> = Default::default();

    machine.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);
    let mut size = 32;
    let mut offset = 0;

    // When
    let (words_from_mem, _) = internal::compute_memory_words_amount(
        size, offset, machine.memory.size()
    );
    internal::fill_array_with_memory_words(ref machine, ref to_hash, offset, words_from_mem);

    // Then
    assert(to_hash.len() == 4, 'wrong array length');
    assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
    assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
    assert((*to_hash[2]) == 0x00200400000000AD, 'wrong array value');
    assert((*to_hash[3]) == 0x0000450000DEFA00, 'wrong array value');
}

#[test]
#[available_gas(20000000000)]
fn test_internal_fill_array_with_memory_words_size_33() {
    // Given
    let mut machine = setup_machine();
    let mut to_hash: Array<u64> = Default::default();

    machine.memory.store(0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0);
    let mut size = 33;
    let mut offset = 0;

    // When
    let (words_from_mem, _) = internal::compute_memory_words_amount(
        size, offset, machine.memory.size()
    );
    internal::fill_array_with_memory_words(ref machine, ref to_hash, offset, words_from_mem);

    // Then
    assert(to_hash.len() == 4, 'wrong array length');
    assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
    assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
    assert((*to_hash[2]) == 0x00200400000000AD, 'wrong array value');
    assert((*to_hash[3]) == 0x0000450000DEFA00, 'wrong array value');
}

#[test]
#[available_gas(20000000000)]
fn test_internal_fill_array_with_last_inputs_size_5() {
    // Given
    let mut to_hash: Array<u64> = Default::default();
    let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
    let size = 5;

    // When
    let result = internal::prepare_last_input(ref to_hash, value, size);

    // Then
    assert(result == 0xE5000000FFFFFFFA, 'wrong result');
    assert(to_hash.len() == 0, 'wrong result');
}

#[test]
#[available_gas(20000000000)]
fn test_internal_fill_array_with_last_inputs_size_20() {
    // Given
    let mut to_hash: Array<u64> = Default::default();
    let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
    let size = 20;

    // When
    let result = internal::prepare_last_input(ref to_hash, value, size);

    // Then
    assert(result == 0x00200400000000AD, 'wrong result');
    assert(to_hash.len() == 2, 'wrong result');
    assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
    assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
}

#[test]
#[available_gas(20000000000)]
fn test_internal_fill_array_with_last_inputs_size_50() {
    // Given
    let mut to_hash: Array<u64> = Default::default();
    let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
    let size = 50;

    // When
    let result = internal::prepare_last_input(ref to_hash, value, size);

    // Then
    assert(result == 0x0000450000DEFA00, 'wrong result');
    assert(to_hash.len() == 3, 'wrong result');
    assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
    assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
    assert((*to_hash[2]) == 0x00200400000000AD, 'wrong array value');
}
