use evm::interpreter::EVMTrait;
//! CREATE, CREATE2 opcode helpers
use cmp::min;
use evm::context::{ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextTrait};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
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
use evm::model::ExecutionResult;

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
impl CreateHelpersImpl of CreateHelpers {
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CREATE family of opcodes.
    fn prepare_create(
        ref self: ExecutionContext, create_type: CreateType
    ) -> Result<CreateArgs, EVMError> {
        let value = self.stack.pop()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let mut bytecode = Default::default();
        self.memory.load_n(size, ref bytecode, offset);

        let to = match create_type {
            CreateType::CreateOrDeployTx => {
                let nonce = self.state.get_account(self.address().evm).nonce();
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
    fn generic_create(ref self: ExecutionContext, create_args: CreateArgs) -> Result<(), EVMError> {
        let mut target_account = self.state.get_account(create_args.to);
        let target_address = target_account.address();

        // The caller in the subcontext is the calling context's current address
        let caller = self.address();
        let mut caller_account = self.state.get_account(caller.evm);
        let caller_current_nonce = caller_account.nonce();
        let caller_balance = caller_account.balance();
        if caller_balance < create_args.value
            || target_account.nonce() == integer::BoundedInt::<u64>::max() {
            return self.stack.push(0);
        }

        caller_account.set_nonce(caller_current_nonce + 1);
        self.state.set_account(caller_account);

        // Collision happens if the target account loaded in state has code or nonce set, meaning
        // - it's deployed on SN and is an active EVM contract
        // - it's not deployed on SN and is an active EVM contract in the Kakarot cache
        if target_account.has_code_or_nonce() {
            return self.stack.push(0);
        };

        let call_ctx = CallContextTrait::new(
            caller,
            self.origin(),
            create_args.bytecode,
            calldata: Default::default().span(),
            value: create_args.value,
            read_only: false,
            gas_limit: self.gas_limit(),
            gas_price: self.gas_price(),
            should_transfer: true,
        );

        // TODO(elias): Make a deep copy of the state
        let mut child_ctx = ExecutionContextTrait::new(
            target_address, call_ctx, self.depth() + 1, self.state
        );

        let result = child_ctx.process_create_message();

        match result.status {
            Status::Active => {
                // TODO: The Execution Result should not share the Status type since it cannot be active
                // This INVARIANT should be handled by the type system
                panic!(
                    "INVARIANT: Status of the Execution Context should not be Active in finalize logic"
                );
            },
            Status::Stopped => {
                self.stack.push(target_address.evm.into())?;
                self.return_data = result.return_data;
                self.state = result.state;
            },
            Status::Reverted => { self.stack.push(0)?; },
        };

        Result::Ok(())
    }
}
