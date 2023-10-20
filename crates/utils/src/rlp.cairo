use result::ResultTrait;
use option::OptionTrait;
use array::{Array, ArrayTrait, Span, SpanTrait};
use clone::Clone;
use traits::{Into, TryInto};
use utils::errors::{RLPError, RLP_EMPTY_INPUT, RLP_INPUT_TOO_SHORT};
use utils::helpers::{U32Trait, ByteArrayExTrait};

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
impl RLPImpl of RLPTrait {
    /// Returns RLPType from the leading byte
    ///
    /// # Arguments
    ///
    /// * `byte` - Leading byte of the RLP encoded data
    /// Return result with RLPType
    fn decode_type(byte: u8) -> RLPType {
        if byte < 0x80 {
            RLPType::String
        } else if byte < 0xb8 {
            RLPType::StringShort
        } else if byte < 0xc0 {
            RLPType::StringLong
        } else if byte < 0xf8 {
            RLPType::ListShort
        } else {
            RLPType::ListLong
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
    fn decode(input: Span<u8>) -> Result<(RLPItem, usize), RLPError> {
        if input.len() == 0 {
            return Result::Err(RLPError::RlpEmptyInput(RLP_EMPTY_INPUT));
        }
        let prefix = *input.at(0);

        let rlp_type = RLPTrait::decode_type(prefix);
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
}


fn rlp_decode_list(ref input: Span<u8>) -> Result<Span<Span<u8>>, RLPError> {
    let mut i = 0;
    let len = input.len();
    let mut output = ArrayTrait::new();

    let mut decode_error: Option<RLPError> = loop {
        if i >= len {
            break Option::None;
        }

        let res = RLPTrait::decode(input);

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
