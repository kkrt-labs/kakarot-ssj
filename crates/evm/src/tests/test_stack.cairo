// Core lib imports
use array::ArrayTrait;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use dict::Felt252DictTrait;
use result::ResultTrait;

// Internal imports
use evm::stack::StackTrait;
use utils::constants;

#[test]
#[available_gas(12000)]
fn test_stack_new_should_return_empty_stack() {
    // When
    let mut stack = StackTrait::new();

    // Then
    assert(stack.len == 0, 'stack length should be 0');
}

#[test]
#[available_gas(40000)]
fn test__empty__should_return_if_stack_is_empty() {
    // Given
    let mut stack = StackTrait::new();

    // Then
    assert(stack.is_empty() == true, 'stack should be empty');

    // When
    stack.push(1).unwrap();
    // Then
    assert(stack.is_empty() == false, 'stack should not be empty');
}

#[test]
#[available_gas(35000)]
fn test__len__should_return_the_length_of_the_stack() {
    // Given
    let mut stack = StackTrait::new();

    // Then
    assert(stack.len() == 0, 'stack length should be 0');

    // When
    stack.push(1).unwrap();
    // Then
    assert(stack.len() == 1, 'stack length should be 1');
}

#[cfg(test)]
mod push {
    use super::StackTrait;
    use option::OptionTrait;
    use super::constants;
    use result::ResultTrait;
    use evm::errors::{EVMError, STACK_OVERFLOW};

    #[test]
    #[available_gas(60000)]
    fn test_should_add_an_element_to_the_stack() {
        // Given
        let mut stack = StackTrait::new();

        // When
        stack.push(1).unwrap();

        // Then
        let res = stack.peek().unwrap();

        assert(stack.is_empty() == false, 'stack should not be empty');
        assert(stack.len() == 1, 'len should be 1');
        assert(res == 1, 'wrong result');
    }

    #[test]
    #[available_gas(30000000)]
    fn test_should_fail_when_overflow() {
        // Given
        let mut stack = StackTrait::new();
        let mut i = 0;

        // When
        loop {
            if i == constants::STACK_MAX_DEPTH {
                break;
            }
            i += 1;

            stack.push(1).unwrap();
        };

        // Then
        let res = stack.push(1);
        assert(stack.len() == constants::STACK_MAX_DEPTH, 'wrong length');
        assert(res.is_err(), 'should return error');
        assert(
            res.unwrap_err() == EVMError::StackError(STACK_OVERFLOW), 'should return StackOverflow'
        );
    }
}

#[cfg(test)]
mod pop {
    use super::StackTrait;
    use array::ArrayTrait;
    use option::OptionTrait;
    use result::ResultTrait;
    use evm::errors::{EVMError, STACK_UNDERFLOW};

    #[test]
    #[available_gas(950000)]
    fn test_should_pop_an_element_from_the_stack() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();
        stack.push(2).unwrap();
        stack.push(3).unwrap();

        // When
        let last_item = stack.pop().unwrap();

        // Then
        assert(last_item == 3, 'wrong result');
        assert(stack.len == 2, 'wrong length');
    }

    #[test]
    #[available_gas(250000)]
    fn test_should_pop_N_elements_from_the_stack() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();
        stack.push(2).unwrap();
        stack.push(3).unwrap();

        // When
        let elements = stack.pop_n(3).unwrap();

        // Then
        assert(stack.len == 0, 'wrong length');
        assert(elements.len() == 3, 'wrong returned array length');
        assert(*elements[0] == 3, 'wrong result at index 0');
        assert(*elements[1] == 2, 'wrong result at index 1');
        assert(*elements[2] == 1, 'wrong result at index 2');
    }

    #[test]
    #[available_gas(55000)]
    fn test_pop_return_err_when_stack_underflow() {
        // Given
        let mut stack = StackTrait::new();

        // When & Then
        let result = stack.pop();
        assert(result.is_err(), 'should return Err ');
        assert(
            result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW),
            'should return StackUnderflow'
        );
    }

    #[test]
    #[available_gas(55000)]
    fn test_pop_n_should_return_err_when_stack_underflow() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();

        // When & Then
        let result = stack.pop_n(2);
        assert(result.is_err(), 'should return Error');
        assert(
            result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW),
            'should return StackUnderflow'
        );
    }
}

