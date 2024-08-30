use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::option::OptionTrait;
use core::panic_with_felt252;
use core::starknet::EthAddress;
use utils::errors::{RLPError, RLPHelpersError};
use utils::eth_transaction::AccessListItem;
use utils::helpers::{EthAddressExTrait, ArrayExtension, ToBytes, FromBytes};

// Possible RLP types
#[derive(Drop, PartialEq)]
pub enum RLPType {
    String,
    List
}

#[derive(Drop, Copy, PartialEq)]
pub enum RLPItem {
    String: Span<u8>,
    List: Span<RLPItem>
}

#[generate_trait]
pub impl RLPImpl of RLPTrait {
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
            return Result::Err(RLPError::EmptyInput);
        }

        let prefix = *input[0];

        if prefix < 0x80 { // Char
            Result::Ok((RLPType::String, 0, 1))
        } else if prefix < 0xb8 { // Short String
            Result::Ok((RLPType::String, 1, prefix.into() - 0x80))
        } else if prefix < 0xc0 { // Long String
            let len_bytes_count: u32 = (prefix - 0xb7).into();
            if input_len <= len_bytes_count {
                return Result::Err(RLPError::InputTooShort);
            }
            let string_len_bytes = input.slice(1, len_bytes_count);
            let string_len: u32 = string_len_bytes
                .from_be_bytes_partial()
                .expect('rlp_decode_type_string_len');
            if input_len <= len_bytes_count + string_len {
                return Result::Err(RLPError::InputTooShort);
            }

            Result::Ok((RLPType::String, 1 + len_bytes_count, string_len))
        } else if prefix < 0xf8 { // Short List
            let list_len: u32 = prefix.into() - 0xc0;
            if input_len <= list_len {
                return Result::Err(RLPError::InputTooShort);
            }
            Result::Ok((RLPType::List, 1, list_len))
        } else if prefix <= 0xff { // Long List
            let len_bytes_count = prefix.into() - 0xf7;
            if input.len() <= len_bytes_count {
                return Result::Err(RLPError::InputTooShort);
            }
            let list_len_bytes = input.slice(1, len_bytes_count);
            let list_len: u32 = list_len_bytes
                .from_be_bytes_partial()
                .expect('rlp_decode_type_list_len');
            if input_len <= len_bytes_count + list_len {
                return Result::Err(RLPError::InputTooShort);
            }
            Result::Ok((RLPType::List, 1 + len_bytes_count, list_len))
        } else {
            Result::Err(RLPError::InvalidInput)
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
        while let Option::Some(item) = input.pop_front() {
            match item {
                RLPItem::String(string) => {
                    joined_encodings.append_span(Self::encode_string(*string));
                },
                RLPItem::List(_) => { panic_with_felt252('List encoding unimplemented') }
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
            return [0x80].span();
        } else if len == 1 && *input[0] < 0x80 {
            return input;
        } else if len < 56 {
            let mut encoding: Array<u8> = Default::default();
            encoding.append(0x80 + len.try_into().unwrap());
            encoding.append_span(input);
            return encoding.span();
        } else {
            let mut encoding: Array<u8> = Default::default();
            let len_as_bytes = len.to_be_bytes();
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

        let (rlp_type, offset, len) = Self::decode_type(input)?;

        if input_len < offset + len {
            return Result::Err(RLPError::InputTooShort);
        }

        match rlp_type {
            RLPType::String => {
                if (len == 0) {
                    output.append(RLPItem::String([].span()));
                } else {
                    output.append(RLPItem::String(input.slice(offset, len)));
                }
            },
            RLPType::List => {
                if len == 0 {
                    output.append(RLPItem::List([].span()));
                } else {
                    let res = Self::decode(input.slice(offset, len))?;
                    output.append(RLPItem::List(res));
                }
            }
        };

        let total_item_len = len + offset;
        if total_item_len < input_len {
            output
                .append_span(
                    Self::decode(input.slice(total_item_len, input_len - total_item_len))?
                );
        }

        Result::Ok(output.span())
    }
}

#[generate_trait]
pub impl RLPHelpersImpl of RLPHelpersTrait {
    fn parse_u128_from_string(self: RLPItem) -> Result<u128, RLPHelpersError> {
        match self {
            RLPItem::String(bytes) => {
                // Empty strings means 0
                if bytes.len() == 0 {
                    return Result::Ok(0);
                }
                let value = bytes.from_be_bytes_partial().expect('parse_u128_from_string');
                Result::Ok(value)
            },
            RLPItem::List(_) => { Result::Err(RLPHelpersError::NotAString) }
        }
    }

    fn try_parse_address_from_string(self: RLPItem) -> Result<Option<EthAddress>, RLPHelpersError> {
        match self {
            RLPItem::String(bytes) => {
                if bytes.len() == 0 {
                    return Result::Ok(Option::None);
                }
                if bytes.len() == 20 {
                    let value = EthAddressExTrait::from_bytes(bytes);
                    return Result::Ok(Option::Some(value));
                }
                return Result::Err(RLPHelpersError::FailedParsingAddress);
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
                let value = bytes.from_be_bytes_partial().expect('parse_u256_from_string');
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

    fn parse_storage_keys_from_rlp_item(self: RLPItem) -> Result<Span<u256>, RLPHelpersError> {
        match self {
            RLPItem::String(_) => { return Result::Err(RLPHelpersError::NotAList); },
            RLPItem::List(mut keys) => {
                let mut storage_keys: Array<u256> = array![];
                let storage_keys: Result<Span<u256>, RLPHelpersError> = loop {
                    match keys.pop_front() {
                        Option::Some(rlp_item) => {
                            let storage_key = match ((*rlp_item).parse_u256_from_string()) {
                                Result::Ok(storage_key) => { storage_key },
                                Result::Err(err) => { break Result::Err(err); }
                            };

                            storage_keys.append(storage_key);
                        },
                        Option::None => { break Result::Ok(storage_keys.span()); }
                    }
                };

                storage_keys
            }
        }
    }

    fn parse_access_list(self: RLPItem) -> Result<Span<AccessListItem>, RLPHelpersError> {
        match self {
            RLPItem::String(_) => { Result::Err(RLPHelpersError::NotAList) },
            RLPItem::List(mut list) => {
                let res: Result<Span<AccessListItem>, RLPHelpersError> = loop {
                    let mut access_list: Array<AccessListItem> = array![];
                    let list = match list.pop_front() {
                        Option::Some(rlp_item) => {
                            match rlp_item {
                                RLPItem::String(_) => {
                                    break Result::Err(RLPHelpersError::NotAList);
                                },
                                RLPItem::List(list) => *list,
                            }
                        },
                        Option::None => { break Result::Ok(access_list.span()); }
                    };

                    // since access list is a list of tuples of 2 elements
                    // accessList: Span<(EthAddress, Span<u256>)>
                    if (list.len() != 2) {
                        break Result::Err(RLPHelpersError::FailedParsingAccessList);
                    }

                    let ethereum_address = match ((*list.at(0)).try_parse_address_from_string()) {
                        Result::Ok(maybe_eth_address) => {
                            match (maybe_eth_address) {
                                Option::Some(eth_address) => { eth_address },
                                Option::None => {
                                    break Result::Err(RLPHelpersError::FailedParsingAccessList);
                                }
                            }
                        },
                        Result::Err(err) => { break Result::Err(err); }
                    };

                    let storage_keys: Span<u256> =
                        match (*list.at(1)).parse_storage_keys_from_rlp_item() {
                        Result::Ok(storage_keys) => storage_keys,
                        Result::Err(err) => { break Result::Err(err); }
                    };

                    access_list.append(AccessListItem { ethereum_address, storage_keys });

                    break Result::Ok(access_list.span());
                };

                res
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use core::array::SpanTrait;
    use core::option::OptionTrait;

    use core::result::ResultTrait;
    use utils::errors::RLPError;
    use utils::eth_transaction::AccessListItem;
    use utils::rlp::{RLPType, RLPTrait, RLPItem, RLPHelpersTrait};

    // Tests source :
    // https://github.com/HerodotusDev/cairo-lib/blob/main/src/encoding/tests/test_rlp.cairo
    //                https://github.com/ethereum/tests/blob/develop/RLPTests/rlptest.json

    #[test]
    fn test_rlp_decode_type_byte() {
        let mut arr = array![0x78];

        let (rlp_type, offset, size) = RLPTrait::decode_type(arr.span()).unwrap();

        assert(rlp_type == RLPType::String, 'Wrong type');
        assert_eq!(offset, 0);
        assert_eq!(size, 1);
    }

    #[test]
    fn test_rlp_decode_type_short_string() {
        let mut arr = array![0x82];

        let (rlp_type, offset, size) = RLPTrait::decode_type(arr.span()).unwrap();

        assert(rlp_type == RLPType::String, 'Wrong type');
        assert_eq!(offset, 1);
        assert_eq!(size, 2);
    }

    #[test]
    fn test_rlp_decode_type_long_string() {
        let mut arr = array![0xb8, 0x01, 0x02];

        let (rlp_type, offset, size) = RLPTrait::decode_type(arr.span()).unwrap();

        assert(rlp_type == RLPType::String, 'Wrong type');
        assert_eq!(offset, 2);
        assert_eq!(size, 1);
    }

    #[test]
    fn test_rlp_decode_type_short_list() {
        let mut arr = array![0xc3, 0x01, 0x02, 0x03];

        let (rlp_type, offset, size) = RLPTrait::decode_type(arr.span()).unwrap();

        assert(rlp_type == RLPType::List, 'Wrong type');
        assert_eq!(offset, 1);
        assert_eq!(size, 3);
    }

    #[test]
    fn test_rlp_decode_type_long_list() {
        let mut arr = array![0xf8, 0x01, 0x00];

        let (rlp_type, offset, size) = RLPTrait::decode_type(arr.span()).unwrap();

        assert(rlp_type == RLPType::List, 'Wrong type');
        assert_eq!(offset, 2);
        assert_eq!(size, 1);
    }

    #[test]
    fn test_rlp_decode_type_long_list_len_too_short() {
        let mut arr = array![0xf9, 0x01];

        let res = RLPTrait::decode_type(arr.span());

        assert(res.is_err(), 'Wrong type');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_empty() {
        let res = RLPTrait::decode(ArrayTrait::new().span());

        assert(res.is_err(), 'should return an error');
        assert(res.unwrap_err() == RLPError::EmptyInput, 'err != EmptyInput');
    }


    #[test]
    fn test_rlp_encode_string_single_byte_lt_0x80() {
        let mut input: Array<u8> = Default::default();
        input.append(0x40);

        let res = RLPTrait::encode_string(input.span());

        assert(res.len() == 1, 'wrong len');
        assert(*res[0] == 0x40, 'wrong encoded value');
    }

    #[test]
    fn test_rlp_encode_string_single_byte_ge_0x80() {
        let mut input: Array<u8> = Default::default();
        input.append(0x80);

        let res = RLPTrait::encode_string(input.span());

        assert(res.len() == 2, 'wrong len');
        assert(*res[0] == 0x81, 'wrong prefix');
        assert(*res[1] == 0x80, 'wrong encoded value');
    }

    #[test]
    fn test_rlp_encode_string_length_between_2_and_55() {
        let mut input: Array<u8> = Default::default();
        input.append(0x40);
        input.append(0x50);

        let res = RLPTrait::encode_string(input.span());

        assert(res.len() == 3, 'wrong len');
        assert(*res[0] == 0x82, 'wrong prefix');
        assert(*res[1] == 0x40, 'wrong first value');
        assert(*res[2] == 0x50, 'wrong second value');
    }

    #[test]
    fn test_rlp_encode_string_length_exactly_56() {
        let mut input: Array<u8> = Default::default();
        let mut i = 0;
        loop {
            if i == 56 {
                break;
            }
            input.append(0x60);
            i += 1;
        };

        let res = RLPTrait::encode_string(input.span());

        assert(res.len() == 58, 'wrong len');
        assert(*res[0] == 0xb8, 'wrong prefix');
        assert(*res[1] == 56, 'wrong string length');
        let mut i = 2;
        loop {
            if i == 58 {
                break;
            }
            assert(*res[i] == 0x60, 'wrong value in sequence');
            i += 1;
        };
    }

    #[test]
    fn test_rlp_encode_string_length_greater_than_56() {
        let mut input: Array<u8> = Default::default();
        let mut i = 0;
        loop {
            if i == 60 {
                break;
            }
            input.append(0x70);
            i += 1;
        };

        let res = RLPTrait::encode_string(input.span());

        assert(res.len() == 62, 'wrong len');
        assert(*res[0] == 0xb8, 'wrong prefix');
        assert(*res[1] == 60, 'wrong length byte');
        let mut i = 2;
        loop {
            if i == 62 {
                break;
            }
            assert(*res[i] == 0x70, 'wrong value in sequence');
            i += 1;
        }
    }

    #[test]
    fn test_rlp_encode_string_large_bytearray_inputs() {
        let mut input: Array<u8> = Default::default();
        let mut i = 0;
        loop {
            if i == 500 {
                break;
            }
            input.append(0x70);
            i += 1;
        };

        let res = RLPTrait::encode_string(input.span());

        assert(res.len() == 503, 'wrong len');
        assert(*res[0] == 0xb9, 'wrong prefix');
        assert(*res[1] == 0x01, 'wrong first length byte');
        assert(*res[2] == 0xF4, 'wrong second length byte');
        let mut i = 3;
        loop {
            if i == 503 {
                break;
            }
            assert(*res[i] == 0x70, 'wrong value in sequence');
            i += 1;
        }
    }

    #[test]
    fn test_rlp_encode_sequence_empty() {
        let res = RLPTrait::encode_sequence([].span());

        assert(res.len() == 1, 'wrong len');
        assert(*res[0] == 0xC0, 'wrong encoded value');
    }

    #[test]
    fn test_rlp_encode_sequence() {
        let cat = RLPItem::String([0x63, 0x61, 0x74].span());
        let dog = RLPItem::String([0x64, 0x6f, 0x67].span());
        let input = array![cat, dog];

        let encoding = RLPTrait::encode_sequence(input.span());

        let expected = [0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67].span();
        assert(expected == encoding, 'wrong rlp encoding')
    }

    #[test]
    #[should_panic(expected: ('Shouldnt encode long sequence',))]
    fn test_rlp_encode_sequence_long_sequence() {
        // encoding of a sequence with more than 55 bytes
        let mut lorem_ipsum = RLPItem::String(
            [
                0x4c,
                0x6f,
                0x72,
                0x65,
                0x6d,
                0x20,
                0x69,
                0x70,
                0x73,
                0x75,
                0x6d,
                0x20,
                0x64,
                0x6f,
                0x6c,
                0x6f,
                0x72,
                0x20,
                0x73,
                0x69,
                0x74,
                0x20,
                0x61,
                0x6d,
                0x65,
                0x74,
                0x2c,
                0x20,
                0x63,
                0x6f,
                0x6e,
                0x73,
                0x65,
                0x63,
                0x74,
                0x65,
                0x74,
                0x75,
                0x72,
                0x20,
                0x61,
                0x64,
                0x69,
                0x70,
                0x69,
                0x73,
                0x69,
                0x63,
                0x69,
                0x6e,
                0x67,
                0x20,
                0x65,
                0x6c,
                0x69,
                0x74
            ].span()
        );
        let input = [lorem_ipsum].span();
        let encoding = RLPTrait::encode_sequence(input);

        let expected = [
            0xf8,
            0x3a,
            0xb8,
            0x38,
            0x4c,
            0x6f,
            0x72,
            0x65,
            0x6d,
            0x20,
            0x69,
            0x70,
            0x73,
            0x75,
            0x6d,
            0x20,
            0x64,
            0x6f,
            0x6c,
            0x6f,
            0x72,
            0x20,
            0x73,
            0x69,
            0x74,
            0x20,
            0x61,
            0x6d,
            0x65,
            0x74,
            0x2c,
            0x20,
            0x63,
            0x6f,
            0x6e,
            0x73,
            0x65,
            0x63,
            0x74,
            0x65,
            0x74,
            0x75,
            0x72,
            0x20,
            0x61,
            0x64,
            0x69,
            0x70,
            0x69,
            0x73,
            0x69,
            0x63,
            0x69,
            0x6e,
            0x67,
            0x20,
            0x65,
            0x6c,
            0x69,
            0x74
        ].span();
        assert(expected == encoding, 'wrong rlp encoding')
    }

    #[test]
    fn test_rlp_decode_string_default_value() {
        let mut arr = array![0x80];

        let rlp_item = RLPTrait::decode(arr.span()).unwrap();
        let expected = RLPItem::String([].span());

        assert(rlp_item.len() == 1, 'item length not 1');
        assert(*rlp_item[0] == expected, 'default value not 0');
    }

    #[test]
    fn test_rlp_decode_string() {
        let mut i = 0;
        loop {
            if i == 0x80 {
                break;
            }
            let mut arr = ArrayTrait::new();
            arr.append(i);

            let res = RLPTrait::decode(arr.span()).unwrap();

            assert(res == [RLPItem::String(arr.span())].span(), 'Wrong value');

            i += 1;
        };
    }

    #[test]
    fn test_rlp_decode_short_string() {
        let mut arr = array![
            0x9b,
            0x5a,
            0x80,
            0x6c,
            0xf6,
            0x34,
            0xc0,
            0x39,
            0x8d,
            0x8f,
            0x2d,
            0x89,
            0xfd,
            0x49,
            0xa9,
            0x1e,
            0xf3,
            0x3d,
            0xa4,
            0x74,
            0xcd,
            0x84,
            0x94,
            0xbb,
            0xa8,
            0xda,
            0x3b,
            0xf7
        ];

        let res = RLPTrait::decode(arr.span()).unwrap();

        // Remove the byte representing the data type
        arr.pop_front().expect('pop_front failed');
        let expected_item = [RLPItem::String(arr.span())].span();

        assert(res == expected_item, 'Wrong value');
    }

    #[test]
    fn test_rlp_decode_short_string_input_too_short() {
        let mut arr = array![
            0x9b,
            0x5a,
            0x80,
            0x6c,
            0xf6,
            0x34,
            0xc0,
            0x39,
            0x8d,
            0x8f,
            0x2d,
            0x89,
            0xfd,
            0x49,
            0xa9,
            0x1e,
            0xf3,
            0x3d,
            0xa4,
            0x74,
            0xcd,
            0x84,
            0x94,
            0xbb,
            0xa8,
            0xda,
            0x3b
        ];

        let res = RLPTrait::decode(arr.span());
        assert(res.is_err(), 'should return an RLPError');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_decode_long_string_with_payload_len_on_1_byte() {
        let mut arr = array![
            0xb8,
            0x3c,
            0xf7,
            0xa1,
            0x7e,
            0xf9,
            0x59,
            0xd4,
            0x88,
            0x38,
            0x8d,
            0xdc,
            0x34,
            0x7b,
            0x3a,
            0x10,
            0xdd,
            0x85,
            0x43,
            0x1d,
            0x0c,
            0x37,
            0x98,
            0x6a,
            0x63,
            0xbd,
            0x18,
            0xba,
            0xa3,
            0x8d,
            0xb1,
            0xa4,
            0x81,
            0x6f,
            0x24,
            0xde,
            0xc3,
            0xec,
            0x16,
            0x6e,
            0xb3,
            0xb2,
            0xac,
            0xc4,
            0xc4,
            0xf7,
            0x79,
            0x04,
            0xba,
            0x76,
            0x3c,
            0x67,
            0xc6,
            0xd0,
            0x53,
            0xda,
            0xea,
            0x10,
            0x86,
            0x19,
            0x7d,
            0xd9
        ];

        let res = RLPTrait::decode(arr.span()).unwrap();

        // Remove the bytes representing the data type and their length
        arr.pop_front().expect('pop_front failed');
        arr.pop_front().expect('pop_front failed');
        let expected_item = [RLPItem::String(arr.span())].span();

        assert(res == expected_item, 'Wrong value');
    }

    #[test]
    fn test_rlp_decode_long_string_with_input_too_short() {
        let mut arr = array![
            0xb8,
            0x3c,
            0xf7,
            0xa1,
            0x7e,
            0xf9,
            0x59,
            0xd4,
            0x88,
            0x38,
            0x8d,
            0xdc,
            0x34,
            0x7b,
            0x3a,
            0x10,
            0xdd,
            0x85,
            0x43,
            0x1d,
            0x0c,
            0x37,
            0x98,
            0x6a,
            0x63,
            0xbd,
            0x18,
            0xba,
            0xa3,
            0x8d,
            0xb1,
            0xa4,
            0x81,
            0x6f,
            0x24,
            0xde,
            0xc3,
            0xec,
            0x16,
            0x6e,
            0xb3,
            0xb2,
            0xac,
            0xc4,
            0xc4,
            0xf7,
            0x79,
            0x04,
            0xba,
            0x76,
            0x3c,
            0x67,
            0xc6,
            0xd0,
            0x53,
            0xda,
            0xea,
            0x10,
            0x86,
            0x19,
        ];

        let res = RLPTrait::decode(arr.span());
        assert(res.is_err(), 'should return an RLPError');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_decode_long_string_with_payload_len_on_2_bytes() {
        let mut arr = array![
            0xb9,
            0x01,
            0x02,
            0xf7,
            0xa1,
            0x7e,
            0xf9,
            0x59,
            0xd4,
            0x88,
            0x38,
            0x8d,
            0xdc,
            0x34,
            0x7b,
            0x3a,
            0x10,
            0xdd,
            0x85,
            0x43,
            0x1d,
            0x0c,
            0x37,
            0x98,
            0x6a,
            0x63,
            0xbd,
            0x18,
            0xba,
            0xa3,
            0x8d,
            0xb1,
            0xa4,
            0x81,
            0x6f,
            0x24,
            0xde,
            0xc3,
            0xec,
            0x16,
            0x6e,
            0xb3,
            0xb2,
            0xac,
            0xc4,
            0xc4,
            0xf7,
            0x79,
            0x04,
            0xba,
            0x76,
            0x3c,
            0x67,
            0xc6,
            0xd0,
            0x53,
            0xda,
            0xea,
            0x10,
            0x86,
            0x19,
            0x7d,
            0xd9,
            0x33,
            0x58,
            0x47,
            0x69,
            0x34,
            0x76,
            0x89,
            0x43,
            0x67,
            0x93,
            0x45,
            0x76,
            0x87,
            0x34,
            0x95,
            0x67,
            0x89,
            0x34,
            0x36,
            0x43,
            0x86,
            0x79,
            0x43,
            0x63,
            0x34,
            0x78,
            0x63,
            0x49,
            0x58,
            0x67,
            0x83,
            0x59,
            0x64,
            0x56,
            0x37,
            0x93,
            0x74,
            0x58,
            0x69,
            0x69,
            0x43,
            0x67,
            0x39,
            0x48,
            0x67,
            0x98,
            0x45,
            0x63,
            0x89,
            0x45,
            0x67,
            0x94,
            0x37,
            0x63,
            0x04,
            0x56,
            0x40,
            0x39,
            0x68,
            0x43,
            0x08,
            0x68,
            0x40,
            0x65,
            0x03,
            0x46,
            0x80,
            0x93,
            0x48,
            0x64,
            0x95,
            0x36,
            0x87,
            0x39,
            0x84,
            0x56,
            0x73,
            0x76,
            0x89,
            0x34,
            0x95,
            0x86,
            0x73,
            0x65,
            0x40,
            0x93,
            0x60,
            0x98,
            0x34,
            0x56,
            0x83,
            0x04,
            0x56,
            0x80,
            0x36,
            0x08,
            0x59,
            0x68,
            0x45,
            0x06,
            0x83,
            0x06,
            0x68,
            0x40,
            0x59,
            0x68,
            0x40,
            0x65,
            0x84,
            0x03,
            0x68,
            0x30,
            0x48,
            0x65,
            0x03,
            0x46,
            0x83,
            0x49,
            0x57,
            0x68,
            0x95,
            0x79,
            0x68,
            0x34,
            0x76,
            0x83,
            0x74,
            0x69,
            0x87,
            0x43,
            0x59,
            0x63,
            0x84,
            0x75,
            0x63,
            0x98,
            0x47,
            0x56,
            0x34,
            0x86,
            0x73,
            0x94,
            0x87,
            0x65,
            0x43,
            0x98,
            0x67,
            0x34,
            0x96,
            0x79,
            0x34,
            0x86,
            0x57,
            0x93,
            0x48,
            0x57,
            0x69,
            0x34,
            0x87,
            0x56,
            0x89,
            0x34,
            0x57,
            0x68,
            0x73,
            0x49,
            0x56,
            0x53,
            0x79,
            0x43,
            0x95,
            0x67,
            0x34,
            0x96,
            0x79,
            0x38,
            0x47,
            0x63,
            0x94,
            0x65,
            0x37,
            0x89,
            0x63,
            0x53,
            0x45,
            0x68,
            0x79,
            0x88,
            0x97,
            0x68,
            0x87,
            0x68,
            0x68,
            0x68,
            0x76,
            0x99,
            0x87,
            0x60
        ];

        let res = RLPTrait::decode(arr.span()).unwrap();

        // Remove the bytes representing the data type and their length
        arr.pop_front().expect('pop_front failed');
        arr.pop_front().expect('pop_front failed');
        arr.pop_front().expect('pop_front failed');
        let expected_item = [RLPItem::String(arr.span())].span();

        assert(res == expected_item, 'Wrong value');
    }


    #[test]
    fn test_rlp_decode_long_string_with_payload_len_too_short() {
        let mut arr = array![0xb9, 0x01,];

        let res = RLPTrait::decode(arr.span());
        assert(res.is_err(), 'should return an RLPError');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_decode_short_list() {
        let mut arr = array![0xc9, 0x83, 0x35, 0x35, 0x35, 0x42, 0x83, 0x45, 0x38, 0x92];
        let res = RLPTrait::decode(arr.span()).unwrap();

        let mut expected_0 = RLPItem::String([0x35, 0x35, 0x35].span());
        let mut expected_1 = RLPItem::String([0x42].span());
        let mut expected_2 = RLPItem::String([0x45, 0x38, 0x92].span());

        let expected_list = RLPItem::List([expected_0, expected_1, expected_2].span());

        assert(res == [expected_list].span(), 'Wrong value');
    }

    #[test]
    fn test_rlp_decode_short_nested_list() {
        let mut arr = array![0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0];
        let res = RLPTrait::decode(arr.span()).unwrap();

        let mut expected_0 = RLPItem::List([].span());
        let mut expected_1 = RLPItem::List([expected_0].span());
        let mut expected_2 = RLPItem::List([expected_0, expected_1].span());

        let expected = RLPItem::List([expected_0, expected_1, expected_2].span());

        assert(res == [expected].span(), 'Wrong value');
    }

    #[test]
    fn test_rlp_decode_multi_list() {
        let mut arr = array![0xc6, 0x82, 0x7a, 0x77, 0xc1, 0x04, 0x01,];

        let res = RLPTrait::decode(arr.span()).unwrap();

        let mut expected_0 = RLPItem::String([0x7a, 0x77].span());
        let mut expected_1 = RLPItem::String([0x04].span());
        let mut expected_1 = RLPItem::List([expected_1].span());
        let mut expected_2 = RLPItem::String([0x01].span());
        let mut expected = RLPItem::List([expected_0, expected_1, expected_2].span());

        assert(res == [expected].span(), 'Wrong value');
    }

    #[test]
    fn test_rlp_decode_short_list_with_input_too_short() {
        let mut arr = array![0xc9, 0x83, 0x35, 0x35, 0x89, 0x42, 0x83, 0x45, 0x38];

        let res = RLPTrait::decode(arr.span());
        assert(res.is_err(), 'should return an RLPError');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_decode_long_list() {
        let mut arr = array![
            0xf9,
            0x02,
            0x11,
            0xa0,
            0x77,
            0x70,
            0xcf,
            0x09,
            0xb5,
            0x06,
            0x7a,
            0x1b,
            0x35,
            0xdf,
            0x62,
            0xa9,
            0x24,
            0x89,
            0x81,
            0x75,
            0xce,
            0xae,
            0xec,
            0xad,
            0x1f,
            0x68,
            0xcd,
            0xb4,
            0xa8,
            0x44,
            0x40,
            0x0c,
            0x73,
            0xc1,
            0x4a,
            0xf4,
            0xa0,
            0x1e,
            0xa3,
            0x85,
            0xd0,
            0x5a,
            0xb2,
            0x61,
            0x46,
            0x6d,
            0x5c,
            0x04,
            0x87,
            0xfe,
            0x68,
            0x45,
            0x34,
            0xc1,
            0x9f,
            0x1a,
            0x4b,
            0x5c,
            0x4b,
            0x18,
            0xdc,
            0x1a,
            0x36,
            0x35,
            0x60,
            0x02,
            0x50,
            0x71,
            0xb4,
            0xa0,
            0x2c,
            0x4c,
            0x04,
            0xce,
            0x35,
            0x40,
            0xd3,
            0xd1,
            0x46,
            0x18,
            0x72,
            0x30,
            0x3c,
            0x53,
            0xa5,
            0xe5,
            0x66,
            0x83,
            0xc1,
            0x30,
            0x4f,
            0x8d,
            0x36,
            0xa8,
            0x80,
            0x0c,
            0x6a,
            0xf5,
            0xfa,
            0x3f,
            0xcd,
            0xee,
            0xa0,
            0xa9,
            0xdc,
            0x77,
            0x8d,
            0xc5,
            0x4b,
            0x7d,
            0xd3,
            0xc4,
            0x82,
            0x22,
            0xe7,
            0x39,
            0xd1,
            0x61,
            0xfe,
            0xb0,
            0xc0,
            0xee,
            0xce,
            0xb2,
            0xdc,
            0xd5,
            0x17,
            0x37,
            0xf0,
            0x5b,
            0x8e,
            0x37,
            0xa6,
            0x38,
            0x51,
            0xa0,
            0xa9,
            0x5f,
            0x4d,
            0x55,
            0x56,
            0xdf,
            0x62,
            0xdd,
            0xc2,
            0x62,
            0x99,
            0x04,
            0x97,
            0xae,
            0x56,
            0x9b,
            0xcd,
            0x8e,
            0xfd,
            0xda,
            0x7b,
            0x20,
            0x07,
            0x93,
            0xf8,
            0xd3,
            0xde,
            0x4c,
            0xdb,
            0x97,
            0x18,
            0xd7,
            0xa0,
            0x39,
            0xd4,
            0x06,
            0x6d,
            0x14,
            0x38,
            0x22,
            0x6e,
            0xaf,
            0x4a,
            0xc9,
            0xe9,
            0x43,
            0xa8,
            0x74,
            0xa9,
            0xa9,
            0xc2,
            0x5f,
            0xb0,
            0xd8,
            0x1d,
            0xb9,
            0x86,
            0x1d,
            0x8c,
            0x13,
            0x36,
            0xb3,
            0xe2,
            0x03,
            0x4c,
            0xa0,
            0x7a,
            0xcc,
            0x7c,
            0x63,
            0xb4,
            0x6a,
            0xa4,
            0x18,
            0xb3,
            0xc9,
            0xa0,
            0x41,
            0xa1,
            0x25,
            0x6b,
            0xcb,
            0x73,
            0x61,
            0x31,
            0x6b,
            0x39,
            0x7a,
            0xda,
            0x5a,
            0x88,
            0x67,
            0x49,
            0x1b,
            0xbb,
            0x13,
            0x01,
            0x30,
            0xa0,
            0x15,
            0x35,
            0x8a,
            0x81,
            0x25,
            0x2e,
            0xc4,
            0x93,
            0x71,
            0x13,
            0xfe,
            0x36,
            0xc7,
            0x80,
            0x46,
            0xb7,
            0x11,
            0xfb,
            0xa1,
            0x97,
            0x34,
            0x91,
            0xbb,
            0x29,
            0x18,
            0x7a,
            0x00,
            0x78,
            0x5f,
            0xf8,
            0x52,
            0xae,
            0xa0,
            0x68,
            0x91,
            0x42,
            0xd3,
            0x16,
            0xab,
            0xfa,
            0xa7,
            0x1c,
            0x8b,
            0xce,
            0xdf,
            0x49,
            0x20,
            0x1d,
            0xdb,
            0xb2,
            0x10,
            0x4e,
            0x25,
            0x0a,
            0xdc,
            0x90,
            0xc4,
            0xe8,
            0x56,
            0x22,
            0x1f,
            0x53,
            0x4a,
            0x96,
            0x58,
            0xa0,
            0xdc,
            0x36,
            0x50,
            0x99,
            0x25,
            0x34,
            0xfd,
            0xa8,
            0xa3,
            0x14,
            0xa7,
            0xdb,
            0xb0,
            0xae,
            0x3b,
            0xa8,
            0xc7,
            0x9d,
            0xb5,
            0x55,
            0x0c,
            0x69,
            0xce,
            0x2a,
            0x24,
            0x60,
            0xc0,
            0x07,
            0xad,
            0xc4,
            0xc1,
            0xa3,
            0xa0,
            0x20,
            0xb0,
            0x68,
            0x3b,
            0x66,
            0x55,
            0xb0,
            0x05,
            0x9e,
            0xe1,
            0x03,
            0xd0,
            0x4e,
            0x4b,
            0x50,
            0x6b,
            0xcb,
            0xc1,
            0x39,
            0x00,
            0x63,
            0x92,
            0xb7,
            0xda,
            0xb1,
            0x11,
            0x78,
            0xc2,
            0x66,
            0x03,
            0x42,
            0xe7,
            0xa0,
            0x8e,
            0xed,
            0xeb,
            0x45,
            0xfb,
            0x63,
            0x0f,
            0x1c,
            0xd9,
            0x97,
            0x36,
            0xeb,
            0x18,
            0x57,
            0x22,
            0x17,
            0xcb,
            0xc6,
            0xd5,
            0xf3,
            0x15,
            0xb7,
            0x1b,
            0xe2,
            0x03,
            0xb0,
            0x3c,
            0xe8,
            0xd9,
            0x9b,
            0x26,
            0x14,
            0xa0,
            0x79,
            0x23,
            0xa3,
            0x3d,
            0xf6,
            0x5a,
            0x98,
            0x6f,
            0xd5,
            0xe7,
            0xf9,
            0xe6,
            0xe4,
            0xc2,
            0xb9,
            0x69,
            0x73,
            0x6b,
            0x08,
            0x94,
            0x4e,
            0xbe,
            0x99,
            0x39,
            0x4a,
            0x86,
            0x14,
            0x61,
            0x2f,
            0xe6,
            0x09,
            0xf3,
            0xa0,
            0x65,
            0x34,
            0xd7,
            0xd0,
            0x1a,
            0x20,
            0x71,
            0x4a,
            0xa4,
            0xfb,
            0x2a,
            0x55,
            0xb9,
            0x46,
            0xce,
            0x64,
            0xc3,
            0x22,
            0x2d,
            0xff,
            0xad,
            0x2a,
            0xa2,
            0xd1,
            0x8a,
            0x92,
            0x34,
            0x73,
            0xc9,
            0x2a,
            0xb1,
            0xfd,
            0xa0,
            0xbf,
            0xf9,
            0xc2,
            0x8b,
            0xfe,
            0xb8,
            0xbf,
            0x2d,
            0xa9,
            0xb6,
            0x18,
            0xc8,
            0xc3,
            0xb0,
            0x6f,
            0xe8,
            0x0c,
            0xb1,
            0xc0,
            0xbd,
            0x14,
            0x47,
            0x38,
            0xf7,
            0xc4,
            0x21,
            0x61,
            0xff,
            0x29,
            0xe2,
            0x50,
            0x2f,
            0xa0,
            0x7f,
            0x14,
            0x61,
            0x69,
            0x3c,
            0x70,
            0x4e,
            0xa5,
            0x02,
            0x1b,
            0xbb,
            0xa3,
            0x5e,
            0x72,
            0xc5,
            0x02,
            0xf6,
            0x43,
            0x9e,
            0x45,
            0x8f,
            0x98,
            0x24,
            0x2e,
            0xd0,
            0x37,
            0x48,
            0xea,
            0x8f,
            0xe2,
            0xb3,
            0x5f,
            0x80
        ];
        let res = RLPTrait::decode(arr.span()).unwrap();

        let mut expected_0 = RLPItem::String(
            [
                0x77,
                0x70,
                0xcf,
                0x09,
                0xb5,
                0x06,
                0x7a,
                0x1b,
                0x35,
                0xdf,
                0x62,
                0xa9,
                0x24,
                0x89,
                0x81,
                0x75,
                0xce,
                0xae,
                0xec,
                0xad,
                0x1f,
                0x68,
                0xcd,
                0xb4,
                0xa8,
                0x44,
                0x40,
                0x0c,
                0x73,
                0xc1,
                0x4a,
                0xf4
            ].span()
        );
        let mut expected_1 = RLPItem::String(
            [
                0x1e,
                0xa3,
                0x85,
                0xd0,
                0x5a,
                0xb2,
                0x61,
                0x46,
                0x6d,
                0x5c,
                0x04,
                0x87,
                0xfe,
                0x68,
                0x45,
                0x34,
                0xc1,
                0x9f,
                0x1a,
                0x4b,
                0x5c,
                0x4b,
                0x18,
                0xdc,
                0x1a,
                0x36,
                0x35,
                0x60,
                0x02,
                0x50,
                0x71,
                0xb4
            ].span()
        );
        let mut expected_2 = RLPItem::String(
            [
                0x2c,
                0x4c,
                0x04,
                0xce,
                0x35,
                0x40,
                0xd3,
                0xd1,
                0x46,
                0x18,
                0x72,
                0x30,
                0x3c,
                0x53,
                0xa5,
                0xe5,
                0x66,
                0x83,
                0xc1,
                0x30,
                0x4f,
                0x8d,
                0x36,
                0xa8,
                0x80,
                0x0c,
                0x6a,
                0xf5,
                0xfa,
                0x3f,
                0xcd,
                0xee
            ].span()
        );
        let mut expected_3 = RLPItem::String(
            [
                0xa9,
                0xdc,
                0x77,
                0x8d,
                0xc5,
                0x4b,
                0x7d,
                0xd3,
                0xc4,
                0x82,
                0x22,
                0xe7,
                0x39,
                0xd1,
                0x61,
                0xfe,
                0xb0,
                0xc0,
                0xee,
                0xce,
                0xb2,
                0xdc,
                0xd5,
                0x17,
                0x37,
                0xf0,
                0x5b,
                0x8e,
                0x37,
                0xa6,
                0x38,
                0x51
            ].span()
        );
        let mut expected_4 = RLPItem::String(
            [
                0xa9,
                0x5f,
                0x4d,
                0x55,
                0x56,
                0xdf,
                0x62,
                0xdd,
                0xc2,
                0x62,
                0x99,
                0x04,
                0x97,
                0xae,
                0x56,
                0x9b,
                0xcd,
                0x8e,
                0xfd,
                0xda,
                0x7b,
                0x20,
                0x07,
                0x93,
                0xf8,
                0xd3,
                0xde,
                0x4c,
                0xdb,
                0x97,
                0x18,
                0xd7
            ].span()
        );
        let mut expected_5 = RLPItem::String(
            [
                0x39,
                0xd4,
                0x06,
                0x6d,
                0x14,
                0x38,
                0x22,
                0x6e,
                0xaf,
                0x4a,
                0xc9,
                0xe9,
                0x43,
                0xa8,
                0x74,
                0xa9,
                0xa9,
                0xc2,
                0x5f,
                0xb0,
                0xd8,
                0x1d,
                0xb9,
                0x86,
                0x1d,
                0x8c,
                0x13,
                0x36,
                0xb3,
                0xe2,
                0x03,
                0x4c
            ].span()
        );
        let mut expected_6 = RLPItem::String(
            [
                0x7a,
                0xcc,
                0x7c,
                0x63,
                0xb4,
                0x6a,
                0xa4,
                0x18,
                0xb3,
                0xc9,
                0xa0,
                0x41,
                0xa1,
                0x25,
                0x6b,
                0xcb,
                0x73,
                0x61,
                0x31,
                0x6b,
                0x39,
                0x7a,
                0xda,
                0x5a,
                0x88,
                0x67,
                0x49,
                0x1b,
                0xbb,
                0x13,
                0x01,
                0x30
            ].span()
        );
        let mut expected_7 = RLPItem::String(
            [
                0x15,
                0x35,
                0x8a,
                0x81,
                0x25,
                0x2e,
                0xc4,
                0x93,
                0x71,
                0x13,
                0xfe,
                0x36,
                0xc7,
                0x80,
                0x46,
                0xb7,
                0x11,
                0xfb,
                0xa1,
                0x97,
                0x34,
                0x91,
                0xbb,
                0x29,
                0x18,
                0x7a,
                0x00,
                0x78,
                0x5f,
                0xf8,
                0x52,
                0xae
            ].span()
        );
        let mut expected_8 = RLPItem::String(
            [
                0x68,
                0x91,
                0x42,
                0xd3,
                0x16,
                0xab,
                0xfa,
                0xa7,
                0x1c,
                0x8b,
                0xce,
                0xdf,
                0x49,
                0x20,
                0x1d,
                0xdb,
                0xb2,
                0x10,
                0x4e,
                0x25,
                0x0a,
                0xdc,
                0x90,
                0xc4,
                0xe8,
                0x56,
                0x22,
                0x1f,
                0x53,
                0x4a,
                0x96,
                0x58
            ].span()
        );
        let mut expected_9 = RLPItem::String(
            [
                0xdc,
                0x36,
                0x50,
                0x99,
                0x25,
                0x34,
                0xfd,
                0xa8,
                0xa3,
                0x14,
                0xa7,
                0xdb,
                0xb0,
                0xae,
                0x3b,
                0xa8,
                0xc7,
                0x9d,
                0xb5,
                0x55,
                0x0c,
                0x69,
                0xce,
                0x2a,
                0x24,
                0x60,
                0xc0,
                0x07,
                0xad,
                0xc4,
                0xc1,
                0xa3
            ].span()
        );
        let mut expected_10 = RLPItem::String(
            [
                0x20,
                0xb0,
                0x68,
                0x3b,
                0x66,
                0x55,
                0xb0,
                0x05,
                0x9e,
                0xe1,
                0x03,
                0xd0,
                0x4e,
                0x4b,
                0x50,
                0x6b,
                0xcb,
                0xc1,
                0x39,
                0x00,
                0x63,
                0x92,
                0xb7,
                0xda,
                0xb1,
                0x11,
                0x78,
                0xc2,
                0x66,
                0x03,
                0x42,
                0xe7
            ].span()
        );
        let mut expected_11 = RLPItem::String(
            [
                0x8e,
                0xed,
                0xeb,
                0x45,
                0xfb,
                0x63,
                0x0f,
                0x1c,
                0xd9,
                0x97,
                0x36,
                0xeb,
                0x18,
                0x57,
                0x22,
                0x17,
                0xcb,
                0xc6,
                0xd5,
                0xf3,
                0x15,
                0xb7,
                0x1b,
                0xe2,
                0x03,
                0xb0,
                0x3c,
                0xe8,
                0xd9,
                0x9b,
                0x26,
                0x14
            ].span()
        );
        let mut expected_12 = RLPItem::String(
            [
                0x79,
                0x23,
                0xa3,
                0x3d,
                0xf6,
                0x5a,
                0x98,
                0x6f,
                0xd5,
                0xe7,
                0xf9,
                0xe6,
                0xe4,
                0xc2,
                0xb9,
                0x69,
                0x73,
                0x6b,
                0x08,
                0x94,
                0x4e,
                0xbe,
                0x99,
                0x39,
                0x4a,
                0x86,
                0x14,
                0x61,
                0x2f,
                0xe6,
                0x09,
                0xf3
            ].span()
        );
        let mut expected_13 = RLPItem::String(
            [
                0x65,
                0x34,
                0xd7,
                0xd0,
                0x1a,
                0x20,
                0x71,
                0x4a,
                0xa4,
                0xfb,
                0x2a,
                0x55,
                0xb9,
                0x46,
                0xce,
                0x64,
                0xc3,
                0x22,
                0x2d,
                0xff,
                0xad,
                0x2a,
                0xa2,
                0xd1,
                0x8a,
                0x92,
                0x34,
                0x73,
                0xc9,
                0x2a,
                0xb1,
                0xfd
            ].span()
        );
        let mut expected_14 = RLPItem::String(
            [
                0xbf,
                0xf9,
                0xc2,
                0x8b,
                0xfe,
                0xb8,
                0xbf,
                0x2d,
                0xa9,
                0xb6,
                0x18,
                0xc8,
                0xc3,
                0xb0,
                0x6f,
                0xe8,
                0x0c,
                0xb1,
                0xc0,
                0xbd,
                0x14,
                0x47,
                0x38,
                0xf7,
                0xc4,
                0x21,
                0x61,
                0xff,
                0x29,
                0xe2,
                0x50,
                0x2f
            ].span()
        );
        let mut expected_15 = RLPItem::String(
            [
                0x7f,
                0x14,
                0x61,
                0x69,
                0x3c,
                0x70,
                0x4e,
                0xa5,
                0x02,
                0x1b,
                0xbb,
                0xa3,
                0x5e,
                0x72,
                0xc5,
                0x02,
                0xf6,
                0x43,
                0x9e,
                0x45,
                0x8f,
                0x98,
                0x24,
                0x2e,
                0xd0,
                0x37,
                0x48,
                0xea,
                0x8f,
                0xe2,
                0xb3,
                0x5f
            ].span()
        );

        let mut expected_16 = RLPItem::String([].span());

        let mut expected = array![
            expected_0,
            expected_1,
            expected_2,
            expected_3,
            expected_4,
            expected_5,
            expected_6,
            expected_7,
            expected_8,
            expected_9,
            expected_10,
            expected_11,
            expected_12,
            expected_13,
            expected_14,
            expected_15,
            expected_16
        ];

        let expected_item = RLPItem::List(expected.span());

        assert(res == [expected_item].span(), 'Wrong value');
    }

    #[test]
    fn test_rlp_decode_long_list_with_input_too_short() {
        let mut arr = array![
            0xf9,
            0x02,
            0x11,
            0xa0,
            0x77,
            0x70,
            0xcf,
            0x09,
            0xb5,
            0x06,
            0x7a,
            0x1b,
            0x35,
            0xdf,
            0x62,
            0xa9,
            0x24,
            0x89,
            0x81,
            0x75,
            0xce,
            0xae,
            0xec,
            0xad,
            0x1f,
            0x68,
            0xcd,
            0xb4
        ];

        let res = RLPTrait::decode(arr.span());
        assert(res.is_err(), 'should return an RLPError');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_decode_long_list_with_len_too_short() {
        let mut arr = array![0xf9, 0x02,];

        let res = RLPTrait::decode(arr.span());
        assert(res.is_err(), 'should return an RLPError');
        assert!(res.unwrap_err() == RLPError::InputTooShort);
    }

    #[test]
    fn test_rlp_item_parse_access_list() {
        // [ [ "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", [ "0x01", "0x02", "0x03", "0x04",
        // "0x05" ] ]]
        let rlp_encoded_access_list: Span<u8> = [
            220,
            219,
            148,
            31,
            152,
            64,
            168,
            93,
            90,
            245,
            191,
            29,
            23,
            98,
            249,
            37,
            189,
            173,
            220,
            66,
            1,
            249,
            132,
            197,
            1,
            2,
            3,
            4,
            5
        ].span();
        let decoded_data = RLPTrait::decode(rlp_encoded_access_list).unwrap();
        assert_eq!(decoded_data.len(), 1);

        let rlp_item = *decoded_data[0];

        let expected_access_list_item = AccessListItem {
            ethereum_address: 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap(),
            storage_keys: [
                0x1, 0x2, 0x3, 0x4, 0x5
            ].span()
        };

        let expected_access_list = [expected_access_list_item].span();

        let res = rlp_item.parse_access_list().unwrap();
        assert_eq!(res.len(), 1);

        assert!(res == expected_access_list, "access list are not equal");
    }
}
