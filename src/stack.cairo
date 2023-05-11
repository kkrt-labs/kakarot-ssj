//! Stack implementation.
//! # Example
//! ```
//! use kakarot::stack::StackTrait;
//!
//! // Create a new stack instance.
//! let mut stack = StackTrait::new();
//! let val_1: u256 = 1.into();
//! let val_2: u256 = 1.into();

//! stack.push(val_1);
//! stack.push(val_2);

//! let value = stack.pop();
//! ```

// Core lib imports
use dict::Felt252DictTrait;
use option::OptionTrait;
use traits::Into;
use result::ResultTrait;
use array::ArrayTrait;


struct Stack {
    items: Felt252Dict<u128>,
    len: usize,
}

impl DestructStack of Destruct<Stack> {
    fn destruct(self: Stack) nopanic {
        self.items.squash();
    }
}

trait StackTrait {
    fn new() -> Stack;
    fn push(ref self: Stack, item: u256) -> ();
    fn pop(ref self: Stack) -> Option<u256>;
    fn peek(ref self: Stack) -> Option<u256>;
    fn len(self: @Stack) -> usize;
    fn is_empty(self: @Stack) -> bool;
}

impl StackImpl of StackTrait {
    //TODO report bug: using #[inline(new)] causes ap change error
    // #[inline(always)]
    /// Creates a new Stack instance.
    /// Returns
    /// * Stack The new stack instance.
    fn new() -> Stack {
        let items = Felt252DictTrait::<u128>::new();
        Stack { items, len: 0 }
    }

    /// Pushes a new item onto the stack.
    /// Parameters
    /// * self The stack instance.
    /// * item The item to push onto the stack.
    fn push(ref self: Stack, item: u256) -> () {
        self.insert_u256(item, self.dict_len());
        self.len += 1;
    }

    /// Pops the top item off the stack.
    /// Returns
    /// * Option<u256> The popped item, or None if the stack is empty.
    fn pop(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            Option::None(())
        } else {
            let last_index = self.dict_len() - 2;
            self.len -= 1;
            Option::Some(self.get_u256(last_index))
        }
    }

    /// Peeks at the top item on the stack.
    /// Returns
    /// * Option<u256> The top item, or None if the stack is empty.
    fn peek(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            Option::None(())
        } else {
            let last_index = self.dict_len() - 2;
            Option::Some(self.get_u256(last_index))
        }
    }

    /// Returns the length of the stack.
    /// Parameters
    /// * self The stack instance.
    /// Returns
    /// * usize The length of the stack.
    fn len(self: @Stack) -> usize {
        *self.len
    }

    /// Returns true if the stack is empty.
    /// Parameters
    /// * self The stack instance.
    /// Returns
    /// * bool True if the stack is empty, false otherwise.
    fn is_empty(self: @Stack) -> bool {
        *self.len == 0
    }
}

/// Trait for helping with stack operations on 256-bit unsigned integers
trait StackU256HelperTrait {
    fn dict_len(ref self: Stack) -> felt252;
    fn insert_u256(ref self: Stack, item: u256, index: felt252);
    fn get_u256(ref self: Stack, index: felt252) -> u256;
}

/// Implementation of `StackU256HelperTrait`
impl StackU256HelperImpl of StackU256HelperTrait {
    /// Returns the length of the dictionary
    ///
    /// # Returns
    /// `felt252` - the length of the dictionary
    fn dict_len(ref self: Stack) -> felt252 {
        (self.len * 2).into()
    }

    /// Inserts a 256-bit unsigned integer `item` into the stack at the given `index`
    ///
    /// # Arguments
    /// * `item` - the 256-bit unsigned integer to insert into the stack
    /// * `index` - the index at which to insert the item in the stack
    fn insert_u256(ref self: Stack, item: u256, index: felt252) {
        let dict_len: felt252 = self.dict_len();
        self.items.insert(dict_len, item.low);
        self.items.insert(dict_len + 1, item.high);
    }

    /// Gets a 256-bit unsigned integer from the stack at the given `index`
    ///
    /// # Arguments
    /// * `index` - the index of the item to retrieve from the stack
    ///
    /// # Returns
    /// `u256` - the 256-bit unsigned integer retrieved from the stack
    fn get_u256(ref self: Stack, index: felt252) -> u256 {
        let low = self.items.get(index);
        let high = self.items.get(index + 1);
        let item = u256 { low: low, high: high };
        item
    }
}

#[cfg(test)]
mod tests {
    use super::StackTrait;
    use super::StackU256HelperTrait;
    use dict::Felt252DictTrait;
    use traits::Into;

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
        let low = stack.items.get(0);
        let high = stack.items.get(1);
        let actual = u256 { low: low, high: high };
        assert(expected == actual, 'u256 item should be 1');
    }

    #[test]
    fn test_get_u256() {
        let mut stack = StackTrait::new();
        let expected: u256 = u256 { low: 100, high: 100 };
        stack.insert_u256(expected, 0);
        let item = stack.get_u256(0);
        assert(expected == item, 'u256 item should be 1');
    }
}