#[cfg(test)]
mod peek {
    use super::StackTrait;
    use option::OptionTrait;
    use result::ResultTrait;
    use evm::errors::{EVMError, STACK_UNDERFLOW};

    #[test]
    #[available_gas(80000)]
    fn test_should_return_last_item() {
        // Given
        let mut stack = StackTrait::new();

        // When
        stack.push(1).unwrap();
        stack.push(2).unwrap();

        // Then
        let last_item = stack.peek().unwrap();
        assert(last_item == 2, 'wrong result');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_should_return_stack_at_given_index_when_value_is_0() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();
        stack.push(2).unwrap();
        stack.push(3).unwrap();

        // When
        let result = stack.peek_at(0).unwrap();

        // Then
        assert(result == 3, 'wrong result');
    }

    #[test]
    #[available_gas(10000000)]
    fn test_should_return_stack_at_given_index_when_value_is_1() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();
        stack.push(2).unwrap();
        stack.push(3).unwrap();

        // When
        let result = stack.peek_at(1).unwrap();

        // Then
        assert(result == 2, 'wrong result');
    }

    #[test]
    #[available_gas(350000)]
    fn test_should_return_err_when_underflow() {
        // Given
        let mut stack = StackTrait::new();

        // When & Then
        let result = stack.peek_at(1);

        assert(result.is_err(), 'should return an EVMError');
        assert(
            result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW),
            'should return StackUnderflow'
        );
    }
}

#[cfg(test)]
mod swap {
    use super::StackTrait;
    use result::ResultTrait;
    use evm::errors::{EVMError, STACK_UNDERFLOW};

    #[test]
    #[available_gas(400000)]
    fn test_should_swap_2_stack_items() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();
        stack.push(2).unwrap();
        stack.push(3).unwrap();
        stack.push(4).unwrap();
        let index3 = stack.peek_at(3).unwrap();
        assert(index3 == 1, 'wrong index3');
        let index2 = stack.peek_at(2).unwrap();
        assert(index2 == 2, 'wrong index2');
        let index1 = stack.peek_at(1).unwrap();
        assert(index1 == 3, 'wrong index1');
        let index0 = stack.peek_at(0).unwrap();
        assert(index0 == 4, 'wrong index0');

        // When
        stack.swap_i(2);

        // Then
        let index3 = stack.peek_at(3).unwrap();
        assert(index3 == 1, 'post-swap: wrong index3');
        let index2 = stack.peek_at(2).unwrap();
        assert(index2 == 4, 'post-swap: wrong index2');
        let index1 = stack.peek_at(1).unwrap();
        assert(index1 == 3, 'post-swap: wrong index1');
        let index0 = stack.peek_at(0).unwrap();
        assert(index0 == 2, 'post-swap: wront index0');
    }

    #[test]
    #[available_gas(50000)]
    fn test_should_return_err_when_index_1_is_underflow() {
        // Given
        let mut stack = StackTrait::new();

        // When & Then
        let result = stack.swap_i(1);

        assert(result.is_err(), 'should return an EVMError');
        assert(
            result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW),
            'should return StackUnderflow'
        );
    }

    #[test]
    #[available_gas(600000)]
    fn test_should_return_err_when_index_2_is_underflow() {
        // Given
        let mut stack = StackTrait::new();
        stack.push(1).unwrap();

        // When & Then
        let result = stack.swap_i(2);

        assert(result.is_err(), 'should return an EVMError');
        assert(
            result.unwrap_err() == EVMError::StackError(STACK_UNDERFLOW),
            'should return StackUnderflow'
        );
    }
}
