use utils::bitwise::{left_shift, right_shift, bit_length};

#[test]
#[available_gas(999999)]
fn test_left_shift() {
    assert(left_shift(1_u32, 0_u32) == 1, '1 << 0');
    assert(left_shift(1_u32, 1_u32) == 2, '1 << 1');
    assert(left_shift(1_u32, 2_u32) == 4, '1 << 2');
    assert(left_shift(1_u32, 8_u32) == 256, '1 << 8');
    assert(left_shift(2_u32, 8_u32) == 512, '2 << 8');
    assert(left_shift(255_u32, 8_u32) == 65280, '255 << 8');
}

#[test]
#[available_gas(999999)]
fn test_right_shift() {
    assert(right_shift(1_u32, 0_u32) == 1, '1 >> 0');
    assert(right_shift(2_u32, 1_u32) == 1, '2 >> 1');
    assert(right_shift(4_u32, 2_u32) == 1, '4 >> 2');
    assert(right_shift(256_u32, 8_u32) == 1, '256 >> 8');
    assert(right_shift(512_u32, 8_u32) == 2, '512 >> 8');
    assert(right_shift(65280_u32, 8_u32) == 255, '65280 >> 8');
}

#[test]
#[available_gas(999999)]
fn test_bit_length() {
    assert(bit_length(0_u32) == 0, 'bit length of 0 is 0');
    assert(bit_length(1_u32) == 1, 'bit length of 1 is 1');
    assert(bit_length(2_u128) == 2, 'bit length of 2 is 2');
    assert(bit_length(5_u8) == 3, 'bit length of 5 is 3');
    assert(bit_length(7_u128) == 3, 'bit length of 7 is 3');
    assert(bit_length(8_u32) == 4, 'bit length of 8 is 4');
}
