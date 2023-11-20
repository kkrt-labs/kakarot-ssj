//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use cmp::min;
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;
use evm::context::{
    ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextType,
    ExecutionContextTrait
};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::{Transfer, Address};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use starknet::{EthAddress, get_contract_address};
use utils::helpers::compute_starknet_address;
use utils::traits::{BoolIntoNumeric, U256TryIntoResult};

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
#[derive(Drop)]
struct CallArgs {
    caller: Address,
    code_address: Address,
    to: Address,
    gas: u128,
    value: u256,
    calldata: Span<u8>,
    ret_offset: usize,
    ret_size: usize,
    should_transfer: bool,
}

#[derive(Drop)]
enum CallType {
    Call,
    DelegateCall,
    CallCode,
    StaticCall,
}

#[generate_trait]
impl MachineCallHelpersImpl of MachineCallHelpers {
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CALL family of opcodes.
    fn prepare_call(ref self: Machine, call_type: @CallType) -> Result<CallArgs, EVMError> {
        let gas = self.stack.pop_u128()?;

        let code_address = self.stack.pop_eth_address()?;
        let to = match call_type {
            CallType::Call => code_address,
            CallType::DelegateCall => self.address().evm,
            CallType::CallCode => self.address().evm,
            CallType::StaticCall => code_address
        };

        let kakarot_core = KakarotCore::unsafe_new_contract_state();

        let code_address = Address {
            evm: code_address, starknet: kakarot_core.compute_starknet_address(code_address)
        };

        let to = Address { evm: to, starknet: kakarot_core.compute_starknet_address(to) };

        let (value, should_transfer) = match call_type {
            CallType::Call => (self.stack.pop()?, true),
            CallType::DelegateCall => (self.value(), false),
            CallType::CallCode => (self.stack.pop()?, false),
            CallType::StaticCall => (0, false),
        };

        let caller = match call_type {
            CallType::Call => self.address(),
            CallType::DelegateCall => self.call_ctx().caller,
            CallType::CallCode => self.address(),
            CallType::StaticCall => self.address(),
        };

        let args_offset = self.stack.pop_usize()?;
        let args_size = self.stack.pop_usize()?;

        let ret_offset = self.stack.pop_usize()?;
        let ret_size = self.stack.pop_usize()?;

        let mut calldata = Default::default();
        self.memory.load_n(args_size, ref calldata, args_offset);

        Result::Ok(
            CallArgs {
                caller,
                code_address,
                to,
                value,
                gas,
                calldata: calldata.span(),
                ret_offset,
                ret_size,
                should_transfer
            }
        )
    }

    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn init_call_sub_ctx(
        ref self: Machine, call_args: CallArgs, read_only: bool
    ) -> Result<(), EVMError> {
        if call_args.should_transfer && call_args.value > 0 {
            let transfer = Transfer {
                sender: self.address(), recipient: call_args.to, amount: call_args.value,
            };
            let result = self.state.add_transfer(transfer);
            if result.is_err() {
                self.stack.push(0)?;
                return Result::Ok(());
            }
        }

        // Case 1: `to` address is a precompile
        // Handle precompile logic
        if is_precompile(call_args.to.evm) {
            panic_with_felt252('precompiles not implemented');
        }

        // Case 2: `to` address is not a precompile
        // We enter the standard flow
        let bytecode = self.state.get_account(call_args.code_address.evm)?.code;

        let call_ctx = CallContextTrait::new(
            call_args.caller,
            bytecode,
            call_args.calldata,
            call_args.value,
            read_only,
            call_args.gas,
            self.gas_price(),
            call_args.ret_offset,
            call_args.ret_size
        );

        let parent_ctx = NullableTrait::new(self.current_ctx.unbox());
        let child_ctx = ExecutionContextTrait::new(
            ExecutionContextType::Call(self.ctx_count),
            call_args.to,
            call_ctx,
            parent_ctx,
            Default::default().span()
        );

        // Machine logic
        self.ctx_count += 1;
        self.current_ctx = BoxTrait::new(child_ctx);

        Result::Ok(())
    }

    /// Finalize the calling context by:
    /// - Pushing the execution status to the Stack
    /// - Set the return data of the parent context
    /// - Store the return data in Memory
    /// - Return to parent context.
    fn finalize_calling_context(ref self: Machine) -> Result<(), EVMError> {
        // Put the status of the call on the stack.
        let status = self.status();
        let success = match status {
            Status::Active => {
                return Result::Err(
                    EVMError::InvalidMachineState(ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION)
                );
            },
            Status::Stopped => 1,
            Status::Reverted => 0,
        };
        self.stack.push(success)?;

        // Get the return_data of the parent context.
        let return_data = self.return_data();

        // Get the min between len(return_data) and call_ctx.ret_size.
        let call_ctx = self.call_ctx();
        let return_data_len = min(return_data.len(), call_ctx.ret_size);

        let return_data = return_data.slice(0, return_data_len);
        self.memory.store_n(return_data, call_ctx.ret_offset);

        // Return from the current sub ctx by setting the execution context
        // to the parent context.
        self.return_to_parent_ctx()
    }
}

/// Check whether a `to` address for a call-family opcode is a precompile.
fn is_precompile(to: EthAddress) -> bool {
    let to: felt252 = to.into();
    if to.into() < 0x10_u256 {
        return true;
    }
    false
}
