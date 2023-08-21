use traits::Index;
use array::SpanTrait;
use array::ArrayTrait;
use clone::Clone;
use dict::Felt252Dict;
use dict::Felt252DictTrait;
use integer::{
    u32_safe_divmod, u32_as_non_zero, u128_safe_divmod, u128_as_non_zero, u256_safe_div_rem,
    u256_as_non_zero
};
use cmp::{max};
use traits::{TryInto, Into};
use kakarot::{utils, utils::helpers, utils::math::Exponentiation};
use option::OptionTrait;
use debug::PrintTrait;


#[derive(Destruct)]
struct Memory {
    items: Felt252Dict<u128>,
    bytes_len: usize,
}

trait MemoryTrait {
    fn new() -> Memory;
    fn store(ref self: Memory, element: u256, offset: usize);
    fn store_n(ref self: Memory, elements: Span<u8>, offset: usize);
    fn ensure_length(ref self: Memory, length: usize) -> usize;
    fn load(ref self: Memory, offset: usize) -> (u256, usize);
    fn load_n(
        ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize
    ) -> usize;
}

impl MemoryImpl of MemoryTrait {
    /// Initializes a new `Memory` instance.
    fn new() -> Memory {
        Memory { items: Default::default(), bytes_len: 0, }
    }

    /// Stores a 32-bytes element into the memory.
    ///
    /// If the offset is aligned with the 16-bytes words in memory, the element is stored directly.
    /// Otherwise, the element is split and stored in multiple words.
    fn store(ref self: Memory, element: u256, offset: usize) {
        let new_min_bytes_len = helpers::ceil_bytes_len_to_next_32_bytes_word(offset + 32);

        self.bytes_len = cmp::max(new_min_bytes_len, self.bytes_len);

        // Check alignment of offset to bytes16 chunks
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
        // |-- mask = 256 ** offset_in_chunk

        self.store_element(element, chunk_index, offset_in_chunk);
    }

    /// Stores a span of N bytes into memory at a specified offset.
    ///
    /// This function checks the alignment of the offset to 16-byte chunks, and handles the special case where the bytes to be
    /// stored are within the same word in memory using the `store_bytes_in_single_chunk` function. If the bytes
    /// span multiple words, the function stores the first word using the `store_first_word` function, the aligned
    /// words using the `store_aligned_words` function, and the last word using the `store_last_word` function.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance to store the bytes in.
    /// * `elements` - A span of bytes to store in memory.
    /// * `offset` - The offset within memory to store the bytes at.
    fn store_n(ref self: Memory, elements: Span<u8>, offset: usize) {
        if elements.len() == 0 {
            return ();
        }

        // Compute new bytes_len.
        let new_min_bytes_len = helpers::ceil_bytes_len_to_next_32_bytes_word(
            offset + elements.len()
        );
        self.bytes_len = cmp::max(new_min_bytes_len, self.bytes_len);

        // Check alignment of offset to bytes16 chunks.
        let (initial_chunk, offset_in_chunk_i) = u32_safe_divmod(offset, u32_as_non_zero(16));
        let (final_chunk, mut offset_in_chunk_f) = u32_safe_divmod(
            offset + elements.len() - 1, u32_as_non_zero(16)
        );
        offset_in_chunk_f += 1;
        let mask_i: u256 = helpers::pow256_rev(offset_in_chunk_i);
        let mask_f: u256 = helpers::pow256_rev(offset_in_chunk_f);

        // Special case: the bytes are stored within the same word.
        if initial_chunk == final_chunk {
            self.store_bytes_in_single_chunk(initial_chunk, mask_i, mask_f, elements);
            return ();
        }

        // Otherwise, fill first word.
        self.store_first_word(initial_chunk, offset_in_chunk_i, mask_i, elements);

        // Store aligned bytes in [initial_chunk + 1, final_chunk - 1].
        let aligned_bytes = elements
            .slice(
                16 - offset_in_chunk_i, elements.len() - 16 - offset_in_chunk_i - offset_in_chunk_f,
            );
        self.store_aligned_words(initial_chunk + 1, aligned_bytes);

        let final_bytes = elements.slice(elements.len() - offset_in_chunk_f, offset_in_chunk_f);
        self.store_last_word(final_chunk, offset_in_chunk_f, mask_f, final_bytes);
    }


