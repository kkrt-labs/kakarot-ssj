//! SHA3.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use evm::memory::MemoryTrait;
use evm::errors::EVMError;
use evm::helpers::U256IntoResultU32;
use keccak::{cairo_keccak, u128_split};
use utils::helpers::{split_u256_into_u64_little, u256_bytes_reverse};

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
        let mut offset: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let mut size: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;

        let mut to_hash: Array<u64> = Default::default();
        let mut last_input: u64 = 0;

        // Fill to_hash with bytes from memory
        loop {
            if (size < 32) | (offset > self.memory.bytes_len) {
                break;
            }
            let (loaded, _) = self.memory.load(offset);
            let ((high_h, low_h), (high_l, low_l)) = split_u256_into_u64_little(loaded);
            to_hash.append(low_h);
            to_hash.append(high_h);
            to_hash.append(low_l);
            to_hash.append(high_l);

            offset += 32;
            size -= 32;
        };

        // Bytes from unallocated memory are set to 0
        loop {
            if size < 32 {
                break;
            }
            to_hash.append(0);
            to_hash.append(0);
            to_hash.append(0);
            to_hash.append(0);

            offset += 32;
            size -= 32;
        };

        // Fill last_input with last bytes to hash
        if size > 0 {
            let (loaded, _) = self.memory.load(offset);
            last_input = InternalSha3Trait::get_last_input(ref to_hash, loaded, size);
            size %= 8;
        }

        let mut hash = cairo_keccak(ref to_hash, last_input, size);

        self.stack.push(u256_bytes_reverse(hash))
    }
}


#[generate_trait]
impl InternalSha3Methods of InternalSha3Trait {
    /// Return the last u64 chunk to hash, given a size, from an u256.
    /// This function is used to prepare inputs for keccak::cairo_keccak.
    ///
    /// This function will split a given u256 into little endian u64 and
    /// return the chunk containing the last bytes to hash while
    /// appending the chunks prior to this one.
    ///
    /// # Arguments
    ///
    /// * `to_hash` - A reference to the array containing previous bytes
    /// * `value` - The `u256` element to get the last u64 input from
    /// * `size` - The amonut of bytes to append to to_hash
    #[inline(always)]
    fn get_last_input(ref to_hash: Array<u64>, value: u256, size: u32) -> u64 {
        let ((high_h, low_h), (high_l, low_l)) = split_u256_into_u64_little(value);
        if size < 8 {
            return low_h;
        } else if size < 16 {
            to_hash.append(low_h);
            return high_h;
        } else if size < 24 {
            to_hash.append(low_h);
            to_hash.append(high_h);
            return low_h;
        } else {
            to_hash.append(low_h);
            to_hash.append(high_h);
            to_hash.append(low_l);
            return high_l;
        }
    }
}
