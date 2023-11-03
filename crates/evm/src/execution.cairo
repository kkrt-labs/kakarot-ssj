use core::result::ResultTrait;
use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextType, ExecutionContextTrait,
    Status
};
use evm::errors::{EVMError, EVMErrorTrait};
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::model::account::{AccountTrait};
use evm::model::{Address, Transfer, ExecutionResult};
use evm::state::{StateTrait};
use starknet::{EthAddress, ContractAddress};
use utils::helpers::compute_starknet_address;

/// Creates an instance of the EVM to execute the given bytecode.
///
/// # Arguments
///
/// * `target` - The EVM address of the called contract. Set to 0
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
    origin: Address,
    address: Address,
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
        :address,
        :call_ctx,
        parent_ctx: Default::default(),
        return_data: Default::default().span()
    );

    // Initiate the Machine with the root context
    let mut machine: Machine = MachineCurrentContextTrait::new(ctx);

    let transfer = Transfer { sender: origin, recipient: address, amount: value };
    match machine.state.add_transfer(transfer) {
        Result::Ok(x) => {},
        Result::Err(err) => {
            return ExecutionResult {
                status: Status::Reverted,
                return_data: Default::default().span(),
                destroyed_contracts: Default::default().span(),
                create_addresses: Default::default().span(),
                events: Default::default().span(),
                state: machine.state,
                error: Option::Some(err)
            };
        }
    }

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the bytecode
    interpreter.run(ref machine);
    let status = machine.status();
    let return_data = machine.return_data();
    let destroyed_contracts = machine.destroyed_contracts();
    let create_addresses = machine.create_addresses();
    let events = machine.events();
    let error = machine.error();
    ExecutionResult {
        status,
        return_data,
        destroyed_contracts,
        create_addresses,
        events,
        state: machine.state,
        error
    }
}

