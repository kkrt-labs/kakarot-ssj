use evm::context::{
    CallContext, CallContextTrait, ExecutionContext, ExecutionContextType, ExecutionContextTrait,
    Status
};
use evm::errors::{EVMError, EVMErrorTrait, CONTRACT_ACCOUNT_EXISTS};
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineTrait, MachineBuilderTrait};
use evm::model::account::{AccountTrait};
use evm::model::{Address, Transfer, ExecutionResult, AccountType};
use evm::state::{State, StateTrait};
use starknet::{EthAddress, ContractAddress};
use utils::helpers::{U256Trait, compute_starknet_address};

/// Creates an instance of the EVM to execute a transaction.
///
/// # Arguments
/// * `origin` - The EVM address of the origin of the transaction.
/// * `target` - The EVM address of the called contract.
/// * `calldata` - The calldata of the execution.
/// * `value` - The value of the execution.
/// * `gas_limit` - The gas limit of the execution.
/// * `gas_price` - The gas price for the execution.
/// * `read_only` - Whether the execution is read only.
/// * `is_deploy_tx` - Whether the execution is a deploy transaction.
///
/// # Returns
/// * ExecutionResult struct, containing:
/// *   The execution status
/// *   The return data of the execution.
/// *   The destroyed contracts
/// *   The created contracts
/// *   The events emitted
fn execute(
    origin: Address,
    target: Address,
    mut calldata: Span<u8>,
    value: u256,
    gas_price: u128,
    gas_limit: u128,
    read_only: bool,
    is_deploy_tx: bool,
) -> ExecutionResult {
    // Create a new root execution context.
    let mut state: State = Default::default();

    let mut target_account = state.get_account(target.evm);
    let (bytecode, calldata) = if is_deploy_tx {
        (calldata, array![].span())
    } else {
        (target_account.code, calldata)
    };

    let call_ctx = CallContextTrait::new(
        caller: origin,
        :bytecode,
        :calldata,
        :value,
        :read_only,
        :gas_limit,
        :gas_price,
        ret_offset: 0,
        ret_size: 0,
    );
    let ctx = ExecutionContextTrait::new(
        ctx_type: ExecutionContextType::Root(is_deploy_tx),
        address: target,
        :call_ctx,
        parent_ctx: Default::default(),
        return_data: Default::default().span()
    );

    let mut machine = MachineBuilderTrait::new().set_state(state).set_ctx(ctx).build();

    let transfer = Transfer { sender: origin, recipient: target, amount: value };
    match machine.state.add_transfer(transfer) {
        Result::Ok(x) => {},
        Result::Err(err) => { return reverted_with_err(machine, err); }
    }

    if is_deploy_tx {
        // Check collision
        if target_account.has_code_or_nonce() {
            return reverted_with_err(machine, EVMError::DeployError(CONTRACT_ACCOUNT_EXISTS));
        }
        // Nonce is set to 1 in the case of a deploy tx
        target_account.nonce = 1;
        target_account.account_type = AccountType::ContractAccount;
        machine.state.set_account(target_account);
    }

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the bytecode
    interpreter.run(ref machine);
    let address = machine.address();
    let status = machine.status();
    let return_data = machine.return_data();
    ExecutionResult { address, status, return_data, state: machine.state }
}

fn reverted_with_err(mut machine: Machine, error: EVMError) -> ExecutionResult {
    let return_data = Into::<felt252, u256>::into(error.to_string()).to_bytes();
    ExecutionResult {
        address: machine.address(),
        status: Status::Reverted,
        return_data: Default::default().span(),
        state: machine.state,
    }
}
