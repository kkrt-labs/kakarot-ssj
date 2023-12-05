use utils::set::{Set, SetTrait, SpanSet, SpanSetTrait};

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

#[test]
fn test_clone() {
    let mut set: Set<u8> = Default::default();
    set.add(1);
    set.add(2);
    set.add(3);
    set.add(3);
    let mut set2 = set.clone();
    assert!(set == set2);
    set2.add(4);
    assert_eq!(set.len(), 3);
    assert_eq!(set2.len(), 4);
    assert_eq!(set.contains(1), true);
    assert_eq!(set.contains(2), true);
    assert_eq!(set.contains(3), true);
    assert_eq!(set.contains(4), false);
    assert_eq!(set2.contains(1), true);
    assert_eq!(set2.contains(2), true);
    assert_eq!(set2.contains(3), true);
    assert_eq!(set2.contains(4), true);
}

#[test]
fn test_spanset_clone_set() {
    let mut set: Set<u8> = Default::default();
    set.add(1);
    set.add(2);
    let span_set = SpanSet { inner: @set };
    let set2 = span_set.clone_set();
    assert!(set == set2);
}

#[test]
fn test_set_extend() {
    let mut other: Set<u8> = Default::default();
    other.add(2);
    other.add(1);
    let other = other.spanset();

    let mut set: Set<u8> = Default::default();
    set.add(3);
    set.add(4);
    set.extend(other);

    assert_eq!(set.len(), 4);
    assert_eq!(set.contains(1), true);
    assert_eq!(set.contains(2), true);
    assert_eq!(set.contains(3), true);
    assert_eq!(set.contains(4), true);
    assert_eq!(set.contains(5), false);
}
