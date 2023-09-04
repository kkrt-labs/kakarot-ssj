use cairo_lib::hashing::keccak::KeccakTrait;
use array::ArrayTrait;
use debug::PrintTrait;

#[test]
#[available_gas(99999999)]
fn test_keccak_cairo_full_byte() {
    let mut input = array![0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff];

    let res = KeccakTrait::keccak_cairo(input.span());
    assert(
        res == 0xAF7D4E460ACF8E540E682A9EE91EA1C08C1615C3889D75EB0A70660A4BFB0BAD,
        'Keccak output not matching'
    );
}

#[test]
#[available_gas(99999999)]
fn test_keccak_cairo_empty_bytes() {
    let mut input = array![];

    let mut res = KeccakTrait::keccak_cairo(input.span());
    res.low = integer::u128_byte_reverse(res.low);
    res.high = integer::u128_byte_reverse(res.high);
    let tmp = res.low;
    res.low = res.high;
    res.high = tmp;
    assert(
        res == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,
        'Keccak output not matching'
    );
}

#[test]
#[available_gas(99999999)]
fn test_keccak_cairo_32_bytes() {
    let mut input = array![];
    input.append(0xFA);
    input.append(0xFA);
    input.append(0xFA);
    input.append(0xFA);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
    input.append(0x00);
}

#[test]
#[available_gas(99999999999)]
fn test_keccak_cairo_lot_of_bytes() {
    let mut input = array![];

    let mut memDst: u32 = 0;
    loop {
        if memDst >= 0x0C80 {
            break;
        }
        input.append(0xFA);
        input.append(0xFA);
        input.append(0xFA);
        input.append(0xFA);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        input.append(0x00);
        memDst += 0x20;
    };
}

#[test]
#[available_gas(99999999)]
fn test_keccak_cairo_remainder() {
    let mut input = array![0xab, 0x76, 0x8c, 0xf7, 0x89, 0xae, 0xfd, 0x23, 0x4a, 0xbc, 0xd2, 0x45];

    let res = KeccakTrait::keccak_cairo(input.span());
    assert(
        res == 0x82CBD5B00CD06A188C831D69CB9629C92A2D5E7A78CEA913C5F9AFF62E66BBB9,
        'Keccak output not matching'
    );
}
