use core::starknet::secp256_trait::{Signature};
use utils::eth_transaction::{
    TransactionType, EthereumTransaction, EthereumTransactionTrait, LegacyTransaction
};
use utils::traits::BoolIntoNumeric;

pub fn deserialize_signature(signature: Span<felt252>, chain_id: u128) -> Option<Signature> {
    let r_low: u128 = (*signature.at(0)).try_into()?;
    let r_high: u128 = (*signature.at(1)).try_into()?;

    let s_low: u128 = (*signature.at(2)).try_into()?;
    let s_high: u128 = (*signature.at(3)).try_into()?;

    let v: u128 = (*signature.at(4)).try_into()?;

    let y_parity = if (v == 0 || v == 1) {
        true
    } else {
        compute_y_parity(v, chain_id)?
    };

    Option::Some(
        Signature {
            r: u256 { low: r_low, high: r_high }, s: u256 { low: s_low, high: s_high }, y_parity,
        }
    )
}

fn compute_y_parity(v: u128, chain_id: u128) -> Option<bool> {
    let y_parity = v - (chain_id * 2 + 35);
    if (y_parity == 0 || y_parity == 1) {
        return Option::Some(y_parity == 1);
    }

    return Option::None;
}

fn serialize_transaction_signature(
    sig: Signature, tx_type: TransactionType, chain_id: u128
) -> Array<felt252> {
    let mut res: Array<felt252> = array![
        sig.r.low.into(), sig.r.high.into(), sig.s.low.into(), sig.s.high.into()
    ];

    let value = match tx_type {
        TransactionType::Legacy => { sig.y_parity.into() + 2 * chain_id + 35 },
        TransactionType::EIP2930 => { sig.y_parity.into() },
        TransactionType::EIP1559 => { sig.y_parity.into() }
    };

    res.append(value.into());
    res
}

fn deserialize_bytes(self: Span<felt252>) -> Option<Array<u8>> {
    let mut i = 0;
    let mut bytes: Array<u8> = Default::default();

    loop {
        if (i == self.len()) {
            break ();
        };

        let v: Option<u8> = (*self[i]).try_into();

        match v {
            Option::Some(v) => { bytes.append(v); },
            Option::None => { break (); }
        }

        i += 1;
    };

    // it means there was an error in the above loop
    if (i != self.len()) {
        Option::None
    } else {
        Option::Some(bytes)
    }
}

fn serialize_bytes(self: Span<u8>) -> Array<felt252> {
    let mut array: Array<felt252> = Default::default();

    let mut i = 0;

    loop {
        if (i == self.len()) {
            break ();
        }

        let value: felt252 = (*self[i]).into();
        array.append(value);

        i += 1;
    };

    array
}
