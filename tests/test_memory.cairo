use core::dict::Felt252DictTrait;
use core::debug::PrintTrait;
use kakarot::memory::MemoryTrait;
use kakarot::memory::PrintTraitCustom;
use kakarot::utils::helpers;
use kakarot::utils;
use array::{ArrayTrait, SpanTrait};
use traits::{Into, TryInto};
use option::OptionTrait;

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

#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();
    // In the memory, the following values are stored in the order 1, 2, 3, 4 (Big Endian)
    let first_value: u256 = u256 { low: 2, high: 1 };
    let second_value = u256 { low: 4, high: 3 };
    let first_bytes_array = helpers::u256_to_bytes_array(first_value);
    let second_bytes_array = helpers::u256_to_bytes_array(second_value);

    memory.store_n(first_bytes_array.span(), 0);

    memory.store_n(second_bytes_array.span(), 32);

    // When
    let result: u256 = memory._load(0);

    // Then
    assert(result == first_value, 'res not u256{2,1}');

    // When
    let result: u256 = memory._load(32);

    // Then
    assert(result == second_value, 'res not u256{4,3}');

    // When
    let result: u256 = memory._load(16);

    // Then
    assert(result == u256 { low: 3, high: 2 }, 'res not u256{3,2}');
}
fn _load_should_load_an_element_from_the_memory_with_offset(offset: usize, low: u128, high: u128) {
    // Given
    let mut memory = MemoryTrait::new();
    // In the memory, the following values are stored in the order 1, 2, 3, 4 (Big Endian)
    let first_value: u256 = u256 { low: 2, high: 1 };
    let second_value = u256 { low: 4, high: 3 };

    let first_bytes_array = helpers::u256_to_bytes_array(first_value);
    let second_bytes_array = helpers::u256_to_bytes_array(second_value);

    memory.store_n(first_bytes_array.span(), 0);
    memory.store_n(second_bytes_array.span(), 32);

    // When
    let result: u256 = memory._load(offset);

    // Then
    assert(result == u256 { low: low, high: high }, 'result not matching expected');
}


#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_1() {
    _load_should_load_an_element_from_the_memory_with_offset(
        8, 2 * utils::pow(256, 8).try_into().unwrap(), utils::pow(256, 8).try_into().unwrap()
    );
}
#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_2() {
    _load_should_load_an_element_from_the_memory_with_offset(
        7, 2 * utils::pow(256, 7).try_into().unwrap(), utils::pow(256, 7).try_into().unwrap()
    );
}
#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_3() {
    _load_should_load_an_element_from_the_memory_with_offset(
        23, 3 * utils::pow(256, 7).try_into().unwrap(), 2 * utils::pow(256, 7).try_into().unwrap()
    );
}

#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_4() {
    _load_should_load_an_element_from_the_memory_with_offset(
        33, 4 * utils::pow(256, 1).try_into().unwrap(), 3 * utils::pow(256, 1).try_into().unwrap()
    );
}
#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_5() {
    _load_should_load_an_element_from_the_memory_with_offset(
        63, 0, 4 * utils::pow(256, 15).try_into().unwrap()
    );
}

#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_6() {
    _load_should_load_an_element_from_the_memory_with_offset(500, 0, 0);
}

#[test]
#[available_gas(200000000)]
fn test__expand__should_return_the_same_memory_and_no_cost(){
    //TODO
}