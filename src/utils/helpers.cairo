use array::ArrayTrait;
use array::SpanTrait;
use traits::{Into, TryInto};
use option::OptionTrait;
use debug::PrintTrait;

// @notice Ceil a number of bits to the next word (32 bytes)
// ex: ceil_bytes_len_to_next_32_bytes_word(2) = 32
// ex: ceil_bytes_len_to_next_32_bytes_word(34) = 64
fn ceil_bytes_len_to_next_32_bytes_word(bytes_len: usize) -> usize {
    let q = (bytes_len + 31) / 32;
    return q * 32;
}

fn pow256_rev(i: usize) -> u256 {
    let mut pow256_rev_table: Array<u256> = ArrayTrait::new();

    pow256_rev_table.append(340282366920938463463374607431768211456);
    pow256_rev_table.append(1329227995784915872903807060280344576);
    pow256_rev_table.append(5192296858534827628530496329220096);
    pow256_rev_table.append(20282409603651670423947251286016);
    pow256_rev_table.append(79228162514264337593543950336);
    pow256_rev_table.append(309485009821345068724781056);
    pow256_rev_table.append(1208925819614629174706176);
    pow256_rev_table.append(4722366482869645213696);
    pow256_rev_table.append(18446744073709551616);
    pow256_rev_table.append(72057594037927936);
    pow256_rev_table.append(281474976710656);
    pow256_rev_table.append(1099511627776);
    pow256_rev_table.append(4294967296);
    pow256_rev_table.append(16777216);
    pow256_rev_table.append(65536);
    pow256_rev_table.append(256);
    pow256_rev_table.append(1);

    return *pow256_rev_table[i];
}

/// Loads a sequence of bytes into a single u256 in big-endian
fn load_word(mut len: usize, words: Span<u8>) -> felt252 {
    if len == 0 {
        return 0;
    }

    let mut current: felt252 = 0;
    let mut counter = 0;

    loop {
        if len == 0 {
            break ();
        }
        let loaded: u8 = *words[counter];
        let tmp = current * 256;
        current = tmp + loaded.into();
        len -= 1;
        counter += 1;
    };

    current
}

fn u256_to_bytes_array(mut value: u256) -> Array<u8> {
    let mut counter = 0;
    let mut bytes_vec: Array<u8> = ArrayTrait::new();
    // low part
    loop {
        if counter == 16 {
            break ();
        }
        bytes_vec.append((value.low % 256).try_into().unwrap());
        value.low /= 256;
        counter += 1;
    };

    let mut counter = 0;
    // high part
    loop {
        if counter == 16 {
            break ();
        }
        bytes_vec.append((value.high % 256).try_into().unwrap());
        value.high /= 256;
        counter += 1;
    };

    // Reverse the array as memory is arranged in big endian order.
    let mut counter = bytes_vec.len();
    let mut bytes_vec_reversed: Array<u8> = ArrayTrait::new();
    loop {
        if counter == 0 {
            break ();
        }
        bytes_vec_reversed.append(*bytes_vec[counter - 1]);
        counter -= 1;
    };
    bytes_vec_reversed
}

impl U256TryIntoU8 of TryInto<u256, u8> {
    fn try_into(self: u256) -> Option<u8> {
        if self.high != 0 {
            return Option::None(());
        }
        self.low.try_into()
    }
}
