use cairo_lib::hashing::poseidon::PoseidonHasher;

#[test]
#[available_gas(99999999)]
fn test_poseidon_hash_double() {
    let a = 0x6109f1949f6a7555eccf4e15ce1f10fbd78091dfe715cc2e0c5a244d9d17761;
    let b = 0x0194791558611599fe4ae0fcfa48f095659c90db18e54de86f2d2f547f7369bf;
    let hash = PoseidonHasher::hash_double(a, b);

    let res = 0x7b8180db85fa1e0b5041f38f57926743905702c498576991f04998b5d9476b4;
    assert(hash == res, 'Hash does not match');
}
