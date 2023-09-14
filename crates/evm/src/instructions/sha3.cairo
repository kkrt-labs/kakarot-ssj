//! SHA3.

// Internal imports
use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
use evm::stack::StackTrait;
use evm::memory::MemoryTrait;
use evm::errors::EVMError;
use evm::helpers::U256IntoResultU32;
use keccak::{cairo_keccak, u128_split};
use utils::helpers::{ArrayExtensionTrait, reverse_endianness};

use array::ArrayTrait;

#[generate_trait]
impl Sha3Impl of Sha3Trait {
    /// SHA3 operation : Hashes n bytes in memory at a given offset in memory
    /// and push the hash result to the stack.
    /// 
    /// # Inputs
    /// * `offset` - The offset in memory where to read the datas
    /// * `size` - The amount of bytes to read
    /// 
    /// # Specification: https://www.evm.codes/#20?fork=shanghai
    fn exec_sha3(ref self: ExecutionContext) -> Result<(), EVMError> {
        let mut offset: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let mut size: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;

        let mut to_hash: Array<u64> = Default::default();

        let (nb_chunks, nb_zeroes) = internal::compute_memory_chunks_amount(
            size, offset, self.memory.bytes_len
        );
        offset = internal::fill_array_with_memory_chunks(ref self, ref to_hash, offset, nb_chunks);
        to_hash.append_n(0, 4 * nb_zeroes);

        // Fill last_input with last bytes to hash
        let last_input: u64 = if (size % 32 != 0) {
            let loaded = self.memory.load(offset);
            internal::prepare_last_input(ref to_hash, loaded, size % 32)
        } else {
            0
        };

        let mut hash = cairo_keccak(ref to_hash, last_input, size % 8);
        self.stack.push(reverse_endianness(hash))
    }
}


mod internal {
    use evm::context::{ExecutionContext, ExecutionContextTrait, BoxDynamicExecutionContextDestruct};
    use evm::stack::StackTrait;
    use evm::memory::MemoryTrait;
    use utils::helpers::split_u256_into_u64_little;

    /// This function will compute how many chunks of 32 Bytes data are read
    /// from the memory and how many chunks of 32 Bytes data must be filled
    /// with zeroes.
    ///
    /// # Arguments
    ///
    /// * `size` - The amount of bytes to hash
    /// * `offset` - Offset in memory
    /// * `mem_len` - Size of the memory
    /// Returns : (nb_chunks, nb_zeroes)
    fn compute_memory_chunks_amount(size: u32, offset: u32, mem_len: u32) -> (u32, u32) {
        if offset > mem_len {
            return (0, size / 32);
        }
        if (mem_len - offset < 32) && (size > 32) {
            return (1, (size / 32) - 1);
        }
        let nb_chunks = (cmp::min(mem_len - offset, size)) / 32;
        (nb_chunks, (size / 32) - nb_chunks)
    }

    /// This function will fill an array with little endian u64
    /// by splitting 32 Bytes chunk read from the memory and
    /// returns the new offset.
    ///
    /// # Arguments
    ///
    /// * `self` - The context in which the memory is read
    /// * `to_hash` - A reference to the array to fill
    /// * `offset` - Offset in memory
    /// * `amount` - The amount of 32 Bytes chunks to read from memory
    /// Return the new offset
    fn fill_array_with_memory_chunks(
        ref self: ExecutionContext, ref to_hash: Array<u64>, mut offset: u32, mut amount: u32
    ) -> u32 {
        loop {
            if amount == 0 {
                break;
            }
            let loaded = self.memory.load(offset);
            let ((high_h, low_h), (high_l, low_l)) = split_u256_into_u64_little(loaded);
            to_hash.append(low_h);
            to_hash.append(high_h);
            to_hash.append(low_l);
            to_hash.append(high_l);

            offset += 32;
            amount -= 1;
        };
        offset
    }

    /// This function will fill an array with the remaining little endian u64 
    /// depending on size from a 32 Bytes chunk of data and return
    /// the u64 chunk containing the last bytes that aren't 8 Bytes long.
    ///
    /// # Arguments
    ///
    /// * `to_hash` - A reference to the array to fill
    /// * `value` - The 32 Bytes chunk to split and get the bytes from
    /// * `size` - The amount of bytes still required to hash
    /// Returns the last u64 chunk that isn't 8 Bytes long.
    fn prepare_last_input(ref to_hash: Array<u64>, value: u256, size: u32) -> u64 {
        let ((high_h, low_h), (high_l, low_l)) = split_u256_into_u64_little(value);
        if size < 8 {
            return low_h;
        } else if size < 16 {
            to_hash.append(low_h);
            return high_h;
        } else if size < 24 {
            to_hash.append(low_h);
            to_hash.append(high_h);
            return low_l;
        } else {
            to_hash.append(low_h);
            to_hash.append(high_h);
            to_hash.append(low_l);
            return high_l;
        }
    }
}
