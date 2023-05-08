use traits::Index;
use array::SpanTrait;
use array::ArrayTrait;
use clone::Clone;

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
    items: Felt252Dict<felt252>,
    bytes_len: usize,
}

trait Felt252DictExtension {
    fn store_u256(ref self: Felt252Dict<felt252>, element: u256, index: usize);
    fn read_u256(ref self: Felt252Dict<felt252>, index: usize) -> u256;
}

impl Felt252DictExtensionImpl of Felt252DictExtension {
    fn store_u256(ref self: Felt252Dict<felt252>, element: u256, index: usize) {
        let index: felt252 = index.into();
        self.insert(index, element.low.into());
        self.insert(index + 1, element.high.into());
    }

    fn read_u256(ref self: Felt252Dict<felt252>, index: usize) -> u256 {
        let index: felt252 = index.into();
        let high: felt252 = self.get(index);
        let low: felt252 = self.get(index + 1);
        u256 { low: low.try_into().unwrap(), high: high.try_into().unwrap() }
    }
}

trait PrintTraitCustom<T> {
    fn print_mem(ref self: T, begin: usize, end: usize);
}

impl MemoryPrintImpl of PrintTraitCustom<Memory> {
    fn print_mem(ref self: Memory, mut begin: usize, end: usize) {
        '____MEMORY_BEGIN___'.print();
        loop {
            if begin == end {
                break ();
            }
            self.items.get(begin.into()).print();
            begin += 1;
        };
        '____MEMORY_END___'.print();
    }
}

trait MemoryTrait {
    fn new() -> Memory;
    fn store(ref self: Memory, element: u256, offset: usize);
    fn store_n(ref self: Memory, elements: Span<u8>, offset: usize);
    fn store_aligned_words(
        ref self: Memory, chunk_index: usize, chunk_index_f: usize, elements: Span<u8>
    );
    fn _load(ref self: Memory, offset: usize) -> u256;
    fn _load_n(ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize);
    fn load_aligned_words(
        ref self: Memory, chunk_index: usize, chunk_index_f: usize, ref elements: Array<u8>
    );
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
        let w0: felt252 = self.items.get(chunk_index.into());
        let w2: felt252 = self.items.get(chunk_index.into() + 2);

        // Compute the new words
        let w0_h: u256 = (w0.into() / mask);
        let w2_l: u256 = (w2.into() / mask);

        // We can convert them back to felt252 as we know they fit in one word.
        let new_w0: felt252 = (w0_h.into() * mask + el_hh).try_into().unwrap();
        let new_w1: felt252 = (el_hl.into() * mask + el_lh).try_into().unwrap();
        let new_w2: felt252 = (el_ll.into() * mask + w2_l).try_into().unwrap();

