use evm::errors::EVMError;
use evm::memory::{Memory, MemoryTrait};
use evm::model::{State};
use evm::model::Address;
use evm::model::Event;
use evm::stack::{Stack, StackTrait};
use starknet::get_caller_address;
use starknet::{EthAddress, ContractAddress};
use utils::helpers::{ArrayExtension, ArrayExtTrait};
use utils::traits::{SpanDefault, EthAddressDefault, ContractAddressDefault};
use evm::model::ExecutionSummary;

#[derive(Drop, Default, Copy, PartialEq)]
enum Status {
    #[default]
    Active,
    Stopped,
    Reverted
}

// *************************************************************************
//                              CallContext
// *************************************************************************
// We should not directly access the fields of the call context;
// instead we should use the methods defined in the trait.
// This is not enforced until there are `pub` and `priv` visibility on struct fields.

/// The call context.
#[derive(Drop, Copy, Default)]
struct CallContext {
    caller: Address,
    // The address of the contract that initiated the transaction or call.
    origin: Address,
    /// The bytecode to execute.
    bytecode: Span<u8>,
    /// The call data.
    calldata: Span<u8>,
    /// Amount of native token to transfer.
    value: u256,
    // If the call is read only (cannot modify the state of the chain)
    read_only: bool,
    // Evm gas limit for the call
    gas_limit: u128,
    // Evm gas price for the call
    gas_price: u128,
    // If the context should perform a transfer
    should_transfer: bool,
}

#[generate_trait]
impl CallContextImpl of CallContextTrait {
    #[inline(always)]
    fn new(
        caller: Address,
        origin: Address,
        bytecode: Span<u8>,
        calldata: Span<u8>,
        value: u256,
        read_only: bool,
        gas_limit: u128,
        gas_price: u128,
        should_transfer: bool,
    ) -> CallContext {
        CallContext {
            caller,
            origin,
            bytecode,
            calldata,
            value,
            read_only,
            gas_limit,
            gas_price,
            should_transfer
        }
    }


    #[inline(always)]
    fn caller(self: @CallContext) -> Address {
        *self.caller
    }

    #[inline(always)]
    fn origin(self: @CallContext) -> Address {
        *self.origin
    }

    #[inline(always)]
    fn should_transfer(self: @CallContext) -> bool {
        *self.should_transfer
    }


    #[inline(always)]
    fn bytecode(self: @CallContext) -> Span<u8> {
        *self.bytecode
    }

    #[inline(always)]
    fn calldata(self: @CallContext) -> Span<u8> {
        *self.calldata
    }

    #[inline(always)]
    fn value(self: @CallContext) -> u256 {
        *self.value
    }

    #[inline(always)]
    fn read_only(self: @CallContext) -> bool {
        *self.read_only
    }

    #[inline(always)]
    fn gas_limit(self: @CallContext) -> u128 {
        *self.gas_limit
    }

    #[inline(always)]
    fn gas_price(self: @CallContext) -> u128 {
        *self.gas_price
    }
}

impl DefaultBoxCallContext of Default<Box<CallContext>> {
    fn default() -> Box<CallContext> {
        let call_ctx: CallContext = Default::default();
        BoxTrait::new(call_ctx)
    }
}

impl DefaultOptionSpanU8 of Default<Option<Span<u8>>> {
    fn default() -> Option<Span<u8>> {
        Option::None
    }
}


// *************************************************************************
//                              ExecutionContext
// *************************************************************************

/// The execution context.
/// Stores all data relevant to the current execution context.
#[derive(Destruct, Default)]
struct ExecutionContext {
    address: Address,
    program_counter: u32,
    depth: u32,
    status: Status,
    call_ctx: Box<CallContext>,
    // Return data of a child context, or the return_data of the context right before it returns
    return_data: Span<u8>,
    stack: Stack,
    memory: Memory,
    state: State,
    gas_used: u128,
}


impl DefaultBoxExecutionContext of Default<Box<ExecutionContext>> {
    fn default() -> Box<ExecutionContext> {
        let context: ExecutionContext = Default::default();
        BoxTrait::new(context)
    }
}


/// `ExecutionContext` implementation.

#[generate_trait]
impl ExecutionContextImpl of ExecutionContextTrait {
    /// Create a new execution context instance.
    #[inline(always)]
    fn new(address: Address, call_ctx: CallContext, depth: u32, state: State,) -> ExecutionContext {
        ExecutionContext {
            address,
            depth,
            program_counter: Default::default(),
            status: Default::default(),
            call_ctx: BoxTrait::new(call_ctx),
            return_data: Default::default().span(),
            stack: Default::default(),
            memory: Default::default(),
            state,
            gas_used: Default::default(),
        }
    }

    #[inline(always)]
    fn gas_limit(self: @ExecutionContext) -> u128 {
        self.call_ctx().gas_limit()
    }

    #[inline(always)]
    fn gas_price(self: @ExecutionContext) -> u128 {
        self.call_ctx().gas_price()
    }

