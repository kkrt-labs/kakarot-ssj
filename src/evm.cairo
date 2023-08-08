use starknet::{ContractAddress, EthAddress};
use array::ArrayTrait;
use traits::Default;

use kakarot::context::{CallContext, ExecutionContext, ExecutionSummary, ExecutionContextTrait};
use kakarot::instructions::EVMInstructionsTrait;

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
    // Compute the intrinsic gas cost for the current transaction and increase the gas used.
    ctx.process_intrinsic_gas_cost();
    // Print the execution context.
    ctx.print_debug();
    let mut evm_instructions = EVMInstructionsTrait::new();
    // Execute the transaction.
    evm_instructions.run(ref ctx)
}

