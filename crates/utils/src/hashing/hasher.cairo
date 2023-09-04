// @notice Hasher trait, a common interface for all hashers
trait Hasher<T, V> {
    fn hash_single(a: T) -> V;
    fn hash_double(a: T, b: T) -> V;
    fn hash_many(input: Span<T>) -> V;
}
