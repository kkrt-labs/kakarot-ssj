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

/// Helper struct to prepare CREATE and CREATE2 opcodes
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
    /// As part of the CREATE family of opcodes.
    fn prepare_create(ref self: Machine, create_type: CreateType) -> Result<CreateArgs, EVMError> {
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
                .get_create_address(self.address().evm, sender_nounce)?,
            CreateType::Create2 => self
                .get_create2_address(
                    self.address().evm, salt: self.stack.pop()?, bytecode: bytecode.span()
                )?,
        };

        Result::Ok(CreateArgs { to, value, offset, size, bytecode: bytecode.span() })
    }

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

        let address: EthAddress = address_hash.slice(12, 20).try_into_result()?;

        Result::Ok(address)
    }
}
