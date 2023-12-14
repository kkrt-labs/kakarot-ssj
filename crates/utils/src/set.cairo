use utils::helpers::{SpanExtTrait, ArrayExtTrait};

#[derive(Drop, PartialEq)]
struct Set<T> {
    inner: Array<T>
}

impl SetDefault<T, +Drop<T>> of Default<Set<T>> {
    #[inline]
    fn default() -> Set<T> {
        let arr: Array<T> = Default::default();
        Set { inner: arr }
    }
}


#[generate_trait]
impl SetImpl<T, +Drop<T>, +PartialEq<T>, +Copy<T>> of SetTrait<T> {
    #[inline]
    fn new() -> Set<T> {
        Set { inner: Default::default() }
    }

    #[inline]
    fn add(ref self: Set<T>, item: T) {
        self.inner.append_unique(item);
    }


    #[inline]
    fn extend(ref self: Set<T>, other: SpanSet<T>) {
        self.extend_from_span(other.to_span());
    }

    #[inline]
    fn extend_from_span(ref self: Set<T>, mut other: Span<T>) {
        loop {
            match other.pop_front() {
                Option::Some(v) => { self.add(*v); },
                Option::None => { break (); },
            };
        };
    }

    #[inline]
    fn contains(self: @Set<T>, item: T) -> bool {
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

impl SetTCloneImpl<T, +Clone<T>, +Drop<T>, +PartialEq<T>, +Copy<T>> of Clone<Set<T>> {
    fn clone(self: @Set<T>) -> Set<T> {
        let mut response: Array<T> = Default::default();
        let mut span = self.to_span();
        loop {
            match span.pop_front() {
                Option::Some(v) => { response.append(*v); },
                Option::None => { break (); },
            };
        };
        Set { inner: response }
    }
}

#[derive(Copy, Drop, PartialEq)]
struct SpanSet<T> {
    inner: @Set<T>
}

impl SpanSetDefault<T, +Drop<T>> of Default<SpanSet<T>> {
    #[inline]
    fn default() -> SpanSet<T> {
        let set: Set<T> = Default::default();
        SpanSet { inner: @set }
    }
}


// impl SpanSetCopy<T> of Copy<SpanSet<T>>;
// impl SpanSetDrop<T> of Drop<SpanSet<T>>;

#[generate_trait]
impl SpanSetImpl<T, +Copy<T>, +Drop<T>, +PartialEq<T>> of SpanSetTrait<T> {
    #[inline]
    fn contains(self: SpanSet<T>, item: T) -> bool {
        self.inner.contains(item)
    }

    #[inline]
    fn to_span(self: SpanSet<T>) -> Span<T> {
        self.inner.to_span()
    }

    fn clone_set(self: SpanSet<T>) -> Set<T> {
        let mut response: Array<T> = Default::default();
        let mut span = self.to_span();
        loop {
            match span.pop_front() {
                Option::Some(v) => { response.append(*v); },
                Option::None => { break (); },
            };
        };
        Set { inner: response }
    }

    #[inline]
    fn len(self: SpanSet<T>) -> usize {
        self.inner.len()
    }
}
