use core::fmt::{Debug, Formatter, Error, Display};
use core::nullable::{NullableTrait};
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
use evm::errors::{ensure, EVMError, TYPE_CONVERSION_ERROR};
use starknet::{StorageBaseAddress, EthAddress};

use utils::constants;
use utils::i256::i256;
use utils::traits::{TryIntoResult};


//TODO(optimization): make len `felt252` based to avoid un-necessary checks
#[derive(Destruct, Default)]
struct Stack {
    items: Felt252Dict<Nullable<u256>>,
    len: usize,
}

trait StackTrait {
    fn new() -> Stack;
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError>;
    fn pop(ref self: Stack) -> Result<u256, EVMError>;
    fn pop_usize(ref self: Stack) -> Result<usize, EVMError>;
    fn pop_u64(ref self: Stack) -> Result<u64, EVMError>;
    fn pop_u128(ref self: Stack) -> Result<u128, EVMError>;
    fn pop_i256(ref self: Stack) -> Result<i256, EVMError>;
    fn pop_eth_address(ref self: Stack) -> Result<EthAddress, EVMError>;
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
    ///
    /// When pushing an item to the stack, we will compute
    /// an index which corresponds to the index in the dict the item will be stored at.
    /// The internal index is computed as follows:
    ///
    /// index = len(Stack_i) + i * STACK_SEGMENT_SIZE
    ///
    /// # Errors
    ///
    /// If the stack is full, returns with a StackOverflow error.
    #[inline(always)]
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError> {
        let length = self.len();
        // we can store at most 1024 256-bits words
        ensure(length != constants::STACK_MAX_DEPTH, EVMError::StackOverflow)?;

        self.items.insert(length.into(), NullableTrait::new(item));
        self.len += 1;
        Result::Ok(())
    }

    /// Pops the top item off the stack.
    ///
    /// # Errors
    ///
    /// If the stack is empty, returns with a StackOverflow error.
    #[inline(always)]
    fn pop(ref self: Stack) -> Result<u256, EVMError> {
        ensure(self.len() != 0, EVMError::StackUnderflow)?;

        self.len -= 1;
        let item = self.items.get(self.len().into());
        Result::Ok(item.deref())
    }

    /// Calls `Stack::pop` and tries to convert it to usize
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    ///     - Type conversion failed
    #[inline(always)]
    fn pop_usize(ref self: Stack) -> Result<usize, EVMError> {
        let item: u256 = self.pop()?;
        let item: usize = item.try_into_result()?;
        Result::Ok(item)
    }

    /// Calls `Stack::pop` and tries to convert it to u64
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    ///     - Type conversion failed
    #[inline(always)]
    fn pop_u64(ref self: Stack) -> Result<u64, EVMError> {
        let item: u256 = self.pop()?;
        let item: u64 = item.try_into_result()?;
        Result::Ok(item)
    }

    /// Calls `Stack::pop` and convert it to i256
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    #[inline(always)]
    fn pop_i256(ref self: Stack) -> Result<i256, EVMError> {
        let item: u256 = self.pop()?;
        let item: i256 = item.into();
        Result::Ok(item)
    }


    /// Calls `Stack::pop` and tries to convert it to u128
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    ///     - Type conversion failed
    #[inline(always)]
    fn pop_u128(ref self: Stack) -> Result<u128, EVMError> {
        let item: u256 = self.pop()?;
        let item: u128 = item.try_into_result()?;
        Result::Ok(item)
    }

    /// Calls `Stack::pop` and converts it to usize
    ///
    /// # Errors
    ///
    /// Returns `EVMError::StackError` with appropriate message
    /// In case:
    ///     - Stack is empty
    #[inline(always)]
    fn pop_eth_address(ref self: Stack) -> Result<EthAddress, EVMError> {
        let item: u256 = self.pop()?;
        let item: EthAddress = item.into();
        Result::Ok(item)
    }

    /// Pops N elements from the stack.
    ///
    /// # Errors
    ///
    /// If the stack length is less than than N, returns with a StackUnderflow error.
    fn pop_n(ref self: Stack, mut n: usize) -> Result<Array<u256>, EVMError> {
        ensure(!(n > self.len()), EVMError::StackUnderflow)?;
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
    ///
    /// # Errors
    ///
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
    ///
    /// # Errors
    ///
    /// If the index is greater than the stack length, returns with a StackUnderflow error.
    #[inline(always)]
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError> {
        ensure(index < self.len(), EVMError::StackUnderflow)?;

        let position = self.len() - 1 - index;
        let item = self.items.get(position.into());

        Result::Ok(item.deref())
    }

    /// Swaps the item at the given index with the item on top of the stack.
    /// index is 0-based, 0 being the top of the stack (unallocated).
    #[inline(always)]
    fn swap_i(ref self: Stack, index: usize) -> Result<(), EVMError> {
        ensure(index < self.len(), EVMError::StackUnderflow)?;

        let position_0: felt252 = self.len().into() - 1;
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
        self.len() == 0
    }
}
