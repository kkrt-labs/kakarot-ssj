// Core lib imports
use array::ArrayTrait;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use dict::Felt252DictTrait;

// Internal imports
use kakarot::stack::StackTrait;
use kakarot::utils::constants;

#[test]
#[available_gas(2000000)]
fn test_stack_new_should_return_empty_stack() {
    // When
    let mut stack = StackTrait::new();

    // Then
    assert(stack.len == 0, 'stack length should be 0');
}

#[test]
#[available_gas(2000000)]
fn test__empty__should_return_if_stack_is_empty() {
    // Given
    let mut stack = StackTrait::new();

    // Then
    assert(stack.is_empty() == true, 'stack should be empty');

    // When
    stack.push(1);
    // Then
    assert(stack.is_empty() == false, 'stack should not be empty');
}

#[test]
#[available_gas(2000000)]
fn test__len__should_return_the_length_of_the_stack() {
    // Given
    let mut stack = StackTrait::new();

    // Then
    assert(stack.len() == 0, 'stack length should be 0');

    // When
    stack.len = 1;
    // Then
    assert(stack.len() == 1, 'stack length should be 1');
}

#[test]
#[available_gas(2000000)]
fn test__push__should_add_an_element_to_the_stack() {
    // Given
    let mut stack = StackTrait::new();

    // When
    stack.push(1);

    // Then
    let high = stack.items.get(0);
    let low = stack.items.get(1);
    let stack_val_1 = u256 { low: low, high: high };

    assert(stack.is_empty() == false, 'stack should not be empty');
    assert(stack.len() == 1, 'len should be 3');
    assert(stack_val_1 == 1, 'wrong result');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Kakarot: StackOverflow', ))]
fn test__push__should_fail_when_overflow() {
    // Given
    let mut stack = StackTrait::new();

    // When
    stack.len = constants::STACK_MAX_DEPTH;

    // Then
    stack.push(1);
}

#[test]
#[available_gas(2000000)]
fn test__pop__should_pop_an_element_to_the_stack() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);
    stack.push(2);
    stack.push(3);

    // When
    let last_item = stack.pop();

    // Then
    assert(last_item == 3, 'wrong result');
    assert(stack.len == 2, 'wrong length');
}


#[test]
#[available_gas(2000000)]
fn test__pop_n__should_pop_N_elements_from_the_stack() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);
    stack.push(2);
    stack.push(3);

    // When
    let elements = stack.pop_n(3);

    // Then
    assert(stack.len == 0, 'wrong length');
    assert(elements.len() == 3, 'wrong returned array length');
    assert(*elements[0] == 3, 'wrong result');
    assert(*elements[1] == 2, 'wrong result');
    assert(*elements[2] == 1, 'wrong result');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Kakarot: StackUnderflow', ))]
fn test__pop__should_fail__when_stack_underflow() {
    // Given
    let mut stack = StackTrait::new();

    // When & Then
    let result = stack.pop();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Kakarot: StackUnderflow', ))]
fn test__pop_n__should_fail__when_stack_underflow() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);

    // When & Then
    let result = stack.pop_n(2);
}


#[test]
#[available_gas(2000000)]
fn stack_peek_test() {
    // Given
    let mut stack = StackTrait::new();

    // When
    stack.push(1);
    stack.push(2);

    // Then
    let last_item = stack.peek().unwrap();
    assert(last_item == 2, 'wrong result');
}

#[test]
#[available_gas(2000000)]
fn test__peek_at__should_return_stack_at_given_index__when_value_is_0() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);
    stack.push(2);
    stack.push(3);

    // When
    let result = stack.peek_at(0);

    // Then
    assert(result == 3, 'wrong result');
}

#[test]
#[available_gas(2000000)]
fn test__peek_at__should_return_stack_at_given_index__when_value_is_1() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);
    stack.push(2);
    stack.push(3);

    // When
    let result = stack.peek_at(1);

    // Then
    assert(result == 2, 'wrong result');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Kakarot: StackUnderflow', ))]
fn test__peek_at__should_fail_when_underflow() {
    // Given
    let mut stack = StackTrait::new();

    // When & Then
    let result = stack.peek_at(1);
}

#[test]
#[available_gas(2000000)]
fn test__swap__should_swap_2_stack_items() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);
    stack.push(2);
    stack.push(3);
    stack.push(4);
    let index3 = stack.peek_at(3);
    assert(index3 == 1, 'wrong index3');
    let index2 = stack.peek_at(2);
    assert(index2 == 2, 'wrong index2');
    let index1 = stack.peek_at(1);
    assert(index1 == 3, 'wrong index1');
    let index0 = stack.peek_at(0);
    assert(index0 == 4, 'wrong index0');

    // When
    stack.swap_i(2);

    // Then
    let index3 = stack.peek_at(3);
    assert(index3 == 1, 'post-swap: wrong index3');
    let index2 = stack.peek_at(2);
    assert(index2 == 4, 'post-swap: wrong index2');
    let index1 = stack.peek_at(1);
    assert(index1 == 3, 'post-swap: wrong index1');
    let index0 = stack.peek_at(0);
    assert(index0 == 2, 'post-swap: wront index0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Kakarot: StackUnderflow', ))]
fn test__swap__should_fail__when_index_1_is_underflow() {
    // Given
    let mut stack = StackTrait::new();

    // When & Then
    let result = stack.swap_i(1);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Kakarot: StackUnderflow', ))]
fn test__swap__should_fail__when_index_2_is_underflow() {
    // Given
    let mut stack = StackTrait::new();
    stack.push(1);

    // When & Then
    let result = stack.swap_i(2);
}

#[cfg(test)]
mod stack_helper_tests {
    use super::StackTrait;
    use kakarot::stack::StackU256HelperTrait;
    use dict::Felt252DictTrait;
    use traits::Into;
    use debug::PrintTrait;

    #[test]
    fn test_dict_len() {
        let mut stack = StackTrait::new();
        stack.len = 1;
        let dict_len = stack.dict_len();
        assert(dict_len == 2, 'dict length should be 2');
    }

    #[test]
    fn test_insert_u256() {
        let mut stack = StackTrait::new();
        let expected: u256 = u256 { low: 100, high: 100 };
        stack.insert_u256(expected, 0);
        let high = stack.items.get(0);
        let low = stack.items.get(1);
        let actual = u256 { low: low, high: high };
        assert(expected == actual, 'u256 not matching expected');
    }

    #[test]
    fn test_get_u256() {
        let mut stack = StackTrait::new();
        let v1: u256 = 100;
        let v2: u256 = 101;
        stack.insert_u256(v1, 0);
        stack.insert_u256(v2, 1);
        let item = stack.get_u256(1);
        assert(v2 == item, 'u256 item should be 101');
    }
}
