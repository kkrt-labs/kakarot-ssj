use utils::i256::{i256};

#[test]
#[available_gas(20000000)]
fn test_i256_positive() {
    let val: i256 = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256.into();

    assert(val > 0_u256.into(), 'i256 should be positive');
}

#[test]
#[available_gas(20000000)]
fn test_i256_negative() {
    let val: i256 = 0x8000000000000000000000000000000000000000000000000000000000000000_u256.into();

    assert(val < 0_u256.into(), 'i256 should be negative');
}

#[test]
#[available_gas(20000000)]
fn test_slt() {
    // https://github.com/ethereum/go-ethereum/blob/master/core/vm/testdata/testcases_slt.json
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x0000000000000000000000000000000000000000000000000000000000000005_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000000_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0x8000000000000000000000000000000000000000000000000000000000000001_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        true
    );
    assert_slt(
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        Into::<u256, i256>::into(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
        false
    );
}

fn assert_slt(a: i256, b: i256, expected: bool) {
    assert(a < b == expected, 'slt failed');
}
