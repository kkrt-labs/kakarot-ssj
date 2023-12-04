//! CREATE, CREATE2 opcode helpers
use cmp::min;
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::gas;
use evm::interpreter::EVMTrait;
use evm::memory::MemoryTrait;
use evm::model::ExecutionSummary;
use evm::model::account::{AccountTrait};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Message, Address, AccountType, Transfer};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use keccak::cairo_keccak;
use starknet::{EthAddress, get_tx_info};
use utils::address::{compute_contract_address, compute_create2_contract_address};
use utils::constants;
use utils::helpers::ArrayExtTrait;
use utils::helpers::{ResultExTrait, EthAddressExTrait, U256Trait, U8SpanExTrait, ceil32};
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

#[derive(Copy, Drop)]
enum CreateType {
    Create,
    Create2,
}

#[generate_trait]
impl CreateHelpersImpl of CreateHelpers {
    ///  Prepare the initialization of a new child or so-called sub-context
    /// As part of the CREATE family of opcodes.
    fn prepare_create(ref self: VM, create_type: CreateType) -> Result<CreateArgs, EVMError> {
        let value = self.stack.pop()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let expand_memory_cost = gas::memory_expansion_cost(self.memory.size(), offset + size);
        let init_code_gas = gas::init_code_cost(size);
        let charged_gas = match create_type {
            CreateType::Create => gas::CREATE + expand_memory_cost + init_code_gas,
            CreateType::Create2 => {
                let calldata_words = ceil32(size) / 32;
                gas::CREATE
                    + gas::KECCAK256WORD * calldata_words.into()
                    + expand_memory_cost
                    + init_code_gas
            },
        };
        self.charge_gas(gas::CREATE + expand_memory_cost + init_code_gas)?;

        let mut bytecode = Default::default();
        self.memory.load_n(size, ref bytecode, offset);

        let to = match create_type {
            CreateType::Create => {
                let nonce = self.env.state.get_account(self.message().target.evm).nonce();
                compute_contract_address(self.message().target.evm, sender_nonce: nonce)
            },
            CreateType::Create2 => compute_create2_contract_address(
                self.message().target.evm, salt: self.stack.pop()?, bytecode: bytecode.span()
            )?,
        };

        Result::Ok(CreateArgs { to, value, bytecode: bytecode.span() })
    }


    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn generic_create(ref self: VM, create_args: CreateArgs) -> Result<(), EVMError> {
        let mut target_account = self.env.state.get_account(create_args.to);
        let target_address = target_account.address();

        //TODO(gas) charge max message call gas

        // The caller in the subcontext is the calling context's current address
        let caller = self.message().target;
        let mut caller_account = self.env.state.get_account(caller.evm);
        let caller_current_nonce = caller_account.nonce();
        let caller_balance = caller_account.balance();
        if caller_balance < create_args.value
            || target_account.nonce() == integer::BoundedInt::<u64>::max()
            || self.message.depth
            + 1 == constants::STACK_MAX_DEPTH {
            return self.stack.push(0);
        }

        // Collision happens if the target account loaded in state has code or nonce set, meaning
        // - it's deployed on SN and is an active EVM contract
        // - it's not deployed on SN and is an active EVM contract in the Kakarot cache
        if target_account.has_code_or_nonce() {
            return self.stack.push(0);
        };

        //TODO(gas) ensure calldata_len <= 2*MAX_CODE_SIZE

        caller_account.set_nonce(caller_current_nonce + 1);
        self.env.state.set_account(caller_account);

        let child_message = Message {
            caller,
            target: target_address,
            value: create_args.value,
            should_transfer_value: true,
            code: create_args.bytecode,
            data: Default::default().span(),
            gas_limit: self.message().gas_limit,
            depth: self.message().depth + 1,
            read_only: false,
        };

        let result = EVMTrait::process_create_message(child_message, ref self.env);

        if result.success {
            self.return_data = Default::default().span();
            self.stack.push(target_address.evm.into())?;
        } else {
            self.stack.push(0)?;
        }
        Result::Ok(())
    }
}
