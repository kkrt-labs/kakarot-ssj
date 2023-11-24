//! SHA3.

use evm::errors::EVMError;
// Internal imports
use evm::machine::Machine;
use evm::memory::MemoryTrait;
use evm::stack::StackTrait;
use keccak::{cairo_keccak, u128_split};
use utils::helpers::{ArrayExtTrait, U256Trait};

#[generate_trait]
impl Sha3Impl of Sha3Trait {
    /// SHA3 operation : Hashes n bytes in memory at a given offset in memory
    /// and push the hash result to the stack.
    ///
    /// # Inputs
    /// * `offset` - The offset in memory where to read the data
    /// * `size` - The amount of bytes to read
    ///
    /// # Specification: https://www.evm.codes/#20?fork=shanghai
    fn exec_sha3(ref self: Machine) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_usize()?;
        let mut size: usize = self.stack.pop_usize()?;

        let mut to_hash: Array<u64> = Default::default();

        let (nb_words, nb_zeroes) = internal::compute_memory_words_amount(
            size, offset, self.memory.size()
        );
        let mut last_input_offset = internal::fill_array_with_memory_words(
            ref self, ref to_hash, offset, nb_words
        );
        // Fill array to hash with zeroes for bytes out of memory bound
        // which is faster than reading them from memory
        to_hash.append_n(0, 4 * nb_zeroes);

        // For cases where the size of bytes to hash isn't a multiple of 8,
        // prepare the last bytes to hash into last_input instead of appending
        // it to to_hash.
        let last_input: u64 = if (size % 32 != 0) {
            let loaded = self.memory.load(last_input_offset);
            internal::prepare_last_input(ref to_hash, loaded, size % 32)
        } else {
            0
        };
        // Properly set the memory length in case we skipped reading zeroes
        self.memory.ensure_length(size + offset);
        let mut hash = cairo_keccak(ref to_hash, last_input, size % 8);
        self.stack.push(hash.reverse_endianness())
    }
}


mod internal {
    use evm::machine::Machine;
    use evm::memory::MemoryTrait;
    use evm::stack::StackTrait;
    use utils::helpers::U256Trait;

    /// Computes how many words are read from the memory
    /// and how many words must be filled with zeroes
    /// given a target size, a memory offset and the length of the memory.
    ///
    /// # Arguments
    ///
    /// * `size` - The amount of bytes to hash
    /// * `offset` - Offset in memory
    /// * `mem_len` - Size of the memory
    /// Returns : (nb_words, nb_zeroes)
    fn compute_memory_words_amount(size: u32, offset: u32, mem_len: u32) -> (u32, u32) {
        // Bytes to hash are less than a word size
        if size < 32 {
            return (0, 0);
        }
        // Bytes out of memory bound are zeroes
        if offset > mem_len {
            return (0, size / 32);
        }
        // The only word to read from memory is less than 32 bytes
        if mem_len - offset < 32 {
            return (1, (size / 32) - 1);
        }

        let bytes_to_read = cmp::min(mem_len - offset, size);
        let nb_words = bytes_to_read / 32;
        (nb_words, (size / 32) - nb_words)
    }

    /// Fills the `to_hash` array with little endian u64s
    /// by splitting words read from the memory and
    /// returns the next offset to read from.
    ///
    /// # Arguments
    ///
    /// * `self` - The context in which the memory is read
    /// * `to_hash` - A reference to the array to fill
    /// * `offset` - Offset in memory to start reading from
    /// * `amount` - The amount of words to read from memory
    /// Return the new offset
    fn fill_array_with_memory_words(
        ref self: Machine, ref to_hash: Array<u64>, mut offset: u32, mut amount: u32
    ) -> u32 {
        loop {
            if amount == 0 {
                break;
            }
            let loaded = self.memory.load(offset);
            let ((high_h, low_h), (high_l, low_l)) = loaded.split_into_u64_le();
            to_hash.append(low_h);
            to_hash.append(high_h);
            to_hash.append(low_l);
            to_hash.append(high_l);

            offset += 32;
            amount -= 1;
        };
        offset
    }

    /// Fills the `to_hash` array with the n-1 remaining little endian u64
    /// depending on size from a word and returns
    /// the u64 containing the last 8 bytes word to hash.
    ///
    /// # Arguments
    ///
    /// * `to_hash` - A reference to the array to fill
    /// * `value` - The word to split in u64 words
    /// * `size` - The amount of bytes still required to hash
    /// Returns the last u64 word that isn't 8 Bytes long.
    fn prepare_last_input(ref to_hash: Array<u64>, value: u256, size: u32) -> u64 {
        let ((high_h, low_h), (high_l, low_l)) = value.split_into_u64_le();
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
