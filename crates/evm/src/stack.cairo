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
use evm::errors::{EVMError, STACK_OVERFLOW, STACK_UNDERFLOW, TYPE_CONVERSION_ERROR};
use nullable::{nullable_from_box, NullableTrait};
use starknet::{StorageBaseAddress, EthAddress};

use utils::constants;
use utils::i256::i256;
use utils::traits::{TryIntoResult};


#[derive(Destruct, Default)]
struct Stack {
    active_segment: usize,
    items: Felt252Dict<Nullable<u256>>,
    len: Felt252Dict<usize>,
}

trait StackTrait {
    fn new() -> Stack;
    fn set_active_segment(ref self: Stack, active_segment: usize);
    fn push(ref self: Stack, item: u256) -> Result<(), EVMError>;
    fn pop(ref self: Stack) -> Result<u256, EVMError>;
    fn pop_usize(ref self: Stack) -> Result<usize, EVMError>;
    fn pop_u64(ref self: Stack) -> Result<u64, EVMError>;
    fn pop_i256(ref self: Stack) -> Result<i256, EVMError>;
    fn pop_eth_address(ref self: Stack) -> Result<EthAddress, EVMError>;
    fn pop_n(ref self: Stack, n: usize) -> Result<Array<u256>, EVMError>;
    fn peek(ref self: Stack) -> Option<u256>;
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError>;
    fn swap_i(ref self: Stack, index: usize) -> Result<(), EVMError>;
    fn len(ref self: Stack) -> usize;
    fn is_empty(ref self: Stack) -> bool;
    fn active_segment(self: @Stack) -> usize;
    fn compute_active_segment_index(self: @Stack, index: usize) -> felt252;
}

impl StackImpl of StackTrait {
    #[inline(always)]
    fn new() -> Stack {
        Default::default()
    }

    /// Sets the current active segment for the `Stack` instance.
    /// Active segment are implementation-specific concepts that reflect
    /// the execution context being currently executed.
    #[inline(always)]
    fn set_active_segment(ref self: Stack, active_segment: usize) {
        self.active_segment = active_segment;
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
        if length == constants::STACK_MAX_DEPTH {
            return Result::Err(EVMError::StackError(STACK_OVERFLOW));
        }
        let index = self.compute_active_segment_index(length);
        self.items.insert(index, NullableTrait::new(item));
        self.len.insert(self.active_segment().into(), length + 1);
        Result::Ok(())
    }

    /// Pops the top item off the stack.
    ///
    /// # Errors
    ///
    /// If the stack is empty, returns with a StackOverflow error.
    #[inline(always)]
    fn pop(ref self: Stack) -> Result<u256, EVMError> {
        let length = self.len();
        if length == 0 {
            return Result::Err(EVMError::StackError(STACK_UNDERFLOW));
        }
        self.len.insert(self.active_segment().into(), length - 1);
        let internal_index = self.compute_active_segment_index(self.len());
        let item = self.items.get(internal_index);
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
    ///
    /// # Errors
    ///
    /// If the stack is empty, returns None.
    #[inline(always)]
    fn peek(ref self: Stack) -> Option<u256> {
        if self.len() == 0 {
            Option::None(())
        } else {
            let last_index = self.compute_active_segment_index(self.len() - 1);
            let item = self.items.get(last_index.into());
            Option::Some(item.deref())
        }
    }

    /// Peeks at the item at the given index on the stack.
    /// index is 0-based, 0 being the top of the stack.
    ///
    /// # Errors
    ///
    /// If the index is greather than the stack length, returns with a StackUnderflow error.
    #[inline(always)]
    fn peek_at(ref self: Stack, index: usize) -> Result<u256, EVMError> {
        if index >= self.len() {
            return Result::Err(EVMError::StackError(STACK_UNDERFLOW));
        }

        let position = self.compute_active_segment_index(self.len() - 1 - index);
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
        let position_0: felt252 = self.compute_active_segment_index(self.len() - 1);
        let position_item: felt252 = position_0 - index.into();
        let top_item = self.items.get(position_0);
        let swapped_item = self.items.get(position_item);
        self.items.insert(position_0, swapped_item.into());
        self.items.insert(position_item, top_item.into());
        Result::Ok(())
    }

    /// Returns the length of the stack.
    #[inline(always)]
    fn len(ref self: Stack) -> usize {
        self.len.get(self.active_segment.into())
    }

    /// Returns true if the stack is empty.
    #[inline(always)]
    fn is_empty(ref self: Stack) -> bool {
        self.len() == 0
    }

    /// Returns the current active segment, i.e. the current active execution context's id
    #[inline(always)]
    fn active_segment(self: @Stack) -> usize {
        *self.active_segment
    }

    /// Computes the internal index to access the Stack of the current execution context
    #[inline(always)]
    fn compute_active_segment_index(self: @Stack, index: usize) -> felt252 {
        let internal_index = index + self.active_segment() * constants::STACK_MAX_DEPTH;
        internal_index.into()
    }
}
