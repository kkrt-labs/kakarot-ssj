use utils::num::{U8SizeOf, U64SizeOf, Felt252SizeOf, SizeOf};

#[test]
fn test_sizeof() {
    assert(10_u8.size_of() == 8, 'should be 8');
    assert(100_u8.size_of() == 8, 'should be 8');
    assert(20_u256.size_of() == 256, 'should be 256');
    assert(32_felt252.size_of() == 252, 'should be 252');
    assert(1_usize.size_of() == 32, 'should be 32');
}

#[test]
fn test_size() {
    assert(U8SizeOf::size() == 8, 'should be 8');
    assert(U64SizeOf::size() == 64, 'should be 64');
    assert(Felt252SizeOf::size() == 252, 'should be 252');
}
