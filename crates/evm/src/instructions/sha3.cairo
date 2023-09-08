//! SHA3.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::errors::EVMError;
use evm::helpers::U256IntoResultU32;
use keccak::{cairo_keccak, u128_split};
use utils::helpers::{u256_to_bytes_array};

use array::ArrayTrait;

#[generate_trait]
impl Sha3Impl of Sha3Trait {
    /// SHA3 operation : Hashes n bytes in memory at a given offset in memory.
    ///
    /// # Arguments
    /// * `offset` - The offset in memory where to read the datas
    /// * `size` - The amount of bytes to read
    /// 
    /// Format 32 bytes chunk of data read from memory into 64 bits chunk in little endian
    /// to be able to call cairro_keccak.
    /// 
    /// # Specification: https://www.evm.codes/#20?fork=shanghai
    fn exec_sha3(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let mut size: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let init_size = size;

        let mut to_hash: Array<u64> = Default::default();
        let mut last_input: u64 = 0;
        let mut slot_to_read = offset;
        loop {
            if size < 32 {
                break;
            }
            // Pad left the hash input with zeroes for out-of-bound bytes
            if slot_to_read > self.memory.bytes_len {
                to_hash.append(0);
                to_hash.append(0);
                to_hash.append(0);
                to_hash.append(0);
                slot_to_read += 32;
                size -= 32;
                continue;
            }
            // Load the 32 words and reverse the bytes order,
            let mut loaded = self.memory.load_internal(slot_to_read);
            loaded.low = integer::u128_byte_reverse(loaded.low);
            loaded.high = integer::u128_byte_reverse(loaded.high);

            // Split the loaded word into u64 to feed cairo_keccak
            let (high_l, low_l) = u128_split(loaded.high);
            let (high_h, low_h) = u128_split(loaded.low);
            to_hash.append(low_l);
            to_hash.append(high_l);
            to_hash.append(low_h);
            to_hash.append(high_h);

            slot_to_read += 32;
            size -= 32;
        };

        if size > 0 {
            // Load the last 32 bytes chunk containing required bytes 
            let mut loaded: u256 = if slot_to_read > self.memory.bytes_len {
                0
            } else {
                self.memory.load_internal(slot_to_read)
            };

            loaded.low = integer::u128_byte_reverse(loaded.low);
            loaded.high = integer::u128_byte_reverse(loaded.high);
            let (high_l, low_l) = u128_split(loaded.high);
            let (high_h, low_h) = u128_split(loaded.low);

            // Assign the last input accordingly to required bytes amount
            if size < 8 {
                last_input = low_l;
            } else if size < 16 {
                size -= 8;
                to_hash.append(low_l);
                last_input = high_l;
            } else if size < 24 {
                size -= 16;
                to_hash.append(low_l);
                to_hash.append(high_l);
                last_input = low_h;
            } else {
                size -= 24;
                to_hash.append(low_l);
                to_hash.append(high_l);
                to_hash.append(low_h);
                last_input = high_h;
            }
        }

        self.memory.ensure_length(offset + init_size);

        let mut hash = cairo_keccak(ref to_hash, last_input, size);
        hash.low = integer::u128_byte_reverse(hash.low);
        hash.high = integer::u128_byte_reverse(hash.high);
        let tmp = hash.low;
        hash.low = hash.high;
        hash.high = tmp;

        self.stack.push(hash)
    }
}
