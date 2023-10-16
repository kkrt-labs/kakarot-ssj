use evm::context::{CallContext, CallContextTrait, ExecutionContext, ExecutionContextTrait, Status};
use evm::interpreter::EVMInterpreterTrait;
use evm::machine::{Machine, MachineCurrentContextTrait};
use starknet::{EthAddress, ContractAddress};


/// Execute EVM bytecode.
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
        id: 0,
        :evm_address,
        // TODO remove sn_address field
        starknet_address: 0.try_into().unwrap(),
        :call_ctx,
        parent_ctx: Default::default(),
        return_data: array![].span()
    );
    let mut machine: Machine = MachineCurrentContextTrait::new(ctx);

    let mut interpreter = EVMInterpreterTrait::new();
    // Execute the transaction.
    interpreter.run(ref machine);
    (machine.status(), machine.return_data())
}

