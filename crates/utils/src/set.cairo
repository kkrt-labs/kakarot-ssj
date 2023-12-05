use utils::helpers::{SpanExtTrait, ArrayExtTrait};

#[derive(Default, Drop)]
struct Set<T> {
    inner: Array<T>
}

#[generate_trait]
impl SetImpl<T, +Drop<T>, +PartialEq<T>> of SetTrait<T> {
    #[inline]
    fn new() -> Set<T> {
        Set { inner: Default::default() }
    }

    #[inline]
    fn add<+Copy<T>,>(ref self: Set<T>, item: T) {
        self.inner.append_unique(item);
    }

    #[inline]
    fn contains<+Copy<T>>(self: @Set<T>, item: T) -> bool {
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
    fn len(self: @Set<T>) -> usize {
        self.inner.span().len()
    }
}

impl SetTCloneImpl<T, +Clone<T>, +Drop<T>, +PartialEq<T>> of Clone<Set<T>> {
    fn clone(self: @Set<T>) -> Set<T> {
        let mut response: Array<T> = Default::default();
        let mut span = self.to_span();
        loop {
            match span.pop_front() {
                Option::Some(v) => { response.append(v.clone()); },
                Option::None => { break (); },
            };
        };
        Set { inner: response }
    }
}

#[derive(Copy, Drop, PartialEq)]
struct SpanSet<T> {
    inner: Span<T>
}

impl SpanSetDefault<T, +Drop<T>> of Default<SpanSet<T>> {
    #[inline]
    fn default() -> SpanSet<T> {
        let arr: Array<T> = Default::default();
        SpanSet { inner: arr.span() }
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
        self.inner
    }

    #[inline]
    fn len(self: SpanSet<T>) -> usize {
        self.inner.len()
    }
}
