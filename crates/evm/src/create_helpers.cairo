use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::interface::IKakarotCore;
//! CREATE, CREATE2 opcode helpers
use core::cmp::min;
use core::num::traits::Bounded;
use evm::errors::{
    ensure, EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION
};
use evm::gas;
use evm::interpreter::EVMTrait;
use evm::memory::MemoryTrait;
use evm::model::account::{Account, AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{ExecutionResult, ExecutionResultTrait, ExecutionSummary, Environment};
use evm::model::{Message, Address, Transfer};
use evm::stack::StackTrait;
use evm::state::StateTrait;
use keccak::cairo_keccak;
use starknet::{EthAddress, get_tx_info};
use utils::address::{compute_contract_address, compute_create2_contract_address};
use utils::constants;
use utils::helpers::ArrayExtTrait;
use utils::helpers::{ResultExTrait, EthAddressExTrait, U256Trait, U8SpanExTrait, ceil32};
use utils::set::SetTrait;
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

        let memory_expansion = gas::memory_expansion(self.memory.size(), offset + size);
        let init_code_gas = gas::init_code_cost(size);
        let charged_gas = match create_type {
            CreateType::Create => gas::CREATE + memory_expansion.expansion_cost + init_code_gas,
            CreateType::Create2 => {
                let calldata_words = ceil32(size) / 32;
                gas::CREATE
                    + gas::KECCAK256WORD * calldata_words.into()
                    + memory_expansion.expansion_cost
                    + init_code_gas
            },
        };
        self.charge_gas(charged_gas)?;

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
        self.accessed_addresses.add(create_args.to);

        let create_message_gas = gas::max_message_call_gas(self.gas_left);
        self.gas_left -= create_message_gas;

        ensure(!self.message().read_only, EVMError::WriteInStaticContext)?;
        self.return_data = array![].span();

        // The sender in the subcontext is the message's target
        let sender_address = self.message().target;
        let mut sender = self.env.state.get_account(sender_address.evm);
        let sender_current_nonce = sender.nonce();
        if sender.balance() < create_args.value
            || sender_current_nonce == Bounded::<u64>::MAX
            || self.message.depth == constants::STACK_MAX_DEPTH {
            self.gas_left += create_message_gas;
            return self.stack.push(0);
        }

        let mut target_account = self.env.state.get_account(create_args.to);
        let target_address = target_account.address();
        // Collision happens if the target account loaded in state has code or nonce set, meaning
        // - it's deployed on SN and is an active EVM contract
        // - it's not deployed on SN and is an active EVM contract in the Kakarot cache
        if target_account.has_code_or_nonce() {
            sender.set_nonce(sender.nonce() + 1);
            self.env.state.set_account(sender);
            return self.stack.push(0);
        };

        ensure(create_args.bytecode.len() <= constants::MAX_INITCODE_SIZE, EVMError::OutOfGas)?;

        sender.set_nonce(sender_current_nonce + 1);
        self.env.state.set_account(sender);

        let child_message = Message {
            caller: sender_address,
            target: target_address,
            gas_limit: create_message_gas,
            data: array![].span(),
            code: create_args.bytecode,
            value: create_args.value,
            should_transfer_value: true,
            depth: self.message().depth + 1,
            read_only: false,
            accessed_addresses: self.accessed_addresses.clone().spanset(),
            accessed_storage_keys: self.accessed_storage_keys.clone().spanset(),
        };

        let result = EVMTrait::process_create_message(child_message, ref self.env);
        self.merge_child(@result);

        if result.success {
            self.return_data = array![].span();
            self.stack.push(target_address.evm.into())?;
        } else {
            self.return_data = result.return_data;
            self.stack.push(0)?;
        }
        Result::Ok(())
    }

    /// Finalizes the creation of an account contract by
    /// setting its code and charging the gas for the code deposit.
    /// Since we don't have access to the child vm anymore, we charge the gas on
    /// the returned ExecutionResult of the childVM.
    ///
    /// # Arguments
    /// * `self` - The ExecutionResult to charge the gas on.
    /// * `account` - The Account to finalize
    #[inline(always)]
    fn finalize_creation(
        ref self: ExecutionResult, mut account: Account
    ) -> Result<Account, EVMError> {
        let code = self.return_data;
        let contract_code_gas = code.len().into() * gas::CODEDEPOSIT;

        if code.len() != 0 {
            ensure(*code[0] != 0xEF, EVMError::InvalidCode)?;
        }
        self.charge_gas(contract_code_gas)?;

        ensure(code.len() <= constants::MAX_CODE_SIZE, EVMError::OutOfGas)?;

        account.set_code(code);
        Result::Ok(account)
    }
}

#[cfg(test)]
mod tests {
    use contracts::test_data::counter_evm_bytecode;
    use evm::create_helpers::CreateHelpers;
    use evm::test_utils::{VMBuilderTrait};
    use starknet::EthAddress;
    use utils::address::{compute_contract_address, compute_create2_contract_address};
    //TODO: test create helpers

}
