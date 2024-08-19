use core::array;
use core::felt252_div;
use core::num::traits::Zero;

/// Load packed bytes from an array of bytes packed in 31-byte words and a final word.
///
/// # Arguments
///
/// * `input` - An array of 31-bytes words and a final word.
/// * `bytes_len` - The total number of bytes to unpack.
///
/// # Returns
///
/// An `Array<u8>` containing the unpacked bytes in big-endian order.
///
/// # Performance considerations
///
/// This function uses head-recursive helper functions (`unpack_full_value` and
/// `unpack_partial_value`) for unpacking individual felt252 values. Head recursion
/// is used here instead of loops because the Array type in Cairo is append-only. This approach
/// allows us to append the bytes in the correct order (big-endian) without needing to
/// reverse the array afterwards. This leads to more efficient memory usage and performance.
pub fn load_packed_bytes(mut input: Span<felt252>, bytes_len: u32) -> Array<u8> {
    if input.is_empty() {
        return Default::default();
    }
    let mut res: Array<u8> = Default::default();
    let full_words = input.slice(0, input.len() - 1);
    for value in full_words {
        let mut value: u256 = (*value).into();
        unpack_full_value(value, ref res);
    };

    let mut last_value: u256 = (*input.pop_back().unwrap()).into();
    if last_value.is_zero() {
        return res;
    }
    let mut remaining_bytes = bytes_len - (full_words.len() * 31);
    unpack_partial_value(last_value, remaining_bytes, ref res);
    res
}

/// Unpacks a value into an array of bytes. The value is expected to be a 31-bytes word.
/// Uses head recursion to append bytes in big-endian order.
///
/// # Arguments
///
/// * `value` - The u256 value to unpack.
/// * `output` - A mutable reference to the output byte array.
fn unpack_full_value(value: u256, ref output: Array<u8>) {
    if value == 0 {
        return;
    }
    let (q, r) = DivRem::div_rem(value, 256);
    unpack_full_value(q, ref output);
    output.append(r.try_into().unwrap());
}

/// Unpacks a partial felt252 value into an array of bytes.
///
/// Similar to `unpack_full_value`, but it unpacks only a specified
/// number of bytes from the value.
/// Uses head recursion to append bytes in big-endian order.
///
/// # Arguments
///
/// * `value` - The u256 value to unpack.
/// * `remaining_bytes` - The number of bytes to unpack from the value.
fn unpack_partial_value(value: u256, remaining_bytes: u32, ref output: Array<u8>) {
    if remaining_bytes == 0 {
        return;
    }

    let (q, r) = DivRem::div_rem(value, 256);
    unpack_partial_value(q, remaining_bytes - 1, ref output);
    output.append(r.try_into().unwrap());
}

#[cfg(test)]
mod tests {
    use super::{load_packed_bytes};

    #[test]
    fn test_should_load_empty_array() {
        let res = load_packed_bytes([].span(), 0);

        assert_eq!(res.span(), [].span());
    }

    #[test]
    fn test_should_load_single_31bytes_felt() {
        let input = [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff];
        let res = load_packed_bytes(input.span(), 31);

        assert_eq!(res.span(), [0xff; 31].span());
    }

    #[test]
    fn test_should_load_with_non_full_last_felt() {
        let input = [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0xffff];
        let res = load_packed_bytes(input.span(), 33);

        assert_eq!(res.span(), [0xff; 33].span());
    }

    #[test]
    fn test_should_load_multiple_words() {
        let input = [
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffff
        ];
        let res = load_packed_bytes(input.span(), 64);

        assert_eq!(res.span(), [0xff; 64].span());
    }

    #[test]
    fn test_should_load_mixed_byte_values_big_endian() {
        let input = [0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f, 0x2021];
        let res = load_packed_bytes(input.span(), 33);
        assert_eq!(
            res.span(),
            [
                0x01,
                0x02,
                0x03,
                0x04,
                0x05,
                0x06,
                0x07,
                0x08,
                0x09,
                0x0a,
                0x0b,
                0x0c,
                0x0d,
                0x0e,
                0x0f,
                0x10,
                0x11,
                0x12,
                0x13,
                0x14,
                0x15,
                0x16,
                0x17,
                0x18,
                0x19,
                0x1a,
                0x1b,
                0x1c,
                0x1d,
                0x1e,
                0x1f,
                0x20,
                0x21
            ].span()
        );
    }
}
