use utils::bitwise::right_shift;

type Byte = u8;

#[generate_trait]
impl ByteImpl of ByteTrait {
    // @notice Extracts the high and low nibbles from a byte
    // @return (high, low)
    fn extract_nibbles(self: Byte) -> (Byte, Byte) {
        let masked = self & 0xf0;
        let high = right_shift(masked, 4);
        let low = self & 0x0f;

        (high, low)
    }
}
