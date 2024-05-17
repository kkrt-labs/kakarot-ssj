use core::array::ArrayTrait;
use evm::instructions::exchange_operations::ExchangeOperationsTrait;
use evm::stack::StackTrait;
use evm_tests::test_utils::VMBuilderTrait;


#[test]
fn test_exec_swap1() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap1().expect('exec_swap1 failed');

    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
    assert(vm.stack.peek_at(1).unwrap() == 1, 'val at index 1 should be now 1');
}


#[test]
fn test_exec_swap2() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap2().expect('exec_swap2 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
    assert(vm.stack.peek_at(2).unwrap() == 1, 'val at index 2 should be now 1');
}

#[test]
fn test_exec_swap3() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap3().expect('exec_swap3 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
    assert(vm.stack.peek_at(3).unwrap() == 1, 'val at index 3 should be now 1');
}

#[test]
fn test_exec_swap4() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap4().expect('exec_swap4 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(4).unwrap() == 1, 'val at index 4 should be now 1');
}


#[test]
fn test_exec_swap5() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap5().expect('exec_swap5 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(5).unwrap() == 1, 'val at index 5 should be now 1');
}

#[test]
fn test_exec_swap6() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap6().expect('exec_swap6 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(6).unwrap() == 1, 'val at index 6 should be now 1');
}


#[test]
fn test_exec_swap7() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap7().expect('exec_swap7 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(7).unwrap() == 1, 'val at index 7 should be now 1');
}

#[test]
fn test_exec_swap8() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap8().expect('exec_swap8 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(8).unwrap() == 1, 'val at index 8 should be now 1');
}


#[test]
fn test_exec_swap9() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap9().expect('exec_swap9 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(9).unwrap() == 1, 'val at index 9 should be now 1');
}

#[test]
fn test_exec_swap10() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap10().expect('exec_swap10 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(10).unwrap() == 1, 'val at index 10 should be now 1');
}

#[test]
fn test_exec_swap11() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap11().expect('exec_swap11 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(11).unwrap() == 1, 'val at index 11 should be now 1');
}

#[test]
fn test_exec_swap12() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap12().expect('exec_swap12 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(12).unwrap() == 1, 'val at index 12 should be now 1');
}

#[test]
fn test_exec_swap13() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap13().expect('exec_swap13 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(13).unwrap() == 1, 'val at index 13 should be now 1');
}

#[test]
fn test_exec_swap14() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap14().expect('exec_swap14 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(14).unwrap() == 1, 'val at index 14 should be now 1');
}

#[test]
fn test_exec_swap15() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap15().expect('exec_swap15 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(15).unwrap() == 1, 'val at index 15 should be now 1');
}

#[test]
fn test_exec_swap16() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    // given
    vm.stack.push(0xf).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(0).expect('push failed');
    vm.stack.push(1).expect('push failed');
    vm.exec_swap16().expect('exec_swap16 failed');
    assert(vm.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(vm.stack.peek_at(16).unwrap() == 1, 'val at index 16 should be now 1');
}