    /// Ensures that the memory is at least `length` bytes long. Expands if necessary.
    /// # Returns
    /// The gas cost of expanding the memory.
    fn ensure_length(ref self: Memory, length: usize) -> usize {
        if self.bytes_len < length {
            let cost = self.expand(length - self.bytes_len);
            return cost;
        } else {
            return 0;
        }
    }

    /// Expands memory if necessary, then load 32 bytes from it at the given offset.
    /// # Returns
    /// * `u256` - The loaded value.
    /// * `usize` - The gas cost of expanding the memory.
    fn load(ref self: Memory, offset: usize) -> (u256, usize) {
        let gas_cost = self.ensure_length(32 + offset);
        let loaded_element = self.load_internal(offset);
        (loaded_element, gas_cost)
    }

    /// Expands memory if necessary, then load elements_len bytes from the memory at given offset inside elements.
    /// # Returns
    /// * `usize` - The gas cost of expanding the memory.
    fn load_n(
        ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize
    ) -> usize {
        let gas_cost = self.ensure_length(elements_len + offset);
        self.load_n_internal(elements_len, ref elements, offset);
        gas_cost
    }
}

#[generate_trait]
impl InternalMemoryMethods of InternalMemoryTrait {
    /// Stores a `u256` element at a specified offset within a memory chunk.
    ///
    /// It first computes the
    /// masks for the high and low parts of the element, then splits the `u256` element into high and low
    /// parts, and computes the new words to write to memory using the masks and the high and low parts
    /// of the element. Finally, it writes the new words to memory.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the element in.
    /// * `element` - The `u256` element to store in memory.
    /// * `chunk_index` - The index of the memory chunk to start storing the element in.
    /// * `offset_in_chunk` - The offset within the memory chunk to store the element at.
    fn store_element(ref self: Memory, element: u256, chunk_index: usize, offset_in_chunk: u32) {
        let mask: u256 = helpers::pow256_rev(offset_in_chunk);
        let mask_c: u256 = 256.pow(16).into() / mask;

        // Split the 2 input bytes16 chunks at offset_in_chunk.
        let (el_hh, el_hl) = u256_safe_div_rem(element.high.into(), u256_as_non_zero(mask_c));
        let (el_lh, el_ll) = u256_safe_div_rem(element.low.into(), u256_as_non_zero(mask_c));

        // Read the words at chunk_index, chunk_index + 2.
        let w0: u128 = self.items.get(chunk_index.into());
        let w2: u128 = self.items.get(chunk_index.into() + 2);

        // Compute the new words
        let w0_h: u256 = (w0.into() / mask);
        let w2_l: u256 = (w2.into() / mask);

        // We can convert them back to felt252 as we know they fit in one word.
        let new_w0: u128 = (w0_h.into() * mask + el_hh).try_into().unwrap();
        let new_w1: u128 = (el_hl.into() * mask + el_lh).try_into().unwrap();
        let new_w2: u128 = (el_ll.into() * mask + w2_l).try_into().unwrap();

        // Write the new words
        self.items.insert(chunk_index.into(), new_w0);
        self.items.insert(chunk_index.into() + 1, new_w1);
        self.items.insert(chunk_index.into() + 2, new_w2);
    }

    /// Stores a span of bytes into a single memory chunk.
    ///
    /// This function computes new word to be stored by multiplying the
    /// high part of the current word by the `mask_i` value, adding the loaded bytes multiplied by the `mask_f`
    /// value, and adding the low part of the current word.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the bytes in.
    /// * `initial_chunk` - The index of the initial memory chunk to store the bytes in.
    /// * `mask_i` - The mask for the high part of the word.
    /// * `mask_f` - The mask for the low part of the word.
    /// * `elements` - A span of bytes to store in memory.
    fn store_bytes_in_single_chunk(
        ref self: Memory, initial_chunk: usize, mask_i: u256, mask_f: u256, elements: Span<u8>
    ) {
        let word: u128 = self.items.get(initial_chunk.into());
        let (word_high, word_low) = u256_safe_div_rem(word.into(), u256_as_non_zero(mask_i));
        let (_, word_low_l) = u256_safe_div_rem(word_low, u256_as_non_zero(mask_f));
        let bytes_as_word = helpers::load_word(elements.len(), elements);
        let new_w: u128 = (word_high * mask_i + bytes_as_word.into() * mask_f + word_low_l)
            .try_into()
            .unwrap();
        self.items.insert(initial_chunk.into(), new_w);
    }

