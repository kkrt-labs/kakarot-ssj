use evm::instructions::PushOperationsTrait;
use evm::stack::StackTrait;
use evm_tests::test_utils::evm_utils::{VMBuilderTrait};

fn get_n_0xFF(mut n: u8) -> Span<u8> {
    let mut array: Array<u8> = ArrayTrait::new();
    loop {
        if n == 0 {
            break;
        }
        array.append(0xFF);
        n -= 1;
    };
    array.span()
}

#[test]
fn test_push0() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(0)).build();

    // When
    vm.exec_push0().expect('exec_push0 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'invalid stack top');
}

#[test]
fn test_push1() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(1)).build();

    // When
    vm.exec_push1().expect('exec_push1 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFF, 'invalid stack top');
}

#[test]
fn test_push2() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(2)).build();

    // When
    vm.exec_push2().expect('exec_push2 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFF, 'invalid stack top');
}

#[test]
fn test_push3() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(3)).build();

    // When
    vm.exec_push3().expect('exec_push3 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFF, 'invalid stack top');
}

#[test]
fn test_push4() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(4)).build();

    // When
    vm.exec_push4().expect('exec_push4 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push5() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(5)).build();

    // When
    vm.exec_push5().expect('exec_push5 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push6() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(6)).build();

    // When
    vm.exec_push6().expect('exec_push6 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push7() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(7)).build();

    // When
    vm.exec_push7().expect('exec_push7 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFF, 'invalid stack top');
}


#[test]
fn test_push8() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(8)).build();

    // When
    vm.exec_push8().expect('exec_push8 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push9() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(9)).build();

    // When
    vm.exec_push9().expect('exec_push9 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push10() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(10)).build();

    // When
    vm.exec_push10().expect('exec_push10 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push11() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(11)).build();

    // When
    vm.exec_push11().expect('exec_push11 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push12() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(12)).build();

    // When
    vm.exec_push12().expect('exec_push12 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push13() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(13)).build();

    // When
    vm.exec_push13().expect('exec_push13 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push14() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(14)).build();

    // When
    vm.exec_push14().expect('exec_push14 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push15() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(15)).build();

    // When
    vm.exec_push15().expect('exec_push15 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push16() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(16)).build();

    // When
    vm.exec_push16().expect('exec_push16 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push17() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(17)).build();

    // When
    vm.exec_push17().expect('exec_push17 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}

#[test]
fn test_push18() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(18)).build();

    // When
    vm.exec_push18().expect('exec_push18 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top');
}
#[test]
fn test_push19() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(19)).build();

    // When
    vm.exec_push19().expect('exec_push19 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top'
    );
}

#[test]
fn test_push20() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(20)).build();

    // When
    vm.exec_push20().expect('exec_push20 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 'invalid stack top'
    );
}

#[test]
fn test_push21() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(21)).build();

    // When
    vm.exec_push21().expect('exec_push21 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push22() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(22)).build();

    // When
    vm.exec_push22().expect('exec_push22 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}
#[test]
fn test_push23() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(23)).build();

    // When
    vm.exec_push23().expect('exec_push23 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}
#[test]
fn test_push24() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(24)).build();

    // When
    vm.exec_push24().expect('exec_push24 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push25() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(25)).build();

    // When
    vm.exec_push25().expect('exec_push25 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push26() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(26)).build();

    // When
    vm.exec_push26().expect('exec_push26 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push27() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(27)).build();

    // When
    vm.exec_push27().expect('exec_push27 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push28() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(28)).build();

    // When
    vm.exec_push28().expect('exec_push28 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push29() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(29)).build();

    // When
    vm.exec_push29().expect('exec_push29 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push30() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(30)).build();

    // When
    vm.exec_push30().expect('exec_push30 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push31() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(31)).build();

    // When
    vm.exec_push31().expect('exec_push31 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}

#[test]
fn test_push32() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().with_bytecode(get_n_0xFF(32)).build();

    // When
    vm.exec_push32().expect('exec_push32 failed');
    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'invalid stack top'
    );
}
