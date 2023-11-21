//! CREATE, CREATE2 opcode helpers
use cmp::min;
use evm::context::{
    ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextType,
    ExecutionContextTrait
};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::account::{AccountTrait};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::{Address, AccountType, Transfer};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use keccak::cairo_keccak;
use starknet::{EthAddress, get_tx_info};
use utils::address::{compute_contract_address, compute_create2_contract_address};
use utils::helpers::ArrayExtTrait;
use utils::helpers::{ResultExTrait, EthAddressExTrait, U256Trait, U8SpanExTrait};
use utils::traits::{
    BoolIntoNumeric, EthAddressIntoU256, U256TryIntoResult, SpanU8TryIntoResultEthAddress
};

/// Helper struct to prepare CREATE and CREATE2 opcodes
#[derive(Drop)]
struct CreateArgs {
    to: EthAddress,
    value: u256,
    bytecode: Span<u8>,
}

#[derive(Drop)]
enum CreateType {
    CreateOrDeployTx,
    Create2,
}

#[generate_trait]
impl MachineCreateHelpersImpl of MachineCreateHelpers {
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CREATE family of opcodes.
    fn prepare_create(ref self: Machine, create_type: CreateType) -> Result<CreateArgs, EVMError> {
        let value = self.stack.pop()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let mut bytecode = Default::default();
        self.memory.load_n(size, ref bytecode, offset);

        // TODO(state): when the tx starts,
        // store get_tx_info().unbox().nonce inside the sender account nonce
        // so that we can call self.nonce() instead of get_tx_info().unbox().nonce

        let to = match create_type {
            CreateType::CreateOrDeployTx => {
                let nonce = self.state.get_account(self.address().evm)?.nonce();
                compute_contract_address(self.address().evm, sender_nonce: nonce)
            },
            CreateType::Create2 => compute_create2_contract_address(
                self.address().evm, salt: self.stack.pop()?, bytecode: bytecode.span()
            )?,
        };

        Result::Ok(CreateArgs { to, value, bytecode: bytecode.span() })
    }


    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn init_create_sub_ctx(ref self: Machine, create_args: CreateArgs) -> Result<(), EVMError> {
        let mut target_account = self.state.get_account(create_args.to)?;
        let target_address = target_account.address();

        // The caller in the subcontext is the calling context's current address
        let caller = self.address();
        let mut caller_account = self.state.get_account(caller.evm)?;
        let caller_current_nonce = caller_account.nonce();
        let caller_balance = self.state.read_balance(caller.evm)?;
        if caller_balance < create_args.value
            || target_account.nonce() == integer::BoundedInt::<u64>::max() {
            return self.stack.push(0);
        }

        if create_args.value > 0 {
            let transfer = Transfer {
                sender: self.address(), recipient: target_address, amount: create_args.value,
            };
            let result = self.state.add_transfer(transfer);
            if result.is_err() {
                return self.stack.push(0);
            }
        }

        caller_account.set_nonce(caller_current_nonce + 1);
        self.state.set_account(caller_account);

        // Collision happens if a
        // - contract is already deployed at this location (type fetched from storage)
        // - Contract has been scheduled for deployment (type set in cache)
        // If the AccountType is unknown, then there's no collision.
        if target_account.exists() {
            return self.stack.push(0);
        };

        target_account.set_nonce(1);
        target_account.set_type(AccountType::ContractAccount);
        target_account.address = target_address;
        self.state.set_account(target_account);

        let call_ctx = CallContextTrait::new(
            caller,
            create_args.bytecode,
            calldata: Default::default().span(),
            value: create_args.value,
            read_only: false,
            gas_limit: self.gas_limit(),
            gas_price: self.gas_price(),
            ret_offset: 0,
            ret_size: 0
        );

        let parent_ctx = NullableTrait::new(self.current_ctx.unbox());
        let child_ctx = ExecutionContextTrait::new(
            ExecutionContextType::Create(self.ctx_count),
            target_address,
            call_ctx,
            parent_ctx,
            Default::default().span()
        );

        // Machine logic
        self.ctx_count += 1;
        self.current_ctx = BoxTrait::new(child_ctx);

        Result::Ok(())
    }

    /// Finalize the create context by:
    /// - Pushing the deployed contract's address (success) to the Stack or 0 (failure)
    /// - Set the return data of the parent context
    /// - Store the bytecode (subcontext's return data) of the newly deployed contract account
    /// - Return to parent context.
    fn finalize_create_context(ref self: Machine) -> Result<(), EVMError> {
        // Put the status of the call on the stack.
        let status = self.status();
        let account_address = self.address().evm;
        match status {
            Status::Active => {
                return Result::Err(
                    EVMError::InvalidMachineState(ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION)
                );
            },
            // Success
            Status::Stopped => {
                let mut return_data = self.return_data();
                let mut i = 0;

                let mut account = self.state.get_account(account_address)?;
                account.set_code(return_data);
                assert(
                    account.account_type == AccountType::ContractAccount,
                    'type should be CA in finalize'
                );
                self.state.set_account(account);
                self.return_to_parent_ctx();
                self.stack.push(account_address.into())
            },
            // Failure
            Status::Reverted => {
                self.return_to_parent_ctx();
                self.stack.push(0)
            },
        }
    }
}
