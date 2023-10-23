use result::ResultTrait;
use option::OptionTrait;
use array::{Array, ArrayTrait, Span, SpanTrait};
use clone::Clone;
use traits::{Into, TryInto};
use utils::errors::{RLPError, RLP_EMPTY_INPUT, RLP_INPUT_TOO_SHORT};
use utils::helpers::{U32Trait, ByteArrayExTrait};

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
impl RLPImpl of RLPTrait {
    /// Returns RLPType from the leading byte with
    /// its offset in the array as well as its size.
    ///
    /// # Arguments
    ///
    /// * `input` - Leading byte of the RLP encoded data
    /// Return result with (RLPType, offset, size)
    fn decode_type(input: Span<u8>) -> Result<(RLPType, u32, u32), RLPError> {
        let input_len = input.len();
        if input_len == 0 {
            return Result::Err(RLPError::RlpEmptyInput(RLP_EMPTY_INPUT));
        }

        let byte = *input[0];

        if byte < 0x80 { // Char
            Result::Ok((RLPType::String, 0, 1))
        } else if byte < 0xb8 { // Short String
            Result::Ok((RLPType::String, 1, byte.into() - 0x80))
        } else if byte < 0xc0 { // Long String
            let len_bytes_count: u32 = (byte - 0xb7).into();
            if input_len <= len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }
            let string_len_bytes = input.slice(1, len_bytes_count);
            let string_len: u32 = U32Trait::from_bytes(string_len_bytes).unwrap();

            Result::Ok((RLPType::String, 1 + len_bytes_count, string_len))
        } else if byte < 0xf8 { // Short List
            Result::Ok((RLPType::List, 1, byte.into() - 0xc0))
        } else { // Long List
            let len_bytes_count = byte.into() - 0xf7;
            if input.len() <= len_bytes_count {
                return Result::Err(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let list_len_bytes = input.slice(1, len_bytes_count);
            let list_len: u32 = U32Trait::from_bytes(list_len_bytes).unwrap();
            Result::Ok((RLPType::List, 1 + len_bytes_count, list_len))
        }
    }

    /// RLP encodes a ByteArray, which is the underlying type used to represent
    /// string data in Cairo.  Since RLP encoding is only used for eth_address
    /// computation by calculating the RLP::encode(deployer_address, deployer_nonce)
    /// and then hash it, the input is a ByteArray and not a Span<u8>
    /// # Arguments
    /// * `input` - ByteArray to encode
    /// # Returns
    /// * `ByteArray - RLP encoded ByteArray
    /// # Errors
    /// * RLPError::RlpEmptyInput - if the input is empty
    fn encode_string(input: ByteArray) -> Result<ByteArray, RLPError> {
        let len = input.len();
        if len == 0 {
            return Result::Ok(
                ByteArray { data: Default::default(), pending_word: 0x80, pending_word_len: 1 }
            );
        } else if len == 1 && input[0] < 0x80 {
            return Result::Ok(input);
        } else if len < 56 {
            let mut prefixes: ByteArray = Default::default();
            prefixes.append_byte(0x80 + len.try_into().unwrap());
            let encoding = prefixes + input;
            return Result::Ok(encoding);
        } else {
            let mut prefixes: ByteArray = Default::default();
            let len_as_bytes = len.to_bytes();
            let len_bytes_count = len_as_bytes.len();
            let prefix = 0xb7 + len_bytes_count.try_into().unwrap();
            prefixes.append_byte(prefix);
            prefixes.append_span_bytes(len_as_bytes);
            let encoding = prefixes + input;
            return Result::Ok(encoding);
        }
    }

    /// RLP decodes a rlp encoded byte array
    /// as described in https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
    ///
    /// # Arguments
    ///
    /// * `input` - RLP encoded bytes
    /// Return result with RLPItem and size of the decoded item
    fn decode(input: Span<u8>) -> Result<Span<RLPItem>, RLPError> {
        let mut output: Array<RLPItem> = Default::default();
        let input_len = input.len();
        let mut i = 0;

        let mut decode_error: Option<RLPError> = loop {
            let res = RLPTrait::decode_type(input.slice(i, input_len - i));
            let (rlp_type, offset, len) = match res {
                Result::Ok(res_dec) => { res_dec },
                Result::Err(err) => { break Option::Some(err); }
            };

            if input_len < offset + len {
                break Option::Some(RLPError::RlpInputTooShort(RLP_INPUT_TOO_SHORT));
            }

            match rlp_type {
                RLPType::String => {
                    output.append(RLPItem::String(input.slice(offset + i, len)));
                },
                RLPType::List => {
                    if len > 0 {
                        let res = RLPTrait::decode(input.slice(offset + i, len));
                        match res {
                            Result::Ok(res_dec) => { output.append(RLPItem::List(res_dec)); },
                            Result::Err(err) => { break Option::Some(err); }
                        };
                    } else {
                        output.append(RLPItem::List(array![].span()));
                    }
                }
            };

            i += len + offset;
            if i >= input_len {
                break Option::None;
            }
        };
        if decode_error.is_some() {
            return Result::Err(decode_error.unwrap());
        }

        Result::Ok(output.span())
    }
}

