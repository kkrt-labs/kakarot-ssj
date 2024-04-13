use core::integer::BoundedInt;
use evm::memory::{MemoryTrait, InternalMemoryTrait};
use utils::constants::{POW_2_8, POW_2_56, POW_2_64, POW_2_120};
use utils::{math::Exponentiation, math::WrappingExponentiation, helpers, helpers::SpanExtTrait};

mod internal {
    use evm::memory::{MemoryTrait, InternalMemoryTrait};
    use utils::{math::Exponentiation, helpers};

    fn load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        offset: usize, low: u128, high: u128
    ) {
        // Given
        let mut memory = MemoryTrait::new();

        let value: u256 = u256 { low: low, high: high };

        let bytes_array = helpers::u256_to_bytes_array(value);

        memory.store_n(bytes_array.span(), offset);

        // When
        let mut elements: Array<u8> = Default::default();
        memory.load_n_internal(32, ref elements, offset);

        // Then
        assert(elements == bytes_array, 'result not matching expected');
    }

    fn load_should_load_an_element_from_the_memory_with_offset_stored_with_store(
        offset: usize, low: u128, high: u128, active_segment: usize,
    ) {
        // Given
        let mut memory = MemoryTrait::new();

        let value: u256 = u256 { low: low, high: high };

        memory.store(value, offset);

        // When
        let result: u256 = memory.load_internal(offset);

        // Then
        assert(result == value, 'result not matching expected');
    }
}


#[test]
fn test_init_should_return_an_empty_memory() {
    // When
    let mut result = MemoryTrait::new();

    // Then
    assert(result.size() == 0, 'memory not empty');
}

#[test]
fn test_len_should_return_the_length_of_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let result = memory.size();

    // Then
    assert(result == 0, 'memory not empty');
}

#[test]
fn test_store_should_add_an_element_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let value: u256 = 1;
    memory.store(value, 0);

    // Then
    let len = memory.size();
    assert(len == 32, 'memory should be 32bytes');
}

#[test]
fn test_store_should_add_an_element_with_offset_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let value: u256 = 1;
    memory.store(value, 1);

    // Then
    let len = memory.size();
    assert(len == 64, 'memory should be 64bytes');
}

#[test]
fn test_store_should_add_n_elements_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);
    memory.store_n(bytes_array.span(), 0);

    // Then
    let len = memory.size();
    assert(len == 32, 'memory should be 32bytes');
}


#[test]
fn test_store_n_no_aligned_words() {
    let mut memory = MemoryTrait::new();
    memory.store_n(array![1, 2].span(), 15);
    assert(memory.size() == 32, 'memory should be 32 bytes');
}

#[test]
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
    assert(memory.size() == 64, 'memory should be 64 bytes');

    let mut stored_bytes = Default::default();
    memory.load_n_internal(35, ref stored_bytes, 15);
    assert(stored_bytes.span() == bytes_arr, 'stored bytes not == expected');
}

#[test]
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
fn test_load_should_load_an_element_from_the_memory() {
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
fn test_load_should_load_an_element_from_the_memory_with_offset_8() {
    internal::load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        8, 2 * POW_2_64, POW_2_64
    );
}
#[test]
fn test_load_should_load_an_element_from_the_memory_with_offset_7() {
    internal::load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        7, 2 * POW_2_56, POW_2_56
    );
}
#[test]
fn test_load_should_load_an_element_from_the_memory_with_offset_23() {
    internal::load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        23, 3 * POW_2_56, 2 * POW_2_56
    );
}

#[test]
fn test_load_should_load_an_element_from_the_memory_with_offset_33() {
    internal::load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        33, 4 * POW_2_8, 3 * POW_2_8
    );
}
#[test]
fn test_load_should_load_an_element_from_the_memory_with_offset_63() {
    internal::load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        63, 0, 4 * POW_2_120
    );
}

#[test]
fn test_load_should_load_an_element_from_the_memory_with_offset_500() {
    internal::load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        500, 0, 0
    );
}


#[test]
fn test_expand__should_return_the_same_memory_and_no_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);
    memory.store_n(bytes_array.span(), 0);

    // When
    memory.expand(0);

    // Then
    assert(memory.size() == 32, 'memory should be 32bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
fn test_expand__should_return_expanded_memory_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);

    memory.store_n(bytes_array.span(), 0);

    // When
    memory.expand(1);

    // Then
    assert(memory.size() == 64, 'memory should be 64bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
fn test_expand__should_return_expanded_memory_by_one_word_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    memory.expand(1);

    // Then
    assert(memory.size() == 32, 'memory should be 32bytes');
}

#[test]
fn test_expand__should_return_expanded_memory_by_exactly_one_word_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    memory.expand(32);

    // Then
    assert(memory.size() == 32, 'memory should be 32bytes');
}

#[test]
fn test_expand__should_return_expanded_memory_by_two_words_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    memory.expand(33);

    // Then
    assert(memory.size() == 64, 'memory should be 96bytes');
}

#[test]
fn test_ensure_length__should_return_the_same_memory_and_no_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);

    memory.store_n(bytes_array.span(), 0);

    // When
    memory.ensure_length(1);

    // Then
    assert(memory.size() == 32, 'memory should be 32bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
fn test_ensure_length__should_return_expanded_memory_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);

    memory.store_n(bytes_array.span(), 0);

    // When
    memory.ensure_length(33);

    // Then
    assert(memory.size() == 64, 'memory should be 64bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'value should be 1');
}

