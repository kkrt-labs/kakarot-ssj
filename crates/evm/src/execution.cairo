use evm::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait, Status};
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::model::ExecutionResult;
use starknet::{EthAddress, ContractAddress};

/// Creates an instance of the EVM to execute the given bytecode.
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
/// * ExecutionResult struct, containing:
/// *   The execution status
/// *   The return data of the execution.
/// *   The destroyed contracts
/// *   The created contracts
/// *   The events emitted
fn execute(
    evm_address: EthAddress,
    bytecode: Span<u8>,
    calldata: Span<u8>,
    value: u256,
    gas_price: u64,
    gas_limit: u64,
) -> ExecutionResult {
    // Create a new root execution context.
    let call_ctx = CallContextTrait::new(
        caller: evm_address, :bytecode, :calldata, :value, read_only: false, :gas_limit, :gas_price
    );
    let ctx = ExecutionContextTrait::new(
        id: 0,
        :evm_address,
        :call_ctx,
        parent_ctx: Default::default(),
        return_data: Default::default().span()
    );

    // Initiate the Machine with the root context
    let mut machine: Machine = MachineCurrentContextTrait::new(ctx);

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the bytecode.
    interpreter.run(ref machine);
    ExecutionResult {
        status: machine.status(),
        return_data: machine.return_data(),
        destroyed_contracts: machine.destroyed_contracts(),
        create_addresses: machine.create_addresses(),
        events: machine.events()
    }
}

