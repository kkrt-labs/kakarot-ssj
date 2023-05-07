use array::ArrayTrait;

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
