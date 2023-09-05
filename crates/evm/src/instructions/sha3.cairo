//! SHA3.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use evm::errors::EVMError;
use evm::helpers::U256IntoResultU32;
use evm::helpers::U256IntoResultU64;
use evm::helpers::U64IntoResultU32;
//use keccak::keccak_u256s_be_inputs;
use keccak::keccak_u256s_le_inputs;
use keccak::cairo_keccak;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use utils::helpers::u256_to_bytes_array;
use utils::helpers::u128_split;

use utils::hashing::keccak::KeccakTrait;
use utils::types::bytes::Bytes;

use starknet::SyscallResultTrait;
use array::ArrayTrait;

use debug::PrintTrait;

#[generate_trait]
impl Sha3Impl of Sha3Trait {
    /// SHA3 operation.
    /// Hashes n bytes in memory at a given offset in memory.
    /// # Specification: https://www.evm.codes/#20?fork=shanghai
    fn exec_sha3(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset: u64 = Into::<u256, Result<u64, EVMError>>::into((self.stack.pop()?))?;
        let mut size: u64 = Into::<u256, Result<u64, EVMError>>::into((self.stack.pop()?))?;

        let mut toHash: Array<u64> = ArrayTrait::<u64>::new();
        let mut last_input: u64 = 0;
        let mut counter = 0;
        loop {
            if size < 32 {
                break;
            }
            if (offset + (32 * counter)) > self.memory.bytes_len.into() {
                toHash.append(0);
                toHash.append(0);
                toHash.append(0);
                toHash.append(0);
                counter += 1;
                size -= 32;
                continue;
            }
            let mut mem = self.memory.load_internal((offset + (32 * counter)).try_into().unwrap());
            mem.low = integer::u128_byte_reverse(mem.low);
            mem.high = integer::u128_byte_reverse(mem.high);

            let (highL, lowL) = u128_split(mem.high);
            let (highH, lowH) = u128_split(mem.low);
            toHash.append(lowL);
            toHash.append(highL);
            toHash.append(lowH);
            toHash.append(highH);

            counter += 1;
            size -= 32;
        };
        let mut last_input_size: u32 = size.try_into().unwrap();
        if last_input_size > 0 {
            let mut mem = 0;
            if (offset + (32 * counter)) > self.memory.bytes_len.into() {
                mem = 0;
            } else {
                mem = self.memory.load_internal((offset + (32 * counter)).try_into().unwrap());
            }

            mem.low = integer::u128_byte_reverse(mem.low);
            mem.high = integer::u128_byte_reverse(mem.high);
            let (highL, lowL) = u128_split(mem.high);
            let (highH, lowH) = u128_split(mem.low);

            if last_input_size < 8 {
                last_input = lowL;
            } else if last_input_size < 16 {
                last_input_size -= 8;
                toHash.append(lowL);
                last_input = highL;
            } else if last_input_size < 24 {
                last_input_size -= 16;
                toHash.append(lowL);
                toHash.append(highL);
                last_input = lowH;
            } else {
                last_input_size -= 24;
                toHash.append(lowL);
                toHash.append(highL);
                toHash.append(lowH);
                last_input = highH;
            }
        }
        self.memory.ensure_length((offset.into() + size).try_into().unwrap());

        let mut hash = cairo_keccak(ref toHash, last_input, last_input_size);
        hash.low = integer::u128_byte_reverse(hash.low);
        hash.high = integer::u128_byte_reverse(hash.high);
        let tmp = hash.low;
        hash.low = hash.high;
        hash.high = tmp;

        self.stack.push(hash)
    }
}
