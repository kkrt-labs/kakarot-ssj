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
use array::ArrayTrait;
use traits::Into;
use result::ResultTrait;
use kakarot::utils::constants;
use debug::PrintTrait;
use box::BoxTrait;
use nullable::{nullable_from_box, NullableTrait};
use kakarot::errors;


// TODO remove this trait once merged in corelib
trait NullableTraitExt<T> {
    fn new(value: T) -> Nullable<T>;
}

impl NullableTraitExtImpl of NullableTraitExt<u256> {
    fn new(value: u256) -> Nullable<u256> {
        let nullable = nullable_from_box(BoxTrait::new(value));
        nullable
    }
}

#[derive(Destruct)]
struct Stack {
    items: Felt252Dict<Nullable<u256>>,
    len: usize,
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
        let items: Felt252Dict<Nullable<u256>> = Default::default();
        Stack { items, len: 0 }
    }

    /// Pushes a new item onto the stack. If this operation would overflow the stack, 
    /// panics with a StackOverflow error.
    /// Parameters
    /// * self The stack instance.
    /// * item The item to push onto the stack.
    fn push(ref self: Stack, item: u256) -> () {
        // we can store at most 1024 256-bits words
        if self.len() == constants::STACK_MAX_DEPTH {
            panic_with_felt252(errors::STACK_OVERFLOW)
        }
        self.items.insert(self.len.into(), NullableTraitExt::new(item));
        self.len += 1;
    }

    /// Pops the top item off the stack. If the stack is empty,
    /// leaves the stack unchanged.
    /// Returns
    /// * Option<u256> The popped item, or None if the stack is empty.
    fn pop(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            return Option::None(());
        }
        let last_index = self.len() - 1;
        self.len -= 1;
        let item = self.items.get(last_index.into());
        Option::Some(item.deref())
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
            panic_with_felt252(errors::STACK_UNDERFLOW);
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
            let item = self.items.get(last_index.into());
            Option::Some(item.deref())
        }
    }

    /// Peeks at the item at the given index on the stack.
    /// index is 0-based, 0 being the top of the stack.
    /// If the index is too large, panics with a StackUnderflow error.
    /// # Arguments
    /// * `self` - the Stack instance
    /// * `index` - the index of the item to peek at
    ///
    /// Returns
    /// * u256 The item at the given index, or None if the stack is empty.
    fn peek_at(ref self: Stack, index: usize) -> u256 {
        if index >= self.len() {
            panic_with_felt252(errors::STACK_UNDERFLOW);
        }

        let position = self.len() - 1 - index;
        let item = self.items.get(position.into());

        item.deref()
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
        let position_0: felt252 = (self.len() - 1).into();
        let position_item: felt252 = position_0 - index.into();
        let top_item = self.items.get(position_0);
        let swapped_item = self.items.get(position_item);
        self.items.insert(position_0, swapped_item.into());
        self.items.insert(position_item, top_item.into());
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