        // Write the new words
        self.items.insert(chunk_index.into(), new_w0);
        self.items.insert(chunk_index.into() + 1, new_w1);
        self.items.insert(chunk_index.into() + 2, new_w2);
    }

    fn store_n(ref self: Memory, elements: Span<u8>, offset: usize) {
        if elements.len() == 0 {
            return ();
        }

        // Compute new bytes_len.
        let new_min_bytes_len = helpers::ceil_bytes_len_to_next_32_bytes_word(
            offset + elements.len()
        );
        let new_bytes_len = if new_min_bytes_len > self.bytes_len {
            new_min_bytes_len
        } else {
            self.bytes_len
        };
        self.bytes_len = new_bytes_len;

        // Check alignment of offset to 16B chunks.
        let (chunk_index_i, offset_in_chunk_i) = u32_safe_divmod(offset, u32_as_non_zero(16));
        let (chunk_index_f, offset_in_chunk_f) = u32_safe_divmod(
            offset + elements.len() - 1, u32_as_non_zero(16)
        );
        let offset_in_chunk_f = offset_in_chunk_f + 1;
        let mask_i: u256 = helpers::pow256_rev(offset_in_chunk_i);
        let mask_f: u256 = helpers::pow256_rev(offset_in_chunk_f);

        // Special case: within the same word.
        if chunk_index_i == chunk_index_f {
            let w: u128 = self.items.get(offset_in_chunk_i.into()).try_into().unwrap();
            let (w_h, w_l) = u256_safe_divmod(u256 { low: w, high: 0 }, u256_as_non_zero(mask_i));
            let (_, w_ll) = u256_safe_divmod(w_l, u256_as_non_zero(mask_f));
            let x = helpers::load_word(elements.len(), elements);
            let new_w: felt252 = (w_h * mask_i + x.into() * mask_f + w_ll).try_into().unwrap();
            self.items.insert(chunk_index_i.into(), new_w);
            return ();
        }

        // Otherwise, fill first word.
        let w_i = self.items.get(chunk_index_i.into());
        let w_i_h = (w_i.into() / mask_i);
        let x_i = helpers::load_word(16 - offset_in_chunk_i, elements);
        let w1: felt252 = (w_i_h * mask_i + x_i.into()).try_into().unwrap();
        self.items.insert(chunk_index_i.into(), w1);

        // Fill last word
        let w_f = self.items.get(chunk_index_f.into());
        //TODO(eni) might need to use a special div_rem for 2*128 here.
        let w_f_l = (w_f.into() % mask_f);
        let mut elements_clone = elements.clone();
        elements_clone.pop_front_n(elements.len() - offset_in_chunk_f);
        let x_f = helpers::load_word(offset_in_chunk_f, elements_clone);
        let w2: felt252 = (x_f.into() * mask_f + w_f_l).try_into().unwrap();
        self.items.insert(chunk_index_f.into(), w2);

        // Write blocks
        let mut elements_clone = elements.clone();
        elements_clone.pop_front_n(elements.len() + 15 - offset_in_chunk_i);
        self.store_aligned_words(chunk_index_i + 1, chunk_index_f, elements_clone);
    }

    fn store_aligned_words(
        ref self: Memory, mut chunk_index: usize, chunk_index_f: usize, mut elements: Span<u8>
    ) {
        loop {
            if chunk_index == chunk_index_f {
                break ();
            }

            let current: felt252 = ((*elements[0]).into() * utils::pow(256, 15)
                + (*elements[1]).into() * utils::pow(256, 14)
                + (*elements[2]).into() * utils::pow(256, 13)
                + (*elements[3]).into() * utils::pow(256, 12)
                + (*elements[4]).into() * utils::pow(256, 11)
                + (*elements[5]).into() * utils::pow(256, 10)
                + (*elements[6]).into() * utils::pow(256, 9)
                + (*elements[7]).into() * utils::pow(256, 8)
                + (*elements[8]).into() * utils::pow(256, 7)
                + (*elements[9]).into() * utils::pow(256, 6)
                + (*elements[10]).into() * utils::pow(256, 5)
                + (*elements[11]).into() * utils::pow(256, 4)
                + (*elements[12]).into() * utils::pow(256, 3)
                + (*elements[13]).into() * utils::pow(256, 2)
                + (*elements[14]).into() * utils::pow(256, 1)
                + (*elements[15]).into() * utils::pow(256, 0));

            self.items.insert(chunk_index.into(), current);
            chunk_index += 1;
            elements.pop_front_n(16);
        }
    }

    fn _load(ref self: Memory, offset: usize) -> u256 {
        let (chunk_index, offset_in_chunk) = u32_safe_divmod(offset, u32_as_non_zero(16));

        if offset == 0 { // Offset is aligned. This is the simplest and most efficient case,
            // so we optimize for it. Note that no locals were allocated at all.
            return self.items.read_u256(chunk_index);
        }
        // Offset is misaligned.
        // |   W0   |   W1   |   w2   |
        //     |  EL_H  |  EL_L  |
        //      ^---^
        //         |-- mask = 256 ** offset_in_chunk

        // Compute mask.

        let mask: u256 = helpers::pow256_rev(offset_in_chunk);
        let mask_c: u256 = utils::pow(2, 128).into() / mask;

        // Read the words at chunk_index, +1, +2.
        let w0: felt252 = self.items.get(chunk_index.into());
        let w1: felt252 = self.items.get(chunk_index.into() + 1);
        let w2: felt252 = self.items.get(chunk_index.into() + 2);

        // Compute element words
        let w0_l: u256 = w0.into() % mask;
        let (w1_h, w1_l): (u256, u256) = u256_safe_divmod(w1.into(), u256_as_non_zero(mask));
        let w2_h: u256 = w2.into() / mask;
        let el_h: u128 = (w0_l * mask_c + w1_h).try_into().unwrap();
        let el_l: u128 = (w1_l * mask_c + w2_h).try_into().unwrap();

        return u256 { low: el_l, high: el_h };
    }

    fn _load_n(ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize) {
        if elements.len() == 0 {
            return ();
        }

        // Check alignment of offset to 16B chunks.
        let (chunk_index_i, offset_in_chunk_i) = u32_safe_divmod(offset, u32_as_non_zero(16));
        let (chunk_index_f, mut offset_in_chunk_f) = u32_safe_divmod(
            offset + elements_len - 1, u32_as_non_zero(16)
        );
        offset_in_chunk_f += 1;
        let mask_i: u256 = helpers::pow256_rev(offset_in_chunk_i);
        let mask_f: u256 = helpers::pow256_rev(offset_in_chunk_f);

        // Special case: within the same word.
        if chunk_index_i == chunk_index_f {
            let w: felt252 = self.items.get(chunk_index_i.into());
            //TODO(eni) special div_rem function here
            let w_l = w.into() % mask_i;
            let w_lh = w_l / mask_f;
            helpers::split_word(w_lh, elements_len, ref elements)
        }

        // Otherwise.
        // Get first word.
        // Otherwise, fill first word.
        let w_i = self.items.get(chunk_index_i.into());
        let w_i_l = (w_i.into() % mask_i);
        let elements_first_word = helpers::split_word(w_i_l, 16 - offset_in_chunk_i, ref elements);

        // Get blocks.
        self.load_aligned_words(chunk_index_i + 1, chunk_index_f, ref elements);

        // Get last word.
        let w_f = self.items.get(chunk_index_f.into());
        let w_f_h = w_f.into() / mask_f;
        let elements_last_word = helpers::split_word(w_f_h, offset_in_chunk_f, ref elements);
    }

    fn load_aligned_words(
        ref self: Memory, mut chunk_index: usize, chunk_index_f: usize, ref elements: Array<u8>
    ) {
        loop {
            if chunk_index == chunk_index_f {
                break ();
            }
            let value = self.items.get(chunk_index.into());
            // Pushes 16 items to `elements`
            helpers::split_word_128(value.into(), ref elements);
            chunk_index += 1;
        }
    }
}

trait SpanExtensionTrait<T> {
    fn pop_front_n(ref self: Span<T>, n: usize);
}

impl SpanExtenstionImpl<T> of SpanExtensionTrait<T> {
    fn pop_front_n(ref self: Span<T>, mut n: usize) {
        loop {
            if n == 0 {
                break ();
            }
            self.pop_front();
            n = n - 1;
        };
    }
}

//TODO(eni) make PR and add this in corelib
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
