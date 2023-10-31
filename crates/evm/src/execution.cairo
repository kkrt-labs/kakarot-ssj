use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextType, ExecutionContextTrait,
    Status
};
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
    origin: EthAddress,
    evm_address: EthAddress,
    bytecode: Span<u8>,
    calldata: Span<u8>,
    value: u256,
    gas_price: u128,
    gas_limit: u128,
    read_only: bool,
) -> ExecutionResult {
    // Create a new root execution context.
    let call_ctx = CallContextTrait::new(
        caller: origin,
        :bytecode,
        :calldata,
        :value,
        :read_only,
        :gas_limit,
        :gas_price,
        ret_offset: 0,
        ret_size: 0
    );
    let ctx = ExecutionContextTrait::new(
        ctx_type: Default::default(),
        :evm_address,
        :call_ctx,
        parent_ctx: Default::default(),
        return_data: Default::default().span()
    );

    // Initiate the Machine with the root context
    let mut machine: Machine = MachineCurrentContextTrait::new(ctx);

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the bytecode
    interpreter.run(ref machine);
    ExecutionResult {
        status: machine.status(),
        return_data: machine.return_data(),
        destroyed_contracts: machine.destroyed_contracts(),
        create_addresses: machine.create_addresses(),
        events: machine.events(),
        error: machine.error()
    }
}

