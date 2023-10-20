use result::ResultTrait;
use option::OptionTrait;
use array::{Array, ArrayTrait, Span, SpanTrait};
use clone::Clone;
use traits::{Into, TryInto};
use utils::errors::{RLPError, RLP_EMPTY_INPUT, RLP_INPUT_TOO_SHORT};
use utils::helpers::BytesSerde;

use debug::PrintTrait;

// All possible RLP tpypes
#[derive(Drop, PartialEq)]
enum RLPType {
    String,
    List
}

#[derive(Drop, Copy, PartialEq)]
enum RLPItem {
    String: Span<u8>,
    List: Span<RLPItem>
}

#[generate_trait]
impl RLPTypeImpl of RLPTypeTrait {
    /// Returns RLPType from the leading byte
    ///
    /// # Arguments
    ///
    /// * `byte` - Leading byte
    /// Return result with RLPType
    fn from_byte(input: Span<u8>) -> Result<(RLPType, u32, u32), RLPError> {
        let input_len = input.len();
        if input_len == 0 {
            return Result::Err(RLPError::RlpEmptyInput(RLP_EMPTY_INPUT));
        }

        let byte = *input[0];
        
        if byte <= 0x7f { // Char
            Result::Ok((RLPType::String, 0, 1))
        } else if byte <= 0xb7 { // Short String
            Result::Ok((RLPType::String, 1, byte.into() - 0x80))
        } else if byte <= 0xbf { // Long String
            let len_bytes_count: u32 = (byte - 0xb7).into();
            if input_len <= len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }
            let string_len_bytes = input.slice(1, len_bytes_count);
            let string_len: u32 = string_len_bytes.deserialize().unwrap();
            if input_len <= string_len + len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            Result::Ok((RLPType::String, 1+len_bytes_count, string_len))
        } else if byte <= 0xf7 { // Short List
            Result::Ok((RLPType::List, 1, byte.into() - 0xc0))
        } else { // Long List
            let len_bytes_count = byte.into() - 0xf7;
            if input.len() <= len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let list_len_bytes = input.slice(1, len_bytes_count);
            let list_len: u32 = list_len_bytes.deserialize().unwrap();
            if input.len() < list_len + len_bytes_count + 1 {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }
            
            Result::Ok((RLPType::String, 1+len_bytes_count, list_len))
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
fn rlp_decode(input: Span<u8>) -> Result<Span<RLPItem>, RLPError> {
    let mut output: Array<RLPItem> = Default::default();
    let input_len = input.len();
    let mut i = 0;

    let mut decode_error: Option<RLPError> = loop {

        let res = RLPTypeTrait::from_byte(input.slice(i, input_len-i));
        let (rlp_type, offset, len) = match res {
            Result::Ok(res_dec) => { res_dec },
            Result::Err(err) => { break Option::Some(err); }
        };

        if input_len < offset+len {
            break Option::Some(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
        }

        match rlp_type {
            RLPType::String => {
                output.append(RLPItem::String(input.slice(offset, len)));
            },
            RLPType::List => {
                let res = rlp_decode(input.slice(offset, len));
                match res {
                    Result::Ok(res_dec) => { output.append(RLPItem::List(res_dec)); },
                    Result::Err(err) => { break Option::Some(err); }
                };
            }
        };

        i += len+offset;
        if i >= input_len {
            break Option::None;
        }
    };
    if decode_error.is_some() {
        return Result::Err(decode_error.unwrap());
    }
    Result::Ok(output.span())
}