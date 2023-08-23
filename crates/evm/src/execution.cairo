use starknet::{ContractAddress, EthAddress};
use array::ArrayTrait;
use traits::Default;

use evm::context::{CallContext, ExecutionContext, ExecutionSummary, ExecutionContextTrait};
use evm::interpreter::EVMInterpreterTrait;

/// Execute EVM bytecode.
fn execute(
    call_context: CallContext,
    starknet_address: ContractAddress,
    evm_address: EthAddress,
    gas_limit: u64,
    gas_price: u64,
) {
    /// TODO: implement the execute function. 
    /// TODO: This function should run the given bytecode with the given calldata and parameters.
    let mut returned_data = Default::default();
    // Create new execution context.
    let mut ctx = ExecutionContextTrait::new(
        call_context, starknet_address, evm_address, gas_limit, gas_price, returned_data, false
    );

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the transaction.
    interpreter.run(ref ctx)
}

