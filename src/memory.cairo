use array::ArrayTrait;
use dict::Felt252Dict;
use dict::Felt252DictTrait;
use integer::{
    u32_safe_divmod, u32_as_non_zero, u128_safe_divmod, u128_as_non_zero, u256_safe_divmod,
    u256_as_non_zero
};
use traits::{TryInto, Into};
use kakarot::{utils, utils::helpers};
use option::OptionTrait;
use debug::PrintTrait;


#[derive(Destruct)]
struct Memory {
    items: Felt252Dict<u128>,
    bytes_len: usize,
}

trait Felt252DictExtension {
    fn store_u256(ref self: Felt252Dict<u128>, element: u256, index: usize);
}

impl Felt252DictExtensionImpl of Felt252DictExtension {
    fn store_u256(ref self: Felt252Dict<u128>, element: u256, index: usize) {
        let index: felt252 = index.into();
        self.insert(index, element.low);
        self.insert(index + 1, element.high);
    }
}

trait MemoryTrait {
    fn new() -> Memory;
    fn store(ref self: Memory, element: u256, offset: usize);
}

impl MemoryImpl of MemoryTrait {
    /// Initializes a new `Memory` instance.
    ///
    /// # Returns
    ///
    /// * A new `Memory` instance.
    fn new() -> Memory {
        Memory { items: Felt252DictTrait::new(), bytes_len: 0,  }
    }

    /// Stores an element into the memory.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance.
    /// * `element` - The element to store, of type `u256`.
    /// * `offset` - The `usize` offset at which to store the element.
    fn store(ref self: Memory, element: u256, offset: usize) {
        let new_min_bytes_len = helpers::ceil_bytes_len_to_next_32_bytes_word(offset + 32);

        let new_bytes_len = if new_min_bytes_len > self.bytes_len {
            new_min_bytes_len
        } else {
            self.bytes_len
        };
        self.bytes_len = new_bytes_len;

        // Check alignment of offset to 16B chunks
        let (chunk_index, offset_in_chunk) = u32_safe_divmod(offset, u32_as_non_zero(16));

        if offset_in_chunk == 0 {
            // Offset is aligned. This is the simplest and most efficient case,
            // so we optimize for it.
            self.items.store_u256(element, chunk_index);
            return ();
        }

        // Offset is misaligned.
        // |   W0   |   W1   |   w2   |
        //     |  EL_H  |  EL_L  |
        // ^---^
        //   |-- mask = 256 ** offset_in_chunk

        let mask: u256 = helpers::pow256_rev(offset_in_chunk);
        let mask_c: u256 = utils::pow(2, 128).into() / mask;

        // Split the 2 input 16B chunks at offset_in_chunk.

        let (el_hh, el_hl) = u256_safe_divmod(
            u256 { low: element.high, high: 0 }, u256_as_non_zero(mask_c)
        );

        let (el_lh, el_ll) = u256_safe_divmod(
            u256 { low: element.low, high: 0 }, u256_as_non_zero(mask_c)
        );

        // Read the words at chunk_index, chunk_index + 2.
        let w0: u128 = self.items.get(chunk_index.into());
        let w2: u128 = self.items.get(chunk_index.into() + 2);

        // Compute the new words
        let w0_h: u256 = (w0.into() / mask);
        let w2_l: u256 = (w2.into() / mask);

        // We can convert them back to u128 as we know they fit in one word.
        let new_w0: u128 = (w0_h.into() * mask + el_hh).try_into().unwrap();
        let new_w1: u128 = (el_hl.into() * mask + el_lh).try_into().unwrap();
        let new_w2: u128 = (el_ll.into() * mask + w2_l).try_into().unwrap();

        // Write the new words
        self.items.insert(chunk_index.into(), new_w0);
        self.items.insert(chunk_index.into() + 1, new_w1);
        self.items.insert(chunk_index.into() + 2, new_w2);
    }
}

//TODO make PR and add this in corelib
impl U128IntoU256 of Into<u128, u256> {
    fn into(self: u128) -> u256 {
        u256 { low: self, high: 0 }
    }
}

impl U32IntoU256 of Into<u32, u256> {
    fn into(self: u32) -> u256 {
        u256 { low: self.into(), high: 0 }
    }
}

impl U256TryIntoU128 of TryInto<u256, u128> {
    fn try_into(self: u256) -> Option<u128> {
        if self.high != 0 {
            return Option::None(());
        }
        Option::Some(self.low)
    }
}
