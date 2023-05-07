use core::dict::Felt252DictTrait;
use core::debug::PrintTrait;
use kakarot::memory::MemoryTrait;
use kakarot::utils::helpers;
use array::{ArrayTrait, SpanTrait};

#[test]
#[available_gas(2000000)]
fn test_init_should_return_an_empty_memory() {
    // When
    let result = MemoryTrait::new();

    // Then
    assert(result.bytes_len == 0, 'memory not empty');
}

#[test]
#[available_gas(2000000)]
fn test_len_should_return_the_length_of_the_memory() {
    // Given
    let memory = MemoryTrait::new();

    // When
    let result = memory.bytes_len;

    // Then
    assert(result == 0, 'memory not empty');
}

#[test]
#[available_gas(2000000)]
fn test_store_should_add_an_element_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let value: u256 = 1;
    let result = memory.store(value, 0);

    // Then
    let len = memory.bytes_len;
    assert(len == 32, 'memory should be 32bytes');
}

#[test]
#[available_gas(2000000)]
fn test_store_should_add_n_elements_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);
    let result = memory.store_n(bytes_array.span(), 0);

    // Then
    let len = memory.bytes_len;
    assert(len == 32, 'memory should be 32bytes');
}
