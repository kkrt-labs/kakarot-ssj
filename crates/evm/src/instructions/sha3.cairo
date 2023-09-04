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
        let offset: u32 = Into::<u256, Result<u32, EVMError>>::into((self.stack.pop()?))?;
        let mut size: u64 = Into::<u256, Result<u64, EVMError>>::into((self.stack.pop()?))?;

        // let mut toHash: Array<u8> = ArrayTrait::<u8>::new();
        // let mut counter = 0;
        // if size == 32 {
        //     let mut mem = self.memory.load_internal(offset+(32*counter));
        //     let toHash: Bytes = u256_to_bytes_array(mem).span();

        //     let mut hash = KeccakTrait::keccak_cairo(toHash);
        //     hash.low = integer::u128_byte_reverse(hash.low);
        //     hash.high = integer::u128_byte_reverse(hash.high);
        //     let tmp = hash.low;
        //     hash.low = hash.high;
        //     hash.high = tmp;

        //     return self.stack.push(hash);

        // }

        // loop {
        //     if size < 32 {
        //         break;
        //     }

        //     let mut mem = self.memory.load_internal(offset+(32*counter));
        //     let memu8: Bytes = u256_to_bytes_array(mem).span();

        //     let mut i = 0;
        //     loop {
        //         if i == 32 {
        //             break;
        //         }

        //         toHash.append(*memu8[i]);
        //         i+=1;
        //     };

        //     counter += 1;
        //     size -= 32;
        //  };
        // if size > 0 {
        //     let mut mem = self.memory.load_internal(offset+(32*counter));
        //     let memu8: Bytes = u256_to_bytes_array(mem).span();
        //     let mut i = size;
        //     loop {
        //         if i == 0 {
        //             break;
        //         }

        //         toHash.append(*memu8[size-i]);
        //         i-=1;
        //     };
        // }

        // let mut hash = KeccakTrait::keccak_cairo(toHash.span());
        // hash.low = integer::u128_byte_reverse(hash.low);
        // hash.high = integer::u128_byte_reverse(hash.high);
        // let tmp = hash.low;
        // hash.low = hash.high;
        // hash.high = tmp;

        // self.stack.push(hash)

        let mut toHash: Array<u64> = ArrayTrait::<u64>::new();
        let mut last_input: u64 = 0;
        let mut counter = 0;
        loop {
            if size < 32 {
                break;
            }

            let mut mem = self.memory.load_internal(offset + (32 * counter));
            mem.low = integer::u128_byte_reverse(mem.low);
            mem.high = integer::u128_byte_reverse(mem.high);
            let tmp = mem.low;
            mem.low = mem.high;
            mem.high = tmp;

            let (highL, lowL) = u128_split(mem.low);
            let (highH, lowH) = u128_split(mem.high);
            toHash.append(lowL);
            toHash.append(highL);
            toHash.append(lowH);
            toHash.append(highH);

            counter += 1;
            size -= 32;
        };
        if size > 0 {
            let mut mem = self.memory.load_internal(offset + (32 * counter));
            mem.low = integer::u128_byte_reverse(mem.low);
            mem.high = integer::u128_byte_reverse(mem.high);
            let tmp = mem.low;
            mem.low = mem.high;
            mem.high = tmp;
            let (highL, lowL) = u128_split(mem.low);
            let (highH, lowH) = u128_split(mem.high);

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

        let mut hash = cairo_keccak(
            ref toHash, last_input, Into::<u64, Result<u32, EVMError>>::into((size))?
        );
        hash.low = integer::u128_byte_reverse(hash.low);
        hash.high = integer::u128_byte_reverse(hash.high);
        let tmp = hash.low;
        hash.low = hash.high;
        hash.high = tmp;

        self.stack.push(hash)
    }
}
