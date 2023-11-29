use core::byte_array::ByteArrayTrait;
use core::result::ResultTrait;
use utils::errors::{RLPError, RLPHelpersError, RLP_EMPTY_INPUT, RLP_INPUT_TOO_SHORT};
use utils::helpers::{U32Trait, U256Impl, U128Impl, ArrayExtension};

// Possible RLP types
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
    /// * `input` - Array of byte to decode
    /// # Returns
    /// * `(RLPType, offset, size)` - A tuple containing the RLPType
    /// the offset and the size of the RLPItem to decode
    /// # Errors
    /// * RLPError::EmptyInput - if the input is empty
    /// * RLPError::InputTooShort - if the input is too short for a given
    fn decode_type(input: Span<u8>) -> Result<(RLPType, u32, u32), RLPError> {
        let input_len = input.len();
        if input_len == 0 {
            return Result::Err(RLPError::EmptyInput(RLP_EMPTY_INPUT));
        }

        let prefix_byte = *input[0];

        if prefix_byte < 0x80 { // Char
            Result::Ok((RLPType::String, 0, 1))
        } else if prefix_byte < 0xb8 { // Short String
            Result::Ok((RLPType::String, 1, prefix_byte.into() - 0x80))
        } else if prefix_byte < 0xc0 { // Long String
            let len_bytes_count: u32 = (prefix_byte - 0xb7).into();
            if input_len <= len_bytes_count {
                return Result::Err(RLPError::InputTooShort(RLP_INPUT_TOO_SHORT));
            }
            let string_len_bytes = input.slice(1, len_bytes_count);
            let string_len: u32 = U32Trait::from_bytes(string_len_bytes).unwrap();

            Result::Ok((RLPType::String, 1 + len_bytes_count, string_len))
        } else if prefix_byte < 0xf8 { // Short List
            Result::Ok((RLPType::List, 1, prefix_byte.into() - 0xc0))
        } else { // Long List
            let len_bytes_count = prefix_byte.into() - 0xf7;
            if input.len() <= len_bytes_count {
                return Result::Err(RLPError::InputTooShort(RLP_INPUT_TOO_SHORT));
            }

            let list_len_bytes = input.slice(1, len_bytes_count);
            let list_len: u32 = U32Trait::from_bytes(list_len_bytes).unwrap();
            Result::Ok((RLPType::List, 1 + len_bytes_count, list_len))
        }
    }

    /// RLP encodes a sequence of RLPItem
    /// # Arguments
    /// * `input` - Span of RLPItem to encode
    /// # Returns
    /// * `ByteArray - RLP encoded ByteArray
    /// # Errors
    /// * RLPError::RlpEmptyInput - if the input is empty
    fn encode_sequence(mut input: Span<RLPItem>) -> Span<u8> {
        let mut joined_encodings: Array<u8> = Default::default();
        loop {
            match input.pop_front() {
                Option::Some(item) => {
                    match item {
                        RLPItem::String(string) => {
                            joined_encodings.append_span(RLPTrait::encode_string(*string));
                        },
                        RLPItem::List(_) => { panic_with_felt252('List encoding unimplemented') }
                    }
                },
                Option::None => { break; }
            }
        };
        let len_joined_encodings = joined_encodings.len();
        if len_joined_encodings < 0x38 {
            let mut result: Array<u8> = array![0xC0 + len_joined_encodings.try_into().unwrap()];
            result.append_span(joined_encodings.span());
            return result.span();
        } else {
            // Actual implementation of long list encoding is commented out
            // as we should never reach this point in the current implementation
            // let bytes_count_len_joined_encodings = len_joined_encodings.bytes_used();
            // let len_joined_encodings: Span<u8> = len_joined_encodings.to_bytes();
            // let mut result = array![0xF7 + bytes_count_len_joined_encodings];
            // result.append_span(len_joined_encodings);
            // result.append_span(joined_encodings.span());
            // return result.span();
            return panic_with_felt252('Shouldnt encode long sequence');
        }
    }

    /// RLP encodes a Span<u8>, which is the underlying type used to represent
    /// string data in Cairo.  Since RLP encoding is only used for eth_address
    /// computation by calculating the RLP::encode(deployer_address, deployer_nonce)
    /// and then hash it, the input is a Span<u8>
    /// # Arguments
    /// * `input` - ByteArray to encode
    /// # Returns
    /// * `ByteArray - RLP encoded ByteArray
    /// # Errors
    /// * RLPError::RlpEmptyInput - if the input is empty
    fn encode_string(input: Span<u8>) -> Span<u8> {
        let len = input.len();
        if len == 0 {
            return array![0x80].span();
        } else if len == 1 && *input[0] < 0x80 {
            return input;
        } else if len < 56 {
            let mut encoding: Array<u8> = Default::default();
            encoding.append(0x80 + len.try_into().unwrap());
            encoding.append_span(input);
            return encoding.span();
        } else {
            let mut encoding: Array<u8> = Default::default();
            let len_as_bytes = len.to_bytes();
            let len_bytes_count = len_as_bytes.len();
            let prefix = 0xb7 + len_bytes_count.try_into().unwrap();
            encoding.append(prefix);
            encoding.append_span(len_as_bytes);
            encoding.append_span(input);
            return encoding.span();
        }
    }

    /// RLP decodes a rlp encoded byte array
    /// as described in https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
    ///
    /// # Arguments
    /// * `input` - Array of bytes to decode
    /// # Returns
    /// * `Span<RLPItem>` - Span of RLPItem
    /// # Errors
    /// * RLPError::InputTooShort - if the input is too short for a given
    fn decode(input: Span<u8>) -> Result<Span<RLPItem>, RLPError> {
        let mut output: Array<RLPItem> = Default::default();
        let input_len = input.len();

        let (rlp_type, offset, len) = RLPTrait::decode_type(input)?;

        if input_len < offset + len {
            return Result::Err(RLPError::InputTooShort(RLP_INPUT_TOO_SHORT));
        }

        match rlp_type {
            RLPType::String => {
                if (len == 0) {
                    output.append(RLPItem::String(array![].span()));
                } else {
                    output.append(RLPItem::String(input.slice(offset, len)));
                }
            },
            RLPType::List => {
                if len > 0 {
                    let res = RLPTrait::decode(input.slice(offset, len))?;
                    output.append(RLPItem::List(res));
                } else {
                    output.append(RLPItem::List(array![].span()));
                }
            }
        };

        let total_item_len = len + offset;
        if total_item_len < input_len {
            output
                .append_span(
                    RLPTrait::decode(input.slice(total_item_len, input_len - total_item_len))?
                );
        }

        Result::Ok(output.span())
    }
}

