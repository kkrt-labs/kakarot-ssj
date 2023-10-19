use result::ResultTrait;
use option::OptionTrait;
use array::{Array, ArrayTrait, Span, SpanTrait};
use clone::Clone;
use traits::{Into, TryInto};
use utils::errors::{RLPError, RLP_EMPTY_INPUT, RLP_INPUT_TOO_SHORT};
use utils::helpers::U32Trait;

// All possible RLP types
#[derive(Drop, PartialEq)]
enum RLPType {
    String,
    StringShort,
    StringLong,
    ListShort,
    ListLong,
}

#[derive(Drop, PartialEq)]
enum RLPItem {
    Bytes: Span<u8>,
    // Should be Span<RLPItem> to allow for any depth/recursion, not yet supported by the compiler
    List: Span<Span<u8>>
}

#[generate_trait]
impl RLPTypeImpl of RLPTypeTrait {
    /// Returns RLPType from the leading byte
    ///
    /// # Arguments
    ///
    /// * `byte` - Leading byte
    /// Return result with RLPType
    fn from_byte(byte: u8) -> RLPType {
        if byte <= 0x7f {
            RLPType::String
        } else if byte <= 0xb7 {
            RLPType::StringShort
        } else if byte <= 0xbf {
            RLPType::StringLong
        } else if byte <= 0xf7 {
            RLPType::ListShort
        } else {
            RLPType::ListLong
        }
    }
}

/// RLP decodes a rlp encoded byte array
/// as described in https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
///
/// # Arguments
///
/// * `input` - RLP encoded bytes
/// Return result with RLPItem and size of the decoded item
fn rlp_decode(input: Span<u8>) -> Result<(RLPItem, usize), RLPError> {
    if input.len() == 0 {
        return Result::Err(RLPError::RlpEmptyInput(RLP_EMPTY_INPUT));
    }
    let prefix = *input.at(0);

    let rlp_type = RLPTypeTrait::from_byte(prefix);
    match rlp_type {
        RLPType::String => {
            let mut arr = array![prefix];
            Result::Ok((RLPItem::Bytes(arr.span()), 1))
        },
        RLPType::StringShort => {
            let len = prefix.into() - 0x80;
            if input.len() <= len {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }
            let decoded_string = input.slice(1, len);

            Result::Ok((RLPItem::Bytes(decoded_string), 1 + len))
        },
        RLPType::StringLong => {
            let len_bytes_count = prefix.into() - 0xb7;
            if input.len() <= len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let string_len_bytes = input.slice(1, len_bytes_count);
            let string_len: u32 = U32Trait::from_bytes(string_len_bytes).unwrap();
            if input.len() <= string_len + len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let decoded_string = input.slice(1 + len_bytes_count, string_len);

            Result::Ok((RLPItem::Bytes(decoded_string), 1 + len_bytes_count + string_len))
        },
        RLPType::ListShort => {
            let len = prefix.into() - 0xc0;
            if input.len() <= len {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let mut list_input = input.slice(1, len);
            let decoded_list = rlp_decode_list(ref list_input)?;
            Result::Ok((RLPItem::List(decoded_list), 1 + len))
        },
        RLPType::ListLong => {
            let len_bytes_count = prefix.into() - 0xf7;
            if input.len() <= len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let list_len_bytes = input.slice(1, len_bytes_count);
            let list_len: u32 = U32Trait::from_bytes(list_len_bytes).unwrap();
            if input.len() < list_len + len_bytes_count + 1 {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let mut list_input = input.slice(1 + len_bytes_count, list_len);
            let decoded_list = rlp_decode_list(ref list_input)?;
            Result::Ok((RLPItem::List(decoded_list), 1 + len_bytes_count + list_len))
        }
    }
}

fn rlp_decode_list(ref input: Span<u8>) -> Result<Span<Span<u8>>, RLPError> {
    let mut i = 0;
    let len = input.len();
    let mut output = ArrayTrait::new();

    let mut decode_error: Option<RLPError> = loop {
        if i >= len {
            break Option::None;
        }

        let res = rlp_decode(input);

        let (decoded, decoded_len) = match res {
            Result::Ok(res_dec) => { res_dec },
            Result::Err(err) => { break Option::Some(err); }
        };
        match decoded {
            RLPItem::Bytes(b) => {
                output.append(b);
                input = input.slice(decoded_len, input.len() - decoded_len);
            },
            RLPItem::List(_) => { panic_with_felt252('Recursive list not supported'); }
        }
        i += decoded_len;
    };
    if decode_error.is_some() {
        return Result::Err(decode_error.unwrap());
    }
    Result::Ok(output.span())
}
