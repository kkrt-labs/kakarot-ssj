//todo(harsh): remove
use debug::PrintTrait;

use evm::precompiles::blake2::Blake2PrecompileTrait
;
use evm::tests::test_utils::{VMBuilderTrait, native_token, other_starknet_address};

#[test]
fn test_blake2_precompile() {
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let calldata = array![43,248,148,254,114,243,110,60,241,54,29,95,58,245,79,165,209,130,230,173,127,82,14,81,31,108,62,43,140,104,5,155,107,189,65,251,171,217,131,31,121,33,126,19,25,205,224,91,97,98,99,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1].span();
    vm.message.data = calldata;

    let gas_before = vm.gas_left;
    Blake2PrecompileTrait::exec(ref vm).unwrap();
    let gas_after = vm.gas_left;

    let result = vm.return_data;

    let mut i = 0;
    loop {
        if i == result.len() {
            break;
        }

        (*result[i]).print();

        i+=1;
    };
}
