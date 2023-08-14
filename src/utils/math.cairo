trait Exponentiation<T> {
    // Raise a number to a power.
    /// * `base` - The number to raise.
    /// * `exp` - The exponent.
    /// # Returns
    /// * `T` - The result of base raised to the power of exp.
    fn pow(self: T, exp: T) -> T;
}

impl U256ExpImpl of Exponentiation<u256> {
    fn pow(self: u256, exp: u256) -> u256 {
        if exp == 0 {
            return 1;
        } else {
            return self * Exponentiation::pow(self, exp - 1);
        }
    }
}

impl Felt252ExpImpl of Exponentiation<felt252> {
    fn pow(self: felt252, exp: felt252) -> felt252 {
        if exp == 0 {
            return 1;
        } else {
            return self * Exponentiation::pow(self, exp - 1);
        }
    }
}
