use array::ArrayTrait;

//! Stack module
/// Stack representation.
#[derive(Drop, Copy)]
struct Stack {
    data: Array::<u256>, 
}

/// Stack trait
trait StackTrait {
    /// Create a new stack.
    fn new() -> Stack;
    /// Push a value onto the stack.
    fn push(ref self: Stack, value: u256);
    /// Pop a value from the stack.
    fn pop(ref self: Stack) -> Option::<u256>;
    /// Peek the Nth item from the stack.
    fn peek(ref self: Stack, idx: u32) -> Option::<@u256>;
    /// Return the length of the stack
    fn len(ref self: Stack) -> u32;
}

/// Stack implementation for the Stack trait.
impl StackImpl of StackTrait {
    /// Create a new stack
    /// # Returns
    /// A new stack
    fn new() -> Stack {
        let data = array_new::<u256>();
        return Stack { data: data };
    }

    /// Push a value onto the stack.
    /// # Arguments
    /// * `self` - The stack
    /// * `value` - The value to push
    fn push(ref self: Stack, value: u256) {
        // Deconstruct the stack struct so we can mutate the data
        let Stack{data: mut data } = self;
        data.append(value);
        // Reconstruct the stack struct
        self = Stack { data };
    }

    /// Pop a value from the stack.
    /// # Arguments
    /// * `self` - The stack
    /// # Returns
    /// The popped value
    fn pop(ref self: Stack) -> Option::<u256> {
        // Deconstruct the stack struct because we consume it
        let Stack{data: mut data } = self;
        let len = data.len();
        // Reconstruct the stack struct
        let value = data.pop_front();
        self = Stack { data };
        value
    }

    /// Peek the Nth item from the stack.
    /// # Arguments
    /// * `self` - The stack
    /// * `idx` - The stack index to peek
    /// # Returns
    /// The peeked value
    fn peek(ref self: Stack, idx: u32) -> Option::<@u256> {
        // Deconstruct the stack struct because we consume it
        let Stack{data: mut data } = self;
        let stack_len = data.len();
        // Index must be positive
        if idx < 0_u32 {
            self = Stack { data };
            return Option::<@u256>::None(());
        }
        // Index must be greater than the length of the stack
        if idx >= stack_len {
            self = Stack { data };
            return Option::<@u256>::None(());
        }
        // Reconstruct the stack struct because next line can panic
        self = Stack { data };
        // Compute the actual index of the underlying array
        let actual_idx = stack_len - idx - 1_u32;

        // Deconstruct the stack struct because we consume it
        let Stack{data: mut data } = self;
        let value = data.get(actual_idx);

        self = Stack { data };
        value
    }

    /// Return the length of the stack
    /// # Returns
    /// The length of the stack
    fn len(ref self: Stack) -> u32 {
        // Deconstruct the stack struct because we consume it
        let Stack{data: mut data } = self;
        let len = data.len();
        // Reconstruct the stack struct
        self = Stack { data };
        len
    }
}

impl Array2DU256Drop of Drop::<Array::<u256>>;
impl Array2DU256Copy of Copy::<Array::<u256>>;