    #[inline(always)]
    fn caller(self: @ExecutionContext) -> Address {
        self.call_ctx().caller()
    }

    #[inline(always)]
    fn value(self: @ExecutionContext) -> u256 {
        self.call_ctx().value()
    }

    #[inline(always)]
    fn calldata(self: @ExecutionContext) -> Span<u8> {
        self.call_ctx().calldata()
    }

    #[inline(always)]
    fn bytecode(self: @ExecutionContext) -> Span<u8> {
        self.call_ctx().bytecode()
    }

    #[inline(always)]
    fn should_transfer(self: @ExecutionContext) -> bool {
        self.call_ctx().should_transfer()
    }

    // *************************************************************************
    //                      DynamicContext getters
    // *************************************************************************

    #[inline(always)]
    fn reverted(self: @ExecutionContext) -> bool {
        if (*self.status == Status::Reverted) {
            return true;
        }
        false
    }

    #[inline(always)]
    fn stopped(self: @ExecutionContext) -> bool {
        // A context is considered stopped if it has status Stopped or Reverted
        if (*self.status == Status::Active) {
            return false;
        }
        true
    }

    #[inline(always)]
    fn status(self: @ExecutionContext) -> Status {
        *self.status
    }

    #[inline(always)]
    fn call_ctx(self: @ExecutionContext) -> CallContext {
        (*self.call_ctx).unbox()
    }


    #[inline(always)]
    fn return_data(self: @ExecutionContext) -> Span<u8> {
        *self.return_data
    }

    /// Stops the current execution context.
    #[inline(always)]
    fn set_stopped(ref self: ExecutionContext) {
        self.status = Status::Stopped;
    }

    #[inline(always)]
    fn gas_used(self: @ExecutionContext) -> u128 {
        *self.gas_used
    }

    #[inline(always)]
    fn increment_gas_used_unchecked(ref self: ExecutionContext, value: u128) {
        self.gas_used += value;
    }

    /// Increments the gas_used field of the current execution context by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_used + new_gas >= limit
    #[inline(always)]
    fn charge_gas(ref self: ExecutionContext, value: u128) -> Result<(), EVMError> {
        let new_gas_used = self.gas_used() + value;
        if (new_gas_used >= self.call_ctx().gas_limit()) {
            return Result::Err(EVMError::OutOfGas);
        }
        self.gas_used = new_gas_used;
        Result::Ok(())
    }

    /// Revert the current execution context.
    ///
    /// When the execution context is reverted, no more instructions can be executed
    /// (it is stopped) and contract creation and contract storage writes are
    /// reverted on its finalization.
    #[inline(always)]
    fn set_reverted(ref self: ExecutionContext) {
        self.status = Status::Reverted;
    }

    // *************************************************************************
    //                        StaticExecutionContext getters
    // *************************************************************************

    /// Getter for the currently executing account address
    #[inline(always)]
    fn address(self: @ExecutionContext) -> Address {
        *self.address
    }


    // *************************************************************************
    //                          ExecutionContext methods
    // *************************************************************************

    /// Reads and return data from bytecode.
    /// The program counter is incremented accordingly.
    ///
    /// # Arguments
    ///
    /// * `self` - The `ExecutionContext` instance to read the data from.
    /// * `len` - The length of the data to read from the bytecode.
    #[inline(always)]
    fn read_code(self: @ExecutionContext, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let code = (*self.call_ctx).unbox().bytecode().slice(self.pc(), len);

        code
    }

    /// Returns the read only field for the current call context
    ///
    /// # Arguments
    ///
    /// * `self` - The `ExecutionContext` instance to read the data from.
    #[inline(always)]
    fn read_only(self: @ExecutionContext) -> bool {
        self.call_ctx().read_only()
    }


    #[inline(always)]
    fn is_root(self: @ExecutionContext) -> bool {
        *self.depth == 0
    }


    #[inline(always)]
    fn depth(self: @ExecutionContext) -> u32 {
        *self.depth
    }

    // TODO: Implement print_debug
    /// Debug print the execution context.
    #[inline(always)]
    fn print_debug(ref self: ExecutionContext) { // debug::print_felt252('gas used');
    // self.gas_used.print();
    }

    #[inline(always)]
    fn set_pc(ref self: ExecutionContext, value: u32) {
        self.program_counter = value;
    }

    fn set_return_data(ref self: ExecutionContext, return_data: Span<u8>) {
        self.return_data = return_data;
    }

    #[inline(always)]
    fn pc(self: @ExecutionContext) -> u32 {
        *self.program_counter
    }

    fn origin(ref self: ExecutionContext) -> Address {
        self.call_ctx().origin()
    }


    fn summarize(self: ExecutionContext) -> ExecutionSummary {
        ExecutionSummary {
            status: self.status(),
            return_data: self.return_data(),
            state: self.state,
            address: self.address()
        }
    }
}
