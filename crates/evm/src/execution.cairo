use starknet::{ContractAddress, EthAddress};
use evm::context::{CallContext, ExecutionContext, ExecutionSummary, ExecutionContextTrait};
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::Machine;


/// Execute EVM bytecode.
fn execute(call_context: CallContext, parent_context: Nullable<ExecutionContext>,) {
    /// TODO: implement the execute function.
    // Create new execution context.
    let mut machine: Machine = Default::default();

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the transaction.
    interpreter.run(ref machine)
}