    /// Stores a sequence of bytes into memory in chunks of 16 bytes each.
    ///
    /// It combines each byte in the span into a single 16-byte value in big-endian order,
    /// and stores this value in memory. The function then updates
    /// the chunk index and slices the byte span to the next 16 bytes until all chunks have been stored.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance to store the bytes in.
    /// * `chunk_index` - The index of the chunk to start storing at.
    /// * `elements` - A span of bytes to store in memory.
    fn store_aligned_words(ref self: Memory, mut chunk_index: usize, mut elements: Span<u8>) {
        loop {
            if elements.len() == 0 {
                break ();
            }

            let current: felt252 = ((*elements[0]).into() * 256.pow(15)
                + (*elements[1]).into() * 256.pow(14)
                + (*elements[2]).into() * 256.pow(13)
                + (*elements[3]).into() * 256.pow(12)
                + (*elements[4]).into() * 256.pow(11)
                + (*elements[5]).into() * 256.pow(10)
                + (*elements[6]).into() * 256.pow(9)
                + (*elements[7]).into() * 256.pow(8)
                + (*elements[8]).into() * 256.pow(7)
                + (*elements[9]).into() * 256.pow(6)
                + (*elements[10]).into() * 256.pow(5)
                + (*elements[11]).into() * 256.pow(4)
                + (*elements[12]).into() * 256.pow(3)
                + (*elements[13]).into() * 256.pow(2)
                + (*elements[14]).into() * 256.pow(1)
                + (*elements[15]).into() * 256.pow(0));

            self.items.insert(chunk_index.into(), current.try_into().unwrap());
            chunk_index += 1;
            elements = elements.slice(0, 16);
        }
    }

    /// Retrieves aligned values from the memory structure, converts them back into a bytes array, and appends them
    /// to the `elements` array.
    ///
    /// It iterates
    /// over the chunks between the first and last chunk indices, retrieves the `u128` values from the memory chunk,
    /// and splits them into big-endian byte arrays and concatenates using the `split_word_128` function.
    /// The results are concatenated to the `elements` array.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to load the values from.
    /// * `chunk_index` - The index of the first chunk to load from.
    /// * `final_chunk` - The index of the last chunk to load from.
    /// * `elements` - A reference to the byte array to append the loaded bytes to.
    fn load_aligned_words(
        ref self: Memory, mut chunk_index: usize, final_chunk: usize, ref elements: Array<u8>
    ) {
        loop {
            if chunk_index == final_chunk {
                break ();
            }
            let value = self.items.get(chunk_index.into());
            // Pushes 16 items to `elements`
            helpers::split_word_128(value.into(), ref elements);
            chunk_index += 1;
        }
    }

