use core::starknet::EthAddress;
use crate::math::Bitshift;
use crate::traits::EthAddressIntoU256;

#[generate_trait]
pub impl EthAddressExImpl of EthAddressExTrait {
    /// Converts an EthAddress to an array of bytes.
    ///
    /// # Returns
    ///
    /// * `Array<u8>` - A 20-byte array representation of the EthAddress.
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

    /// Converts a 20-byte array into an EthAddress.
    ///
    /// # Arguments
    ///
    /// * `input` - A `Span<u8>` of length 20 representing the bytes of an Ethereum address.
    ///
    /// # Returns
    ///
    /// * `Option<EthAddress>` - `Some(EthAddress)` if the conversion succeeds, `None` if the input
    /// length is not 20.
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

#[cfg(test)]
mod tests {
    use core::starknet::EthAddress;
    use super::EthAddressExTrait;
    #[test]
    fn test_eth_address_to_bytes() {
        let eth_address: EthAddress = 0x1234567890123456789012345678901234567890
            .try_into()
            .unwrap();
        let bytes = eth_address.to_bytes();
        assert_eq!(
            bytes.span(),
            [
                0x12,
                0x34,
                0x56,
                0x78,
                0x90,
                0x12,
                0x34,
                0x56,
                0x78,
                0x90,
                0x12,
                0x34,
                0x56,
                0x78,
                0x90,
                0x12,
                0x34,
                0x56,
                0x78,
                0x90
            ].span()
        );
    }

    #[test]
    fn test_eth_address_from_bytes() {
        let bytes = [
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90
        ].span();
        let eth_address = EthAddressExTrait::from_bytes(bytes);
        assert_eq!(
            eth_address,
            Option::Some(0x1234567890123456789012345678901234567890.try_into().unwrap())
        );
    }

    #[test]
    fn test_eth_address_from_bytes_invalid_length() {
        let bytes = [
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12,
            0x34,
            0x56,
            0x78,
            0x90,
            0x12
        ];
        let eth_address = EthAddressExTrait::from_bytes(bytes.span());
        assert_eq!(eth_address, Option::None);
    }
}