#[generate_trait]
impl RLPHelpersImpl of RLPHelpersTrait {
    fn parse_u128_from_string(self: RLPItem) -> Result<u128, RLPHelpersError> {
        match self {
            RLPItem::String(bytes) => {
                // Empty strings means 0
                if bytes.len() == 0 {
                    return Result::Ok(0);
                }
                let value = U128Impl::from_bytes(bytes).ok_or(RLPHelpersError::FailedParsingU128)?;
                Result::Ok(value)
            },
            RLPItem::List(_) => { Result::Err(RLPHelpersError::NotAString) }
        }
    }

    fn parse_u256_from_string(self: RLPItem) -> Result<u256, RLPHelpersError> {
        match self {
            RLPItem::String(bytes) => {
                // Empty strings means 0
                if bytes.len() == 0 {
                    return Result::Ok(0);
                }
                let value = U256Impl::from_bytes(bytes).ok_or(RLPHelpersError::FailedParsingU256)?;
                Result::Ok(value)
            },
            RLPItem::List(_) => { Result::Err(RLPHelpersError::NotAString) }
        }
    }


    fn parse_bytes_from_string(self: RLPItem) -> Result<Span<u8>, RLPHelpersError> {
        match self {
            RLPItem::String(bytes) => { Result::Ok(bytes) },
            RLPItem::List(_) => { Result::Err(RLPHelpersError::NotAString) }
        }
    }
}
