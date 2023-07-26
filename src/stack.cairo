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
use kakarot::utils::constants;
use debug::PrintTrait;


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
    fn pop_n(ref self: Stack, n: usize) -> Array<u256>;
    fn peek(ref self: Stack) -> Option<u256>;
    fn peek_at(ref self: Stack, index: usize) -> u256;
    fn swap_i(ref self: Stack, index: usize);
    fn len(self: @Stack) -> usize;
    fn is_empty(self: @Stack) -> bool;
}

impl StackImpl of StackTrait {
    #[inline(always)]
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
        // we can store at most 1024 256-bits words
        if self.len() == constants::STACK_MAX_DEPTH {
            panic_with_felt252('Kakarot: StackOverflow')
        }
        self.insert_u256(item, self.len());
        self.len += 1;
    }

    /// Pops the top item off the stack.
    /// Returns
    /// * Option<u256> The popped item, or None if the stack is empty.
    fn pop(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            return Option::None(());
        }
        let last_index = self.len() - 1;
        self.len -= 1;
        Option::Some(self.get_u256(last_index))
    }

    /// Pops N elements from the stack.
    /// 
    /// # Arguments
    /// * `self` - the Stack instance
    /// * `n` - the number of elements to pop from the stack
    /// Returns
    /// * Array<u256> An array containing the popped items
    fn pop_n(ref self: Stack, mut n: usize) -> Array<u256> {
        if n > self.len() {
            panic_with_felt252('Kakarot: StackUnderflow');
        }
        let mut popped_items = ArrayTrait::<u256>::new();
        loop {
            if n == 0 {
                break ();
            }
            popped_items.append(self.pop().unwrap());
            n -= 1;
        };
        popped_items
    }

    /// Peeks at the top item on the stack.
    /// Returns
    /// * Option<u256> The top item, or None if the stack is empty.
    fn peek(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            Option::None(())
        } else {
            let last_index = self.len() - 1;
            Option::Some(self.get_u256(last_index))
        }
    }

    /// Peeks at the item at the given index on the stack.
    /// index is 0-based, 0 being the top of the stack.
    /// # Arguments
    /// * `self` - the Stack instance
    /// * `index` - the index of the item to peek at

    /// Returns
    /// * u256 The item at the given index, or None if the stack is empty.
    fn peek_at(ref self: Stack, index: usize) -> u256 {
        if index >= self.len() {
            panic_with_felt252('Kakarot: StackUnderflow');
        }

        let item = self.get_u256(self.len() - 1 - index);
        item
    }

    /// Swaps the item at the given index with the on on the top of the stack.
    /// index is 0-based, 0 being the top of the stack (unallocated).
    /// 
    /// # Arguments
    /// * `self` - the Stack instance
    /// * `index` - the top-based index of the item to swap with the top of the stack
    fn swap_i(ref self: Stack, index: usize) {
        if index >= self.len() {
            panic_with_felt252('Kakarot: StackUnderflow');
        }
        let position_0 = self.len() - 1;
        let position_item = position_0 - index;
        let top_item = self.get_u256(position_0);
        let swapped_item = self.get_u256(position_item);
        self.insert_u256(top_item, position_item);
        self.insert_u256(swapped_item, position_0);
    }

    /// Returns the length of the stack.
    /// Parameters
    /// * self The stack instance.
    /// Returns
    /// * usize The length of the stack.
    #[inline(always)]
    fn len(self: @Stack) -> usize {
        *self.len
    }

    /// Returns true if the stack is empty.
    /// Parameters
    /// * self The stack instance.
    /// Returns
    /// * bool True if the stack is empty, false otherwise.
    #[inline(always)]
    fn is_empty(self: @Stack) -> bool {
        *self.len == 0
    }
}

/// Trait for helping with stack operations on 256-bit unsigned integers
trait StackU256HelperTrait {
    fn dict_len(ref self: Stack) -> usize;
    fn insert_u256(ref self: Stack, item: u256, index: usize);
    fn get_u256(ref self: Stack, index: usize) -> u256;
}

/// Implementation of `StackU256HelperTrait`
impl StackU256HelperImpl of StackU256HelperTrait {
    /// Returns the length of the dictionary
    ///
    /// # Returns
    /// `felt252` - the length of the dictionary
    fn dict_len(ref self: Stack) -> usize {
        (self.len() * 2)
    }

    /// Inserts a 256-bit unsigned integer `item` into the stack at the given `index`
    ///
    /// # Arguments
    /// * `item` - the 256-bit unsigned integer to insert into the stack
    /// * `index` - the index at which to insert the item in the stack
    fn insert_u256(ref self: Stack, item: u256, index: usize) {
        let real_index: felt252 = index.into() * 2;
        self.items.insert(real_index, item.high);
        self.items.insert(real_index + 1, item.low);
    }

    /// Gets a 256-bit unsigned integer from the stack at the given `index`
    ///
    /// # Arguments
    /// * `index` - the index of the item to retrieve from the stack
    ///
    /// # Returns
    /// `u256` - the 256-bit unsigned integer retrieved from the stack
    fn get_u256(ref self: Stack, index: usize) -> u256 {
        let real_index: felt252 = index.into() * 2;
        let high = self.items.get(real_index.into());
        let low = self.items.get(real_index.into() + 1);
        let item = u256 { low: low, high: high };
        item
    }
}

