use evm::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait, Status};
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use starknet::{EthAddress, ContractAddress};


/// Runs the given bytecode with the given calldata and parameters.
///
/// # Arguments
///
/// * `evm_contract_address` - The EVM address of the called contract. Set to 0
/// if there is no notion of deployed contract in the bytecode.
/// * `bytecode` - The bytecode to run.
/// * `calldata` - The calldata of the execution.
/// * `value` - The value of the execution.
/// * `gas_limit` - The gas limit of the execution.
/// * `gas_price` - The gas price for the execution.
/// # Returns
/// * The final Status of the execution.
/// * The return data of the execution.
fn execute(
    evm_address: EthAddress,
    bytecode: Span<u8>,
    calldata: Span<u8>,
    value: u256,
    gas_price: u64,
    gas_limit: u64,
) -> (Status, Span<u8>) {
    let call_ctx = CallContextTrait::new(
        caller: evm_address, :bytecode, :calldata, :value, read_only: false, :gas_limit, :gas_price
    );
    // Create new execution context.
    let ctx = ExecutionContextTrait::new(
        id: 0, :evm_address, :call_ctx, parent_ctx: Default::default(), return_data: array![].span()
    );
    let mut machine: Machine = MachineCurrentContextTrait::new(ctx);

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the bytecode.
    interpreter.run(ref machine);
    (machine.status(), machine.return_data())
}

