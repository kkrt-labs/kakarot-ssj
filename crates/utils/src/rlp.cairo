use result::ResultTrait;
use option::OptionTrait;
use array::{Array, ArrayTrait, Span, SpanTrait};
use clone::Clone;
use traits::{Into, TryInto};
use utils::helpers::SpanU8TryIntoU32;
use utils::errors::{RLPError, RLP_INVALID_LENGTH};

// @notice Enum with all possible RLP types
#[derive(Drop, PartialEq)]
enum RLPType {
    String,
    StringShort,
    StringLong,
    ListShort,
    ListLong,
}

#[generate_trait]
impl RLPTypeImpl of RLPTypeTrait {
    // @notice Returns RLPType from the leading byte
    // @param byte Leading byte
    // @return Result with RLPType
    fn from_byte(byte: u8) -> RLPType {
        if byte <= 0x7f {
            RLPType::String(())
        } else if byte <= 0xb7 {
            RLPType::StringShort(())
        } else if byte <= 0xbf {
            RLPType::StringLong(())
        } else if byte <= 0xf7 {
            RLPType::ListShort(())
        } else {
            RLPType::ListLong(())
        }
    }
}

// @notice Represent a RLP item
#[derive(Drop, PartialEq)]
enum RLPItem {
    Bytes: Span<u8>,
    // Should be Span<RLPItem> to allow for any depth/recursion, not yet supported by the compiler
    List: Span<Span<u8>>
}

// @notice RLP decodes a rlp encoded byte array
// as described in https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
// @param input RLP encoded bytes
// @return Result with RLPItem and size of the decoded item
fn rlp_decode(input: Span<u8>) -> Result<(RLPItem, usize), RLPError> {
    if input.len() == 0 {
        return Result::Err(RLPError::RlpInvalidLength(RLP_INVALID_LENGTH));
    }
    let prefix = *input.at(0);

    let rlp_type = RLPTypeTrait::from_byte(prefix);
    match rlp_type {
        RLPType::String(()) => {
            let mut arr = array![prefix];
            Result::Ok((RLPItem::Bytes(arr.span()), 1))
        },
        RLPType::StringShort(()) => {
            let len = prefix.into() - 0x80;
            let res = input.slice(1, len);

            Result::Ok((RLPItem::Bytes(res), 1 + len))
        },
        RLPType::StringLong(()) => {
            // Extract the amount of bytes representing the data payload length
            let len_len = prefix.into() - 0xb7;
            let len_span = input.slice(1, len_len);

            // Bytes => u32
            let len: u32 = len_span.try_into().unwrap();
            let res = input.slice(1 + len_len, len);

            Result::Ok((RLPItem::Bytes(res), 1 + len_len + len))
        },
        RLPType::ListShort(()) => {
            let len = prefix.into() - 0xc0;
            let mut in = input.slice(1, len);
            let res = rlp_decode_list(ref in);
            Result::Ok((RLPItem::List(res), 1 + len))
        },
        RLPType::ListLong(()) => {
            // Extract the amount of bytes representing the data payload length
            let len_len = prefix.into() - 0xf7;
            let len_span = input.slice(1, len_len);

            // Bytes => u32
            let len: u32 = len_span.try_into().unwrap();
            let mut in = input.slice(1 + len_len, len);
            let res = rlp_decode_list(ref in);
            Result::Ok((RLPItem::List(res), 1 + len_len + len))
        }
    }
}

fn rlp_decode_list(ref input: Span<u8>) -> Span<Span<u8>> {
    let mut i = 0;
    let len = input.len();
    let mut output = ArrayTrait::new();

    loop {
        if i >= len {
            break ();
        }

        let (decoded, decoded_len) = rlp_decode(input).unwrap();
        match decoded {
            RLPItem::Bytes(b) => {
                output.append(b);
                input = input.slice(decoded_len, input.len() - decoded_len);
            },
            RLPItem::List(_) => { panic_with_felt252('Recursive list not supported'); }
        }
        i += decoded_len;
    };
    output.span()
}
