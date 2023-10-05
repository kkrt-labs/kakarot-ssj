use utils::helpers;
use utils::helpers::{
    SpanExtension, SpanExtensionTrait, ArrayExtension, ArrayExtensionTrait, U256Trait
};
use utils::eth_transaction::{EthTransactionTrait, EthereumTransaction};
use debug::PrintTrait;

#[test]
#[available_gas(2000000000)]
fn test_decode() {
    let mut a = helpers::u256_to_bytes_array(
        0xec098504a817c800825208943535353535353535353535353535353535353535
    );
    let b = helpers::u256_to_bytes_array(0x880de0b6b3a764000080018080);
    ArrayExtension::concat(ref a, b.span().slice(32 - 13, 13));

    let r = 18515461264373351373200002665853028612451056578545711640558177340181847433846;
    let s = 46948507304638947509940763649030358759909902576025900602547168820602576006531;
    let v = 37;

    let eth_transaction = EthTransactionTrait::decode(a.span(), r, s, v);

    assert(eth_transaction.nonce == 9, 'wrong nonce');
    assert(eth_transaction.gas_price == 20000000000, 'wrong gas_price');
    assert(eth_transaction.gas_limit == 21000, 'wrong gas_limit');
    assert(
        eth_transaction.destination.into() == 0x3535353535353535353535353535353535353535,
        'wrong destination'
    );
    assert(eth_transaction.amount == 1000000000000000000, 'wrong amount');
    assert(eth_transaction.payload.len() == 0, 'wrong payload size');
}
/// example taken from : https://eips.ethereum.org/EIPS/eip-155
/// chainId : 1
/// nonce : 9
/// gasprice : 20000000000
/// startgas  : 21000
/// to  : 0x3535353535353535353535353535353535353535
/// value  : 1000000000000000000
/// data : []
/// r = 18515461264373351373200002665853028612451056578545711640558177340181847433846;
/// s = 46948507304638947509940763649030358759909902576025900602547168820602576006531;
/// v = 37;
/// privkey = 0x4646464646464646464646464646464646464646464646464646464646464646
/// signing data : 0xec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080
/// signing hash : 0xdaf5a779ae972f972197303d7b574746c7ef83eadac0f2791ad23db92e4c8e53
/// signed tx : 0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83


