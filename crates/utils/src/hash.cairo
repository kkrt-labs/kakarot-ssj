impl HashStateExtImpl of HashStateExtTrait<HashState> {
    /// A variant of poseidon hash that computes a value that fits in a Starknet StorageBaseAddress.
    #[inline(always)]
    fn finalize_250(self: HashState) -> felt252 {
        let r = if self.odd {
            let (r, _, _) = hades_permutation(self.s0, self.s1 + 1, self.s2);
            r
        } else {
            let (r, _, _) = hades_permutation(self.s0 + 1, self.s1, self.s2);
            r
        };

        r & 0x3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    }
}
