use utils::helpers::{SpanExtTrait, ArrayExtTrait};

#[derive(Drop, PartialEq)]
pub struct Set<T> {
    inner: Array<T>
}

pub impl SetDefault<T, +Drop<T>> of Default<Set<T>> {
    #[inline]
    fn default() -> Set<T> {
        let arr: Array<T> = Default::default();
        Set { inner: arr }
    }
}

#[generate_trait]
pub impl SetImpl<T, +Drop<T>, +Copy<T>> of SetTrait<T> {
    #[inline]
    fn new() -> Set<T> {
        Set { inner: Default::default() }
    }

    fn from_array(arr: Array<T>) -> Set<T> {
        Set { inner: arr }
    }

    #[inline]
    fn add<+PartialEq<T>>(ref self: Set<T>, item: T) {
        self.inner.append_unique(item);
    }


    #[inline]
    fn extend<+PartialEq<T>>(ref self: Set<T>, other: SpanSet<T>) {
        self.extend_from_span(other.to_span());
    }

    #[inline]
    fn extend_from_span<+PartialEq<T>>(ref self: Set<T>, mut other: Span<T>) {
        for v in other {
            self.add(*v);
        };
    }

    #[inline]
    fn contains<+PartialEq<T>>(self: @Set<T>, item: T) -> bool {
        self.inner.span().contains(item)
    }

    #[inline]
    fn to_array(self: Set<T>) -> Array<T> {
        self.inner
    }

    #[inline]
    fn to_span(self: @Set<T>) -> Span<T> {
        self.inner.span()
    }

    #[inline]
    fn spanset(self: @Set<T>) -> SpanSet<T> {
        SpanSet { inner: self }
    }

    #[inline]
    fn len(self: @Set<T>) -> usize {
        self.inner.span().len()
    }
}

pub impl SetTCloneImpl<T, +Clone<T>, +Drop<T>, +PartialEq<T>, +Copy<T>> of Clone<Set<T>> {
    fn clone(self: @Set<T>) -> Set<T> {
        let mut response: Array<T> = Default::default();
        let mut span = self.to_span();
        for v in span {
            response.append(*v);
        };
        Set { inner: response }
    }
}

#[derive(Copy, Drop, PartialEq)]
pub struct SpanSet<T> {
    inner: @Set<T>
}

pub impl SpanSetDefault<T, +Drop<T>> of Default<SpanSet<T>> {
    #[inline]
    fn default() -> SpanSet<T> {
        let set: Set<T> = Default::default();
        SpanSet { inner: @set }
    }
}


// pub impl SpanSetCopy<T> of Copy<SpanSet<T>>;
// pub impl SpanSetDrop<T> of Drop<SpanSet<T>>;

#[generate_trait]
pub impl SpanSetImpl<T, +Copy<T>, +Drop<T>> of SpanSetTrait<T> {
    #[inline]
    fn contains<+PartialEq<T>>(self: SpanSet<T>, item: T) -> bool {
        self.inner.contains(item)
    }

    #[inline]
    fn to_span(self: SpanSet<T>) -> Span<T> {
        self.inner.to_span()
    }

    fn clone_set(self: SpanSet<T>) -> Set<T> {
        let mut response: Array<T> = Default::default();
        let mut span = self.to_span();
        for v in span {
            response.append(*v);
        };
        Set { inner: response }
    }

    #[inline]
    fn len(self: SpanSet<T>) -> usize {
        self.inner.len()
    }
}

#[cfg(test)]
mod tests {
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
}
