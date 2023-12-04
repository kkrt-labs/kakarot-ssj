use evm::model::vm::{VM, VMTrait};
use evm::model::{Message, Environment};

#[test]
fn test_is_valid_jump_destinations() {
    // PUSH1, 0x03, JUMP, JUMPDEST, PUSH1, 0x09, JUMP, PUSH1 0x2, JUMPDDEST, PUSH1 0x2
    let bytecode: Array<u8> = array![
        0x60, 0x3, 0x56, 0x5b, 0x60, 0x9, 0x56, 0x60, 0x2, 0x5b, 0x60, 0x2
    ];
    let mut message: Message = Default::default();
    message.code = bytecode.span();

    let mut vm = VMTrait::new(message, Default::default());

    vm.init_valid_jump_destinations();

    let expected_valid_jump_destinations = array![0x3, 0x9].span();
    assert!(
        vm.valid_jumpdests == expected_valid_jump_destinations,
        "expected valid_jump_destinations to be [0x3, 0x9]"
    );

    assert!(vm.is_valid_jump(0x3) == true, "expected jump to be valid");
    assert!(vm.is_valid_jump(0x9) == true, "expected jump to be valid");

    assert!(vm.is_valid_jump(0x4) == false, "expected jump to be invalid");
    assert!(vm.is_valid_jump(0x5) == false, "expected jump to be invalid");
}

#[test]
fn test_valid_jump_destination_failing() {
    // PUSH1, 0x03, JUMP, JUMPDEST, PUSH1, 0x09, JUMP, PUSH1 0x2, JUMPDDEST, PUSH1 0x2
    let bytecode: Array<u8> = array![0x60, 0x5B, 0x60, 0x00];
    let mut message: Message = Default::default();
    message.code = bytecode.span();

    let mut vm = VMTrait::new(message, Default::default());
    vm.init_valid_jump_destinations();

    assert!(vm.is_valid_jump(0x1) == false, "expected false");
}
