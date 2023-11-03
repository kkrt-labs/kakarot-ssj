//! CREATE, CREATE2 opcode helpers
use cmp::min;
use evm::context::{
    ExecutionContext, Status, CallContext, CallContextTrait, ExecutionContextType,
    ExecutionContextTrait
};
use evm::errors::{EVMError, CALL_GAS_GT_GAS_LIMIT, ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION};
use evm::machine::{Machine, MachineCurrentContextTrait};
use evm::memory::MemoryTrait;
use evm::model::account::AccountTrait;
use evm::stack::StackTrait;
use keccak::cairo_keccak;
use starknet::{EthAddress, get_tx_info};
use utils::helpers::ArrayExtTrait;
use utils::helpers::{ByteArrayExTrait, ResultExTrait, EthAddressExt, U256Trait};
use utils::traits::{BoolIntoNumeric, U256TryIntoResult, SpanU8TryIntoResultEthAddress};

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
#[derive(Drop)]
struct CreateArgs {
    to: EthAddress,
    value: u256,
    offset: usize,
    size: usize,
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
    /// As part of the CALL family of opcodes.
    fn prepare_create(ref self: Machine, create_type: CreateType) -> Result<CreateArgs, EVMError> {
        // For CALL and CALLCODE, we pop 5 items off of the stack
        // For STATICCALL and DELEGATECALL, we pop 4 items off of the stack
        // The difference being the "value" parameter in CALL and CALLCODE.
        let value = self.stack.pop()?;
        let offset = self.stack.pop_usize()?;
        let size = self.stack.pop_usize()?;

        let mut bytecode = Default::default();
        self.memory.load_n(size, ref bytecode, offset);

        // TODO(state): when the tx starts, 
        // store get_tx_info().unbox().nonce inside the sender account nonce
        let sender_nounce = get_tx_info().unbox().nonce;

        let to = match create_type {
            CreateType::CreateOrDeployTx => self
                .get_create_address(self.evm_address(), sender_nounce)?,
            CreateType::Create2 => self
                .get_create2_address(
                    self.evm_address(), salt: self.stack.pop()?, bytecode: bytecode.span()
                )?,
        };

        Result::Ok(CreateArgs { to, value, offset, size, bytecode: bytecode.span() })
    }

    // /// Initializes and enters into a new sub-context
    // /// The Machine will change its `current_ctx` to point to the
    // /// newly created sub-context.
    // /// Then, the EVM execution loop will start on this new execution context.
    // fn init_sub_ctx(
    //     ref self: Machine, call_args: CreateArgs, read_only: bool
    // ) -> Result<(), EVMError> {
    //     // Case 2: `to` address is not a precompile
    //     // We enter the standard flow
    //     let maybe_account = AccountTrait::account_type_at(call_args.to)?;
    //     let bytecode = match maybe_account {
    //         Option::Some(acc) => acc.bytecode()?,
    //         Option::None => Default::default().span(),
    //     };

    //     // The caller in the subcontext is the current context's current address
    //     let caller = self.evm_address();

    //     let call_ctx = CallContextTrait::new(
    //         caller,
    //         bytecode,
    //         call_args.calldata,
    //         call_args.value,
    //         read_only,
    //         call_args.gas,
    //         self.gas_price(),
    //         call_args.ret_offset,
    //         call_args.ret_size
    //     );

    //     let parent_ctx = NullableTrait::new(self.current_ctx.unbox());
    //     let child_ctx = ExecutionContextTrait::new(
    //         ExecutionContextType::Call(self.ctx_count),
    //         call_args.to,
    //         call_ctx,
    //         parent_ctx,
    //         Default::default().span()
    //     );

    //     // Machine logic
    //     self.ctx_count += 1;
    //     self.current_ctx = BoxTrait::new(child_ctx);

    //     Result::Ok(())
    // }

    // /// Finalize the calling context by:
    // /// - Pushing the execution status to the Stack
    // /// - Set the return data of the parent context
    // /// - Store the return data in Memory
    // /// - Return to parent context and decrease the ctx_count.
    // fn finalize_create_context(ref self: Machine) -> Result<(), EVMError> {
    //     // Put the status of the call on the stack.
    //     let status = self.status();
    //     let success = match status {
    //         Status::Active => {
    //             return Result::Err(
    //                 EVMError::InvalidMachineState(ACTIVE_MACHINE_STATE_IN_CALL_FINALIZATION)
    //             );
    //         },
    //         Status::Stopped => 1,
    //         Status::Reverted => 0,
    //     };
    //     self.stack.push(success)?;

    //     // Get the return_data of the parent context.
    //     let return_data = self.return_data();

    //     // Get the min between len(return_data) and call_ctx.ret_size.
    //     let call_ctx = self.call_ctx();
    //     let return_data_len = min(return_data.len(), call_ctx.ret_size);

    //     let return_data = return_data.slice(0, return_data_len);
    //     self.memory.store_n(return_data, call_ctx.ret_offset);

    //     // Return from the current sub ctx by setting the execution context
    //     // to the parent context.
    //     self.return_to_parent_ctx()
    // }

    fn get_create_address(
        ref self: Machine, sender_address: EthAddress, sender_nounce: felt252
    ) -> Result<EthAddress, EVMError> {
        panic_with_felt252('get_create_address todo')
    }


    fn get_create2_address(
        self: @Machine, sender_address: EthAddress, salt: u256, bytecode: Span<u8>
    ) -> Result<EthAddress, EVMError> {
        let mut bytecode = ByteArrayExTrait::from_bytes(bytecode);
        let (mut keccak_input, last_input_word, last_input_num_bytes) = bytecode.to_u64_words();
        let hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes)
            .reverse_endianness()
            .to_bytes();

        let sender_address = sender_address.to_bytes();

        let salt = salt.to_bytes();

        let mut preimage: Array<u8> = array![];

        preimage.concat(array![0xff].span());
        preimage.concat(sender_address);
        preimage.concat(salt);
        preimage.concat(hash);

        let mut preimage = ByteArrayExTrait::from_bytes(preimage.span());
        let (mut keccak_input, last_input_word, last_input_num_bytes) = preimage.to_u64_words();
        let address_hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes)
            .reverse_endianness()
            .to_bytes();

        // Since cairo_keccak returns a little endian result
        // We take a slice from 0 to 20th element
        let address: EthAddress = address_hash.slice(12, 20).try_into_result()?;

        // Result::Ok(address)
        Result::Ok(address)
    }
}
