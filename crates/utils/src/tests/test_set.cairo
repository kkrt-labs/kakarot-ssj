use utils::set::{Set, SetTrait};

#[test]
fn test_add() {
    let mut set: Set<u8> = Default::default();
    set.add(1);
    set.add(2);
    set.add(3);
    set.add(3);
    assert_eq!(set.len(), 3);
    assert_eq!(set.contains(1), true);
    assert_eq!(set.contains(2), true);
    assert_eq!(set.contains(3), true);
    assert_eq!(set.contains(4), false);
}
