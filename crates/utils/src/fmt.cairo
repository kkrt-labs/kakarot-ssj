use core::fmt::{Display, Debug, Formatter, Error};
use starknet::{EthAddress, ContractAddress};
use utils::set::{SpanSet, SpanSetTrait};
use utils::traits::EthSignature;

mod display_felt252_based {
    use core::fmt::{Display, Formatter, Error};
    use core::to_byte_array::AppendFormattedToByteArray;
    impl TDisplay<T, +Into<T, felt252>, +Copy<T>> of Display<T> {
        fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
            let value: felt252 = (*self).into();
            let base: felt252 = 10_u8.into();
            value.append_formatted_to_byte_array(ref f.buffer, base.try_into().unwrap());
            Result::Ok(())
        }
    }
}

mod debug_display_based {
    use core::fmt::{Display, Debug, Formatter, Error};
    use core::to_byte_array::AppendFormattedToByteArray;
    impl TDisplay<T, +Display<T>> of Debug<T> {
        fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
            Display::fmt(self, ref f)
        }
    }
}

impl EthAddressDisplay = display_felt252_based::TDisplay<EthAddress>;
impl ContractAddressDisplay = display_felt252_based::TDisplay<ContractAddress>;
impl EthAddressDebug = debug_display_based::TDisplay<EthAddress>;
impl ContractAddressDebug = debug_display_based::TDisplay<ContractAddress>;

impl EthSignatureDebug of Debug<EthSignature> {
    fn fmt(self: @EthSignature, ref f: Formatter) -> Result<(), Error> {
        write!(f, "r: {}", *self.r)?;
        write!(f, "s: {}", *self.s)?;
        write!(f, "y_parity: {}", *self.y_parity)?;

        Result::Ok(())
    }
}

impl TSpanSetDebug<T, +Debug<T>, +Copy<T>, +Drop<T>> of Debug<SpanSet<T>> {
    fn fmt(self: @SpanSet<T>, ref f: Formatter) -> Result<(), Error> {
        // For a reason I don't understand, the following code doesn't compile:
        // Debug::fmt(@(*self.to_span())sc, ref f)
        let mut self = (*self).to_span();
        write!(f, "[")?;
        loop {
            match self.pop_front() {
                Option::Some(value) => {
                    if Debug::fmt(value, ref f).is_err() {
                        break Result::Err(Error {});
                    };
                    if self.is_empty() {
                        break Result::Ok(());
                    }
                    if write!(f, ", ").is_err() {
                        break Result::Err(Error {});
                    };
                },
                Option::None => { break Result::Ok(()); }
            };
        }?;
        write!(f, "]")
    }
}
