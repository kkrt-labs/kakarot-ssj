//! SHA3.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use evm::memory::{InternalMemoryTrait, MemoryTrait};
use evm::errors::EVMError;
use evm::helpers::U256IntoResultU32;
use keccak::cairo_keccak;
use utils::helpers::{u256_to_bytes_array, u128_split};

use array::ArrayTrait;

#[generate_trait]
impl Sha3Impl of Sha3Trait {
    /// SHA3 operation.
    /// Hashes n bytes in memory at a given offset in memory.
    /// # Specification: https://www.evm.codes/#20?fork=shanghai
    fn exec_sha3(ref self: ExecutionContext) -> Result<(), EVMError> {
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let mut size: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let init_size = size;

        let mut toHash: Array<u64> = ArrayTrait::<u64>::new();
        let mut last_input: u64 = 0;
        let mut counter = 0;
        loop {
            if size < 32 {
                break;
            }
            // If we try to read unallocted memory slot, we'll feed the data to hash with 0s
            // and allocated the memory space the end of the process, which is cheaper than allocating every load().
            if (offset + (32 * counter)) > self.memory.bytes_len {
                toHash.append(0);
                toHash.append(0);
                toHash.append(0);
                toHash.append(0);
                counter += 1;
                size -= 32;
                continue;
            }
            // Load the 32 words and reverse the bytes order,
            let mut loaded = self.memory.load_internal((offset + (32 * counter)));
            loaded.low = integer::u128_byte_reverse(loaded.low);
            loaded.high = integer::u128_byte_reverse(loaded.high);

            // Split the loaded word into u64 to feed cairo_keccak
            let (highL, lowL) = u128_split(loaded.high);
            let (highH, lowH) = u128_split(loaded.low);
            toHash.append(lowL);
            toHash.append(highL);
            toHash.append(lowH);
            toHash.append(highH);

            counter += 1;
            size -= 32;
        };

        if size > 0 {
            let mut loaded = 0;
            if (offset + (32 * counter)) > self.memory.bytes_len {
                loaded = 0;
            } else {
                loaded = self.memory.load_internal((offset + (32 * counter)));
            }

            loaded.low = integer::u128_byte_reverse(loaded.low);
            loaded.high = integer::u128_byte_reverse(loaded.high);
            let (highL, lowL) = u128_split(loaded.high);
            let (highH, lowH) = u128_split(loaded.low);

            if size < 8 {
                last_input = lowL;
            } else if size < 16 {
                size -= 8;
                toHash.append(lowL);
                last_input = highL;
            } else if size < 24 {
                size -= 16;
                toHash.append(lowL);
                toHash.append(highL);
                last_input = lowH;
            } else {
                size -= 24;
                toHash.append(lowL);
                toHash.append(highL);
                toHash.append(lowH);
                last_input = highH;
            }
        }

        self.memory.ensure_length(offset + init_size);

        let mut hash = cairo_keccak(ref toHash, last_input, size);
        hash.low = integer::u128_byte_reverse(hash.low);
        hash.high = integer::u128_byte_reverse(hash.high);
        let tmp = hash.low;
        hash.low = hash.high;
        hash.high = tmp;

        self.stack.push(hash)
    }
}
