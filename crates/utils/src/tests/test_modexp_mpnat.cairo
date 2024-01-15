use core::traits::Into;
use alexandria_data_structures::vec::VecTrait;
use alexandria_data_structures::vec::{Felt252Vec, Felt252VecImpl};
use core::result::ResultTrait;

//todo: remove
use debug::PrintTrait;
use utils::crypto::modexp::arith::{mod_inv, monsq, monpro, compute_r_mod_n, in_place_shl, in_place_shr, big_wrapping_pow, big_wrapping_mul, big_sq, borrowing_sub, shifted_carrying_mul};
use utils::crypto::modexp::mpnat::{MPNat, MPNatTrait, WORD_MAX, DOUBLE_WORD_MAX, Word, DoubleWord, WORD_BYTES};
use utils::helpers::{U128Trait, U32Trait};
use utils::helpers::{Felt252VecTrait,  Felt252VecU64Trait };
use utils::math::{u64_wrapping_mul};

#[generate_trait]
impl Felt252TestTraitImpl of Felt252TestTrait {
    fn print_dict(ref self: Felt252Vec<u64>) {
        let mut i = 0;
        loop {
            if self.len == i {
                break;
            }

            let b = self[i];
            b.print();

            i += 1;
        }
    }
}
