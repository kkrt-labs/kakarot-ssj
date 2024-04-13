use core::integer::BoundedInt;
use evm::instructions::DuplicationOperationsTrait;
use evm::stack::Stack;
use evm::stack::StackTrait;
use evm::tests::test_utils::VMBuilderTrait;


// ensures all values start from index `from` upto index `to` of stack are `0x0`
fn ensures_zeros(ref stack: Stack, from: u32, to: u32) {
    let mut idx: u32 = from;

    if to > from {
        return;
    }

    loop {
        if idx == to {
            break;
        }

        assert(stack.peek_at(idx).unwrap() == 0x00, 'should be zero');
        idx += 1;
    }
}

// push `n` number of `0x0` to the stack
fn push_zeros(ref stack: Stack, n: u8) {
    let mut i = 0;
    loop {
        if i == n {
            break;
        }
        stack.push(0x0).unwrap();
        i += 1;
    }
}

#[test]
fn test_dup1() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup1().expect('exec_dup1 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup2() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 1);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup2().expect('exec_dup2 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup3() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 2);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup3().expect('exec_dup3 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup4() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 3);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup4().expect('exec_dup4 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup5() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 4);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup5().expect('exec_dup5 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup6() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 5);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup6().expect('exec_dup6 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup7() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 6);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup7().expect('exec_dup7 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup8() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 7);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup8().expect('exec_dup8 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup9() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 8);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup9().expect('exec_dup9 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup10() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 9);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup10().expect('exec_dup10 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup11() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 10);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup11().expect('exec_dup11 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup12() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 11);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup12().expect('exec_dup12 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup13() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 12);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup13().expect('exec_dup13 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup14() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 13);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup14().expect('exec_dup14 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup15() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 14);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup15().expect('exec_dup15 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}

#[test]
fn test_dup16() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    let initial_len = vm.stack.len();

    vm.stack.push(0x01).expect('push failed');
    push_zeros(ref vm.stack, 15);

    let old_stack_len = vm.stack.len();

    // When
    vm.exec_dup16().expect('exec_dup16 failed');

    // Then
    let new_stack_len = vm.stack.len();

    assert(new_stack_len == old_stack_len + 1, 'len should increase by 1');

    assert(vm.stack.peek_at(initial_len).unwrap() == 0x01, 'first inserted spot should be 1');
    assert(vm.stack.peek_at(new_stack_len - 1).unwrap() == 0x01, 'top of stack should be 1');

    ensures_zeros(ref vm.stack, initial_len + 1, new_stack_len - 1);
}
