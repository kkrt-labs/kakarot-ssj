use utils::hashing::hasher::Hasher;
use poseidon::{poseidon_hash_span, hades_permutation};

struct Poseidon {}

// Permutation params: https://docs.starknet.io/documentation/architecture_and_concepts/Cryptography/hash-functions/#poseidon_hash
impl PoseidonHasher of Hasher<felt252, felt252> {
    fn hash_single(a: felt252) -> felt252 {
        let (single, _, _) = hades_permutation(a, 0, 1);
        single
    }

    fn hash_double(a: felt252, b: felt252) -> felt252 {
        let (double, _, _) = hades_permutation(a, b, 2);
        double
    }

    fn hash_many(input: Span<felt252>) -> felt252 {
        poseidon_hash_span(input)
    }
}