    /// Loads a `u256` element from the memory chunk at a specified offset.
    ///
    /// If the offset is aligned with the memory words, the function returns the `u256` element at the
    /// specified offset directly from the memory chunk. If the offset is misaligned, the function computes the masks
    /// for the high and low parts of the first and last words of the `u256` element, reads the words at the specified
    /// offset and the next two offsets, and computes the high and low parts of the `u256` element using the masks and
    /// the read words. The resulting `u256` element is then returned.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to load the element from.
    /// * `offset` - The offset within the memory chunk to load the element from.
    ///
    /// # Returns
    ///
    /// The `u256` element at the specified offset in the memory chunk.
    fn load_internal(ref self: Memory, offset: usize) -> u256 {
        let (chunk_index, offset_in_chunk) = u32_safe_divmod(offset, u32_as_non_zero(16));

        if offset == 0 {
            // Offset is aligned. This is the simplest and most efficient case,
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
        let mask_c: u256 = 2.pow(128).into() / mask;

        // Read the words at chunk_index, +1, +2.
        let w0: u128 = self.items.get(chunk_index.into());
        let w1: u128 = self.items.get(chunk_index.into() + 1);
        let w2: u128 = self.items.get(chunk_index.into() + 2);

        // Compute element words
        let w0_l: u256 = w0.into() % mask;
        let (w1_h, w1_l): (u256, u256) = u256_safe_div_rem(w1.into(), u256_as_non_zero(mask));
        let w2_h: u256 = w2.into() / mask;
        let el_h: u128 = (w0_l * mask_c + w1_h).try_into().unwrap();
        let el_l: u128 = (w1_l * mask_c + w2_h).try_into().unwrap();

        return u256 { low: el_l, high: el_h };
    }

    /// Loads a span of bytes from the memory chunk at a specified offset.
    ///
    /// This function loads the n bytes from the memory chunks, and splits the first word,
    /// the aligned words, and the last word into bytes using the masks, and stored in
    /// the parameter `elements` array.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to load the bytes from.
    /// * `elements_len` - The length of the array of bytes to load.
    /// * `elements` - A reference to the array of bytes to load.
    /// * `offset` - The chunk memory offset to load the bytes from.
    fn load_n_internal(
        ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize
    ) {
        if elements_len == 0 {
            return ();
        }

        // Check alignment of offset to bytes16 chunks.
        let (initial_chunk, offset_in_chunk_i) = u32_safe_divmod(offset, u32_as_non_zero(16));
        let (final_chunk, mut offset_in_chunk_f) = u32_safe_divmod(
            offset + elements_len - 1, u32_as_non_zero(16)
        );
        offset_in_chunk_f += 1;
        let mask_i: u256 = helpers::pow256_rev(offset_in_chunk_i);
        let mask_f: u256 = helpers::pow256_rev(offset_in_chunk_f);

        // Special case: within the same word.
        if initial_chunk == final_chunk {
            let w: u128 = self.items.get(initial_chunk.into());
            let w_l = w.into() % mask_i;
            let w_lh = w_l / mask_f;
            helpers::split_word(w_lh, elements_len, ref elements)
        }

        // Otherwise.
        // Get first word.
        let w_i = self.items.get(initial_chunk.into());
        let w_i_l = (w_i.into() % mask_i);
        let elements_first_word = helpers::split_word(w_i_l, 16 - offset_in_chunk_i, ref elements);

        // Get blocks.
        self.load_aligned_words(initial_chunk + 1, final_chunk, ref elements);

        // Get last word.
        let w_f = self.items.get(final_chunk.into());
        let w_f_h = w_f.into() / mask_f;
        let elements_last_word = helpers::split_word(w_f_h, offset_in_chunk_f, ref elements);
    }


    /// Expands the memory by a specified length and returns the cost of the expansion.
    ///
    /// The cost of the expansion is the difference in cost between the old memory size and the
    /// new memory size.
    /// The function updates the `bytes_len` field of the `Memory` instance to reflect the new size of the memory
    /// chunk, and returns the cost of the expansion.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to expand.
    /// * `length` - The length to expand the memory chunk by.
    ///
    /// # Returns
    ///
    /// The cost of the expansion.
    fn expand(ref self: Memory, length: usize) -> usize {
        let last_memory_size_word = (self.bytes_len + 31) / 32;
        let mut last_memory_cost = (last_memory_size_word * last_memory_size_word) / 512;
        last_memory_cost += (3 * last_memory_size_word);

        let new_bytes_len = self.bytes_len + length;
        let new_memory_size_word = (new_bytes_len + 31) / 32;
        let new_memory_cost = (new_memory_size_word * new_memory_size_word) / 512;
        let new_memory_cost = new_memory_cost + (3 * new_memory_size_word);

        let cost = new_memory_cost - last_memory_cost;

        // Update memory size.
        self.bytes_len = new_bytes_len;

        cost
    }


    /// Stores the first word of a span of bytes in the memory chunk at a specified offset.
    /// The function computes the high part of the word by dividing the current word at the specified offset
    /// by the mask, and computes the low part of the word by loading the remaining bytes from the span of bytes. It
    /// then combines the high and low parts of the word using the mask and stores the resulting word in the memory
    /// chunk at the specified offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the word in.
    /// * `chunk_index` - The index of the memory chunk to store the word in.
    /// * `start_offset_in_chunk` - The offset within the chunk to store the word at.
    /// * `start_mask` - The mask for the high part of the word.
    /// * `elements` - A span of bytes to store.
    ///
    /// # Panics
    ///
    /// This function panics if the resulting word cannot be converted to a `u128` - which should never happen.
    fn store_first_word(
        ref self: Memory,
        chunk_index: usize,
        start_offset_in_chunk: usize,
        start_mask: u256,
        elements: Span<u8>
    ) {
        let word = self.items.get(chunk_index.into());
        let word_high = (word.into() / start_mask);
        let word_low = helpers::load_word(16 - start_offset_in_chunk, elements);
        let new_word: u128 = (word_high * start_mask + word_low.into()).try_into().unwrap();
        self.items.insert(chunk_index.into(), new_word);
    }

    /// Stores the last word of a span of bytes in the memory chunk at a specified offset.
    /// The function computes the low part of the word by taking the current word at the specified offset modulo the mask,
    /// and computes the high part of the word by loading the remaining bytes from the span of bytes. It then combines
    /// the high and low parts of the word using the mask and stores the resulting word in the memory chunk at the
    /// specified offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the word in.
    /// * `chunk_index` - The index of the memory chunk to store the word in.
    /// * `end_offset_in_chunk` - The offset within the chunk to store the word at.
    /// * `end_mask` - The mask for the low part of the word.
    /// * `elements` - A span of bytes to store.
    ///
    /// # Panics
    ///
    /// This function panics if the resulting word cannot be converted to a `u128` - which should never happen.
    fn store_last_word(
        ref self: Memory,
        chunk_index: usize,
        end_offset_in_chunk: usize,
        end_mask: u256,
        elements: Span<u8>
    ) {
        let word = self.items.get(chunk_index.into());
        let word_low = (word.into() % end_mask);

        let low_bytes = helpers::load_word(end_offset_in_chunk, elements);
        let new_word: u128 = (low_bytes.into() * end_mask + word_low).try_into().unwrap();
        self.items.insert(chunk_index.into(), new_word);
    }
}

#[generate_trait]
impl Felt252DictExtensionImpl of Felt252DictExtension {
    /// Stores a u256 element into the dictionary.
    /// The element will be stored as two distinct u128 elements,
    /// thus taking two indexes.
    ///
    /// # Arguments
    /// * `self` - A mutable reference to the `Felt252Dict` instance.
    /// * `element` - The element to store, of type `u256`.
    /// * `index` - The `usize` index at which to store the element.
    fn store_u256(ref self: Felt252Dict<u128>, element: u256, index: usize) {
        let index: felt252 = index.into();
        self.insert(index, element.high.into());
        self.insert(index + 1, element.low.into());
    }

    /// Reads a u256 element from the dictionary.
    /// The element is stored as two distinct u128 elements,
    /// thus we have to read the low and high parts and combine them.
    /// The memory is big-endian organized, so the high part is stored first.
    ///
    /// # Arguments
    /// * `self` - A mutable reference to the `Felt252Dict` instance.
    /// * `index` - The `usize` index at which the element is stored.
    ///
    /// # Returns
    /// * The element read, of type `u256`.
    fn read_u256(ref self: Felt252Dict<u128>, index: usize) -> u256 {
        let index: felt252 = index.into();
        let high: u128 = self.get(index);
        let low: u128 = self.get(index + 1);
        u256 { low: low, high: high }
    }
}


#[generate_trait]
impl MemoryPrintImpl of MemoryPrintTrait {
    /// Prints the memory content between offset begin and end
    fn print_segment(ref self: Memory, mut begin: usize, end: usize) {
        '____MEMORY_BEGIN___'.print();
        loop {
            if begin >= end {
                break ();
            }
            self.items.get(begin.into()).print();
            begin += 1;
        };
        '____MEMORY_END___'.print();
    }
}

impl DefaultMemoryImpl of Default<Memory> {
    fn default() -> Memory {
        MemoryTrait::new()
    }
}
