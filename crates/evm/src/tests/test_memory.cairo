use core::dict::Felt252DictTrait;
use debug::PrintTrait;
use evm::memory::{MemoryTrait, InternalMemoryTrait, MemoryPrintTrait};
use utils::{math::Exponentiation, math::WrappingExponentiation, helpers};


mod internal {
    use evm::memory::{MemoryTrait, InternalMemoryTrait, MemoryPrintTrait};
    use utils::{math::Exponentiation, helpers};

    fn load_should_load_an_element_from_the_memory_with_offset(
        offset: usize, low: u128, high: u128
    ) {
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
        let result: u256 = memory.load_internal(offset);

        // Then
        assert(result == u256 { low: low, high: high }, 'result not matching expected');
    }
}


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
fn test_store_should_add_an_element_with_offset_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let value: u256 = 1;
    let result = memory.store(value, 1);

    // Then
    let len = memory.bytes_len;
    assert(len == 64, 'memory should be 64bytes');
}

#[test]
#[available_gas(20000000)]
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
fn test_store_n_no_aligned_words() {
    let mut memory = MemoryTrait::new();
    memory.store_n(array![1, 2].span(), 15);
    assert(memory.bytes_len == 32, 'memory should be 32 bytes');
}

#[test]
#[available_gas(200000000)]
fn test_store_n_2_aligned_words() {
    let mut memory = MemoryTrait::new();
    let bytes_arr = array![
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35
    ]
        .span();
    memory.store_n(bytes_arr, 15);
    // value [1], will be stored in first word, values [2:34] will be stored in aligned words,
    // value [35] will be stored in final word
    assert(memory.bytes_len == 64, 'memory should be 64 bytes');

    let mut stored_bytes = array![];
    memory.load_n_internal(35, ref stored_bytes, 15);
    assert(stored_bytes.span() == bytes_arr, 'stored bytes not == expected');
}

#[test]
#[available_gas(2000000000)]
fn test_load_n_internal_same_word() {
    let mut memory = MemoryTrait::new();
    memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);

    let mut results: Array<u8> = ArrayTrait::new();
    memory.load_n_internal(16, ref results, 0);

    assert(results.len() == 16, 'error');
    let mut i = 0;
    loop {
        if i == results.len() {
            break;
        }
        assert(*results[i] == 0xFF, 'byte value loaded not correct');
        i += 1;
    }
}


#[test]
#[available_gas(20000000)]
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
    let result: u256 = memory.load_internal(0);

    // Then
    assert(result == first_value, 'res not u256{2,1}');

    // When
    let result: u256 = memory.load_internal(32);

    // Then
    assert(result == second_value, 'res not u256{4,3}');

    // When
    let result: u256 = memory.load_internal(16);

    // Then
    assert(result == u256 { low: 3, high: 2 }, 'res not u256{3,2}');
}

#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_1() {
    internal::load_should_load_an_element_from_the_memory_with_offset(
        8, 2 * 256.wrapping_pow(8).try_into().unwrap(), 256.wrapping_pow(8).try_into().unwrap()
    );
}
#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_2() {
    internal::load_should_load_an_element_from_the_memory_with_offset(
        7, 2 * 256.wrapping_pow(7).try_into().unwrap(), 256.wrapping_pow(7).try_into().unwrap()
    );
}
#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_3() {
    internal::load_should_load_an_element_from_the_memory_with_offset(
        23, 3 * 256.wrapping_pow(7).try_into().unwrap(), 2 * 256.wrapping_pow(7).try_into().unwrap()
    );
}

#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_4() {
    internal::load_should_load_an_element_from_the_memory_with_offset(
        33, 4 * 256.wrapping_pow(1).try_into().unwrap(), 3 * 256.wrapping_pow(1).try_into().unwrap()
    );
}
#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_5() {
    internal::load_should_load_an_element_from_the_memory_with_offset(
        63, 0, 4 * 256.wrapping_pow(15).try_into().unwrap()
    );
}

#[test]
#[available_gas(200000000)]
fn test__load__should_load_an_element_from_the_memory_with_offset_6() {
    internal::load_should_load_an_element_from_the_memory_with_offset(500, 0, 0);
}

#[test]
#[available_gas(200000000)]
fn test__expand__should_return_the_same_memory_and_no_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);
    memory.store_n(bytes_array.span(), 0);

    // When
    let cost = memory.expand(0);

    // Then
    assert(cost == 0, 'cost should be 0');
    assert(memory.bytes_len == 32, 'memory should be 32bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
#[available_gas(2000000000)]
fn test__expand__should_return_expanded_memory_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);

    memory.store_n(bytes_array.span(), 0);

    // When
    let cost = memory.expand(1);

    // Then
    assert(cost >= 0, 'cost should be positive');
    assert(memory.bytes_len == 64, 'memory should be 64bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
#[available_gas(2000000000)]
fn test__expand__should_return_expanded_memory_by_one_word_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let cost = memory.expand(1);

    // Then
    assert(cost >= 0, 'cost should be positive');
    assert(memory.bytes_len == 32, 'memory should be 32bytes');
}

#[test]
#[available_gas(2000000000)]
fn test__expand__should_return_expanded_memory_by_exactly_one_word_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let cost = memory.expand(32);

    // Then
    assert(cost >= 0, 'cost should be positive');
    assert(memory.bytes_len == 32, 'memory should be 32bytes');
}

#[test]
#[available_gas(2000000000)]
fn test__expand__should_return_expanded_memory_by_two_words_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let cost = memory.expand(33);

    // Then
    assert(cost >= 0, 'cost should be positive');
    assert(memory.bytes_len == 64, 'memory should be 96bytes');
}

#[test]
#[available_gas(2000000000)]
fn test__ensure_length__should_return_the_same_memory_and_no_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);

    memory.store_n(bytes_array.span(), 0);

    // When
    let cost = memory.ensure_length(1);

    // Then
    assert(cost == 0, 'cost should be 0');
    assert(memory.bytes_len == 32, 'memory should be 32bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
#[available_gas(20000000000)]
fn test__ensure_length__should_return_expanded_memory_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);

    memory.store_n(bytes_array.span(), 0);

    // When
    let cost = memory.ensure_length(33);

    // Then
    assert(cost >= 0, 'cost should be positive');
    assert(memory.bytes_len == 64, 'memory should be 64bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
#[available_gas(20000000000)]
fn test__expand_and_load__should_return_expanded_memory_and_element_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);
    memory.store_n(bytes_array.span(), 0);

    // When
    let (loaded_element, cost) = memory.load(32);

    // Then
    assert(cost >= 0, 'cost should be positive');
    assert(memory.bytes_len == 64, 'memory should be 64 bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'loaded_element should be 1');

    let value = memory.load_internal(32);
    assert(value == 0, 'value should be 0');
}

