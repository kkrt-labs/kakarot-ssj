use starknet::{ContractAddress, EthAddress};
use evm::context::{CallContext, ExecutionContext, ExecutionSummary, ExecutionContextTrait};
use evm::interpreter::EVMInterpreterTrait;


/// Execute EVM bytecode.
fn execute(call_context: CallContext, parent_context: Nullable<ExecutionContext>,) {
    /// TODO: implement the execute function.
    // Create new execution context.
    let mut ctx: ExecutionContext = Default::default();

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the transaction.
    interpreter.run(ref ctx)
}

