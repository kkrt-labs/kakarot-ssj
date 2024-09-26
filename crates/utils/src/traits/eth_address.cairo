use core::starknet::EthAddress;
use crate::math::Bitshift;
use crate::traits::EthAddressIntoU256;

#[generate_trait]
pub impl EthAddressExImpl of EthAddressExTrait {
    fn to_bytes(self: EthAddress) -> Array<u8> {
        let bytes_used: u256 = 20;
        let value: u256 = self.into();
        let mut bytes: Array<u8> = Default::default();
        let mut i = 0;
        while i != bytes_used {
            let val = value.shr(8 * (bytes_used - i - 1));
            bytes.append((val & 0xFF).try_into().unwrap());
            i += 1;
        };

        bytes
    }

    /// Packs 20 bytes into a EthAddress
    /// # Arguments
    /// * `input` a Span<u8> of len == 20
    /// # Returns
    /// * Option::Some(EthAddress) if the operation succeeds
    /// * Option::None otherwise
    fn from_bytes(input: Span<u8>) -> Option<EthAddress> {
        let len = input.len();
        if len != 20 {
            return Option::None;
        }
        let offset: u32 = len - 1;
        let mut result: u256 = 0;
        let mut i: u32 = 0;
        while i != len {
            let byte: u256 = (*input.at(i)).into();
            result += byte.shl((8 * (offset - i)).into());

            i += 1;
        };
        result.try_into()
    }
}