#[test]
fn test_expand_and_load_should_return_expanded_memory_and_element_and_cost() {
    // Given
    let mut memory = MemoryTrait::new();
    let value: u256 = 1;
    let bytes_array = helpers::u256_to_bytes_array(value);
    memory.store_n(bytes_array.span(), 0);

    // When
    memory.load(32);

    // Then
    assert(memory.size() == 64, 'memory should be 64 bytes');
    let value = memory.load_internal(0);
    assert(value == 1, 'loaded_element should be 1');

    let value = memory.load_internal(32);
    assert(value == 0, 'value should be 0');
}

#[test]
fn test_store_padded_segment_should_not_change_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let bytes = array![1, 2, 3, 4, 5].span();
    memory.store_padded_segment(0, 0, bytes);

    // Then
    let len = memory.size();
    assert(len == 0, 'memory should be 0bytes');
}

#[test]
fn test_store_padded_segment_should_expand_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let bytes = Default::default().span();
    memory.store_padded_segment(10, 10, bytes);

    // Then
    let len = memory.size();
    assert(len == 32, 'memory should be length 32');
    let word = memory.load(10);
    assert(word == 0, 'word should be 0');
}

#[test]
fn test_store_padded_segment_should_add_n_elements_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    let bytes = array![1, 2, 3, 4, 5].span();
    memory.store_padded_segment(0, 5, bytes);

    // Then
    let len = memory.size();
    assert(len == 32, 'memory should be 32bytes');

    let first_word = memory.load_internal(0);
    assert(
        first_word == 0x0102030405000000000000000000000000000000000000000000000000000000,
        'Wrong memory value'
    );
}

#[test]
fn test_store_padded_segment_should_add_n_elements_padded_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // Memory initialization with a value to verify that if the size is out of the bound bytes, 0's have been copied.
    // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
    memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);

    // When
    let bytes = array![1, 2, 3, 4, 5].span();
    memory.store_padded_segment(0, 10, bytes);

    // Then
    let len = memory.size();
    assert(len == 32, 'memory should be 32bytes');

    let first_word = memory.load_internal(0);
    assert(
        first_word == 0x01020304050000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'Wrong memory value'
    );
}

#[test]
fn test_store_padded_segment_should_add_n_elements_padded_with_offset_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // Memory initialization with a value to verify that if the size is out of the bound bytes, 0's have been copied.
    // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
    memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);

    // When
    let bytes = array![1, 2, 3, 4, 5].span();
    memory.store_padded_segment(5, 10, bytes);

    // Then
    let len = memory.size();
    assert(len == 32, 'memory should be 32bytes');

    let first_word = memory.load_internal(0);
    assert(
        first_word == 0xFFFFFFFFFF01020304050000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'Wrong memory value'
    );
}

#[test]
fn test_store_padded_segment_should_add_n_elements_padded_with_offset_between_two_words_to_the_memory() {
    // Given
    let mut memory = MemoryTrait::new();

    // Memory initialization with a value to verify that if the size is out of the bound bytes, 0's have been copied.
    // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
    memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);
    memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 32);

    // When
    let bytes = array![1, 2, 3, 4, 5].span();
    memory.store_padded_segment(30, 10, bytes);

    // Then
    let len = memory.size();
    assert(len == 64, 'memory should be 64bytes');

    let first_word = memory.load_internal(0);
    assert(
        first_word == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0102,
        'Wrong memory value'
    );

    let second_word = memory.load_internal(32);
    assert(
        second_word == 0x0304050000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'Wrong memory value'
    );
}


#[test]
fn test_store_byte_should_store_byte_at_offset() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    memory.store_byte(0x01, 15);

    // Then
    assert(memory.items[0] == 0x01, 'Wrong value for word 0');
    assert(memory.items[1] == 0x00, 'Wrong value for word 1');
    assert(memory.size() == 32, 'Wrong memory length');
}
#[test]
fn test_store_byte_should_store_byte_at_offset_2() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    memory.store_byte(0xff, 14);

    // Then
    assert(memory.items[0] == 0xff00, 'Wrong value for word 0');
    assert(memory.items[1] == 0x00, 'Wrong value for word 1');
    assert(memory.size() == 32, 'Wrong memory length');
}

#[test]
fn test_store_byte_should_store_byte_at_offset_in_existing_word() {
    // Given
    let mut memory = MemoryTrait::new();
    memory.items.insert(0, 0xFFFF); // Set the first word in memory to 0xFFFF;
    memory.items.insert(1, 0xFFFF);

    // When
    memory.store_byte(0x01, 30);

    // Then
    assert(memory.items[0] == 0xFFFF, 'Wrong value for word 0');
    assert(memory.items[1] == 0x01FF, 'Wrong value for word 1');
    assert(memory.size() == 32, 'Wrong memory length');
}

#[test]
fn test_store_byte_should_store_byte_at_offset_in_new_word() {
    // Given
    let mut memory = MemoryTrait::new();

    // When
    memory.store_byte(0x01, 32);

    // Then
    assert(memory.items[0] == 0x0, 'Wrong value for word 0');
    assert(memory.items[1] == 0x0, 'Wrong value for word 1');
    assert(memory.items[2] == 0x01000000000000000000000000000000, 'Wrong value for word 2');
    assert(memory.size() == 64, 'Wrong memory length');
}

#[test]
fn test_store_byte_should_store_byte_at_offset_in_new_word_with_existing_value_in_previous_word() {
    // Given
    let mut memory = MemoryTrait::new();
    memory.items.insert(0, 0x0100);
    memory.items.insert(1, 0xffffffffffffffffffffffffffffffff);

    // When
    memory.store_byte(0xAB, 17);

    // Then
    assert(memory.items[0] == 0x0100, 'Wrong value in word 0');
    assert(memory.items[1] == 0xffABffffffffffffffffffffffffffff, 'Wrong value in word 1');
    assert(memory.size() == 32, 'Wrong memory length');
}
