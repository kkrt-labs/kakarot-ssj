//! Stack implementation.
//! # Example
//! ```
//! use evm::stack::StackTrait;
//!
//! // Create a new stack instance.
//! let mut stack = StackTrait::new();
//! let val_1: u256 = 1.into();
//! let val_2: u256 = 1.into();

//! stack.push(val_1)?;
//! stack.push(val_2)?;

//! let value = stack.pop()?;
//! ```

// Core lib imports

use utils::constants;
use debug::PrintTrait;
use nullable::{nullable_from_box, NullableTrait};
use evm::errors::{EVMError, STACK_OVERFLOW, STACK_UNDERFLOW};


#[derive(Destruct, Default)]
struct Stack {
    items: Felt252Dict<Nullable<u256>>,
    len: usize,
}

trait StackTrait {
    fn new() -> Stack;
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError>;
    fn pop(ref self: Stack) -> Result<u256, EVMError>;
    fn pop_n(ref self: Stack, n: usize) -> Result<Array<u256>, EVMError>;
    fn peek(ref self: Stack) -> Option<u256>;
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError>;
    fn swap_i(ref self: Stack, index: usize) -> Result<(), EVMError>;
    fn len(self: @Stack) -> usize;
    fn is_empty(self: @Stack) -> bool;
}

impl StackImpl of StackTrait {
    #[inline(always)]
    fn new() -> Stack {
        Default::default()
    }

    /// Pushes a new bytes32 word onto the stack.
    /// If the stack is full, returns with a StackOverflow error.
    #[inline(always)]
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError> {
        // we can store at most 1024 256-bits words
        if self.len() == constants::STACK_MAX_DEPTH {
            return Result::Err(EVMError::StackError(STACK_OVERFLOW));
        }
        self.items.insert(self.len.into(), NullableTrait::new(item));
        self.len += 1;
        Result::Ok(())
    }

    /// Pops the top item off the stack. If the stack is empty,
    /// returns with a StackOverflow error.
    #[inline(always)]
    fn pop(ref self: Stack) -> Result<u256, EVMError> {
        if self.len() == 0 {
            return Result::Err(EVMError::StackError(STACK_UNDERFLOW));
        }
        let last_index = self.len() - 1;
        self.len -= 1;
        let item = self.items.get(last_index.into());
        Result::Ok(item.deref())
    }

    /// Pops N elements from the stack.
    /// If the stack length is less than than N, returns with a StackUnderflow error.
    fn pop_n(ref self: Stack, mut n: usize) -> Result<Array<u256>, EVMError> {
        if n > self.len() {
            return Result::Err(EVMError::StackError(STACK_UNDERFLOW));
        }
        let mut popped_items = ArrayTrait::<u256>::new();
        loop {
            if n == 0 {
                break ();
            }
            popped_items.append(self.pop().unwrap());
            n -= 1;
        };
        Result::Ok(popped_items)
    }

    /// Peeks at the top item on the stack.
    /// If the stack is empty, returns None.
    #[inline(always)]
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
    /// If the index is greather than the stack length, returns with a StackUnderflow error.
    #[inline(always)]
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError> {
        if index >= self.len() {
            return Result::Err(EVMError::StackError(STACK_UNDERFLOW));
        }

        let position = self.len() - 1 - index;
        let item = self.items.get(position.into());

        Result::Ok(item.deref())
    }

    /// Swaps the item at the given index with the item on top of the stack.
    /// index is 0-based, 0 being the top of the stack (unallocated).
    #[inline(always)]
    fn swap_i(ref self: Stack, index: usize) -> Result<(), EVMError> {
        if index >= self.len() {
            return Result::Err(EVMError::StackError(STACK_UNDERFLOW));
        }
        let position_0: felt252 = (self.len() - 1).into();
        let position_item: felt252 = position_0 - index.into();
        let top_item = self.items.get(position_0);
        let swapped_item = self.items.get(position_item);
        self.items.insert(position_0, swapped_item.into());
        self.items.insert(position_item, top_item.into());
        Result::Ok(())
    }

    /// Returns the length of the stack.
    #[inline(always)]
    fn len(self: @Stack) -> usize {
        *self.len
    }

    /// Returns true if the stack is empty.
    #[inline(always)]
    fn is_empty(self: @Stack) -> bool {
        *self.len == 0
    }
}
