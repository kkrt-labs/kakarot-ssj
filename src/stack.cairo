//! Temporary copied from Quaireaux.
//! Remove when Qaireaux dependencies can be used through Scarb.
//! Stack implementation.
//!
//! # Example
//! ```
//! use quaireaux::data_structures::stack::StackTrait;
//!
//! // Create a new stack instance.
//! let mut stack = StackTrait::new();
//! // Create an item and push it to the stack.
//! let mut item:u256 = 1.into();
//! stack.push(item);
//! Remove the item from the stack;
//! let (stack, _) = stack.pop();
//! ```

// Core lib imports
use array::ArrayTrait;
use option::OptionTrait;

const ZERO_USIZE: usize = 0_usize;

#[derive(Copy, Drop)]
struct Stack {
    elements: Array::<u256>, 
}

trait StackTrait {
    /// Creates a new Stack instance.
    fn new() -> Stack;
    /// Pushes a new value onto the stack.
    fn push(ref self: Stack, value: u256);
    /// Removes the last item from the stack and returns it, or None if the stack is empty.
    fn pop(self: Stack) -> (Stack, Option::<u256>);
    /// Returns the last item from the stack without removing it, or None if the stack is empty.
    fn peek(self: @Stack) -> Option::<u256>;
    /// Returns the number of items in the stack.
    fn len(self: @Stack) -> usize;
    /// Returns true if the stack is empty.
    fn is_empty(self: @Stack) -> bool;
}

impl StackImpl of StackTrait {
    #[inline(always)]
    /// Creates a new Stack instance.
    /// Returns
    /// * Stack The new stack instance.
    fn new() -> Stack {
        let mut elements = ArrayTrait::<u256>::new();
        Stack { elements }
    }

    /// Pushes a new value onto the stack.
    /// * `self` - The stack to push the value onto.
    /// * `value` - The value to push onto the stack.
    fn push(ref self: Stack, value: u256) {
        let Stack{mut elements } = self;
        elements.append(value);
        self = Stack { elements }
    }


    /// Removes the last item from the stack and returns it, or None if the stack is empty.
    /// * `self` - The stack to pop the item off of.
    /// Returns
    /// * Stack The stack with the item removed.
    /// * Option::<u256> The item removed or None if the stack is empty.
    fn pop(mut self: Stack) -> (Stack, Option::<u256>) {
        if self.is_empty() {
            return (self, Option::None(()));
        }
        // Deconstruct the stack struct because we consume it
        let Stack{elements: mut elements } = self;
        let stack_len = elements.len();
        let last_idx = stack_len - 1_usize;

        let sliced_elements = array_slice(@elements, begin: 0_usize, end: last_idx);

        let value = elements.at(last_idx);
        // Update the returned stack with the sliced array
        self = Stack { elements: sliced_elements };
        (self, Option::Some(*value))
    }

    /// Returns the last item from the stack without removing it, or None if the stack is empty.
    /// * `self` - The stack to peek the item off of.
    /// Returns
    /// * Option::<u256> The last item of the stack
    fn peek(self: @Stack) -> Option::<u256> {
        if self.is_empty() {
            return Option::None(());
        }
        Option::Some(*self.elements.at(self.elements.len() - 1_usize))
    }

    /// Returns the number of items in the stack.
    /// * `self` - The stack to get the length of.
    /// Returns
    /// * usize The number of items in the stack.
    fn len(self: @Stack) -> usize {
        self.elements.len()
    }

    /// Returns true if the stack is empty.
    /// * `self` - The stack to check if it is empty.
    /// Returns
    /// * bool True if the stack is empty, false otherwise.
    fn is_empty(self: @Stack) -> bool {
        self.len() == ZERO_USIZE
    }
}

impl ArrayU256Copy of Copy::<Array::<u256>>;

/// Returns the slice of an array.
/// * `arr` - The array to slice.
/// * `begin` - The index to start the slice at.
/// * `end` - The index to end the slice at (not included).
/// # Returns
/// * `Array::<u256>` - The slice of the array.
fn array_slice(src: @Array::<u256>, begin: usize, end: usize) -> Array::<u256> {
    let mut slice = ArrayTrait::<u256>::new();
    fill_array_256(ref dst: slice, :src, index: begin, count: end);
    slice
}

// Fill an array with a value.
/// * `dst` - The array to fill.
/// * `src` - The array to fill with.
/// * `index` - The index to start filling at.
/// * `count` - The number of elements to fill.
fn fill_array_256(ref dst: Array::<u256>, src: @Array::<u256>, index: u32, count: u32) {
    // Check if out of gas.
    // TODO: Remove when automatically handled by compiler.
    match try_fetch_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = ArrayTrait::new();
            data.append('OOG');
            panic(data);
        }
    }

    if count == 0_u32 {
        return ();
    }
    if index >= src.len() {
        return ();
    }
    let element = src.at(index);
    dst.append(*element);

    fill_array_256(ref dst, src, index + 1_u32, count - 1_u32)
}
