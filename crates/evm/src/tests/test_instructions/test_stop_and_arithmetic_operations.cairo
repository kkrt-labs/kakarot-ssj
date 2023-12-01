use core::result::ResultTrait;
use evm::instructions::StopAndArithmeticOperationsTrait;
use evm::model::vm::{VM, VMTrait};
use evm::stack::StackTrait;
use evm::tests::test_utils::VMBuilderTrait;

use integer::BoundedInt;


#[test]
fn test_exec_stop() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();

    // When
    vm.exec_stop().expect('exec_stop failed');

    // Then
    assert(!vm.is_running(), 'ctx not stopped');
}

#[test]
fn test_exec_add() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(1).expect('push failed');
    vm.stack.push(2).expect('push failed');
    vm.stack.push(3).expect('push failed');

    // When
    vm.exec_add().expect('exec_add failed');

    // Then
    assert(vm.stack.len() == 2, 'stack should have two elems');
    assert(vm.stack.peek().unwrap() == 5, 'stack top should be 3+2');
    assert(vm.stack.peek_at(1).unwrap() == 1, 'stack[1] should be 1');
}

#[test]
fn test_exec_add_overflow() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(BoundedInt::<u256>::max()).unwrap();
    vm.stack.push(1).expect('push failed');

    // When
    vm.exec_add().expect('exec_add failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
fn test_exec_mul() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(4).expect('push failed');
    vm.stack.push(5).expect('push failed');

    // When
    vm.exec_mul().expect('exec_mul failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 20, 'stack top should be 4*5');
}

#[test]
fn test_exec_mul_overflow() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(BoundedInt::<u256>::max()).unwrap();
    vm.stack.push(2).expect('push failed');

    // When
    vm.exec_mul().expect('exec_mul failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == BoundedInt::<u256>::max() - 1, 'expected MAX_U256 -1');
}

#[test]
fn test_exec_sub() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(7).expect('push failed');
    vm.stack.push(10).expect('push failed');

    // When
    vm.exec_sub().expect('exec_sub failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 3, 'stack top should be 10-7');
}

#[test]
fn test_exec_sub_underflow() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(1).expect('push failed');
    vm.stack.push(0).expect('push failed');

    // When
    vm.exec_sub().expect('exec_sub failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == BoundedInt::<u256>::max(), 'stack top should be MAX_U256');
}


#[test]
fn test_exec_div() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(4).expect('push failed');
    vm.stack.push(100).expect('push failed');

    // When
    vm.exec_div().expect('exec_div failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 25, 'stack top should be 100/4');
}

#[test]
fn test_exec_div_by_zero() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0).expect('push failed');
    vm.stack.push(100).expect('push failed');

    // When
    vm.exec_div().expect('exec_div failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
fn test_exec_sdiv_pos() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(5).expect('push failed');
    vm.stack.push(10).expect('push failed');

    // When
    vm.exec_sdiv().expect('exec_sdiv failed'); // 10 / 5

    // Then
    assert(vm.stack.len() == 1, 'stack len should be 1');
    assert(vm.stack.peek().unwrap() == 2, 'ctx not stopped');
}

#[test]
fn test_exec_sdiv_neg() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(BoundedInt::max()).unwrap();
    vm.stack.push(2).expect('push failed');

    // When
    vm.exec_sdiv().expect('exec_sdiv failed'); // 2 / -1

    // Then
    assert(vm.stack.len() == 1, 'stack len should be 1');
    assert(vm.stack.peek().unwrap() == BoundedInt::max() - 1, 'sdiv_neg failed');
}

#[test]
fn test_exec_sdiv_by_0() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0).expect('push failed');
    vm.stack.push(10).expect('push failed');

    // When
    vm.exec_sdiv().expect('exec_sdiv failed');

    // Then
    assert(vm.stack.len() == 1, 'stack len should be 1');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}

#[test]
fn test_exec_mod() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(6).expect('push failed');
    vm.stack.push(100).expect('push failed');

    // When
    vm.exec_mod().expect('exec_mod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 4, 'stack top should be 100%6');
}

#[test]
fn test_exec_mod_by_zero() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0).expect('push failed');
    vm.stack.push(100).expect('push failed');

    // When
    vm.exec_smod().expect('exec_smod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 100%6');
}

#[test]
fn test_exec_smod() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(3).expect('push failed');
    vm.stack.push(10).expect('push failed');

    // When
    vm.exec_smod().expect('exec_smod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 1, 'stack top should be 10%3 = 1');
}

#[test]
fn test_exec_smod_neg() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD)
        .unwrap(); // -3
    vm
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8)
        .unwrap(); // -8

    // When
    vm.exec_smod().expect('exec_smod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
        'stack top should be -8%-3 = -2'
    );
}

#[test]
fn test_exec_smod_zero() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0).expect('push failed');
    vm.stack.push(10).expect('push failed');

    // When
    vm.exec_mod().expect('exec_mod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}


#[test]
fn test_exec_addmod() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(7).expect('push failed');
    vm.stack.push(10).expect('push failed');
    vm.stack.push(20).expect('push failed');

    // When
    vm.exec_addmod().expect('exec_addmod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 2, 'stack top should be (10+20)%7');
}

#[test]
fn test_exec_addmod_by_zero() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0).expect('push failed');
    vm.stack.push(10).expect('push failed');
    vm.stack.push(20).expect('push failed');

    // When
    vm.exec_addmod().expect('exec_addmod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
}


#[test]
fn test_exec_addmod_overflow() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(3).expect('push failed');
    vm.stack.push(2).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).unwrap();

    // When
    vm.exec_addmod().expect('exec_addmod failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 2, 'stack top should be 2'
    ); // (MAX_U256 + 2) % 3 = (2^256 + 1) % 3 = 2
}

#[test]
fn test_mulmod_basic() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(10).expect('push failed');
    vm.stack.push(7).expect('push failed');
    vm.stack.push(5).expect('push failed');

    // When
    vm.exec_mulmod().expect('exec_mulmod failed');

    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 5, 'stack top should be 5'); // (5 * 7) % 10 = 5
}

#[test]
fn test_mulmod_zero_modulus() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0).expect('push failed');
    vm.stack.push(7).expect('push failed');
    vm.stack.push(5).expect('push failed');

    vm.exec_mulmod().expect('exec_mulmod failed');

    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0'); // modulus is 0
}

#[test]
fn test_mulmod_overflow() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(12).expect('push failed');
    vm.stack.push(BoundedInt::<u256>::max()).unwrap();
    vm.stack.push(BoundedInt::<u256>::max()).unwrap();

    vm.exec_mulmod().expect('exec_mulmod failed');

    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 9, 'stack top should be 1'
    ); // (MAX_U256 * MAX_U256) % 12 = 9
}

#[test]
fn test_mulmod_zero() {
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(10).expect('push failed');
    vm.stack.push(7).expect('push failed');
    vm.stack.push(0).expect('push failed');

    vm.exec_mulmod().expect('exec_mulmod failed');

    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0'); // 0 * 7 % 10 = 0
}

#[test]
fn test_exec_exp() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(2).expect('push failed');
    vm.stack.push(10).expect('push failed');

    // When
    vm.exec_exp().expect('exec exp failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 100, 'stack top should be 100');
}

#[test]
fn test_exec_exp_overflow() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(2).expect('push failed');
    vm.stack.push(BoundedInt::<u128>::max().into() + 1).unwrap();

    // When
    vm.exec_exp().expect('exec exp failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0'); // (2^128)^2 = 2^256 = 0 % 2^256
}

#[test]
fn test_exec_signextend() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0xFF).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    vm.exec_signextend().expect('exec_signextend failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm
            .stack
            .peek()
            .unwrap() == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
        'stack top should be MAX_u256 -1'
    );
}

#[test]
fn test_exec_signextend_no_effect() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm.stack.push(0x7F).expect('push failed');
    vm.stack.push(0x00).expect('push failed');

    // When
    vm.exec_signextend().expect('exec_signextend failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0x7F, 'stack top should be 0x7F'
    ); // The 248-th bit of x is 0, so the output is not changed.
}

#[test]
fn test_exec_signextend_on_negative() {
    // Given
    let mut vm = VMBuilderTrait::new_with_presets().build();
    vm
        .stack
        .push(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0001)
        .expect('push failed');
    vm.stack.push(0x01).expect('push failed'); // s = 15, v = 0

    // When
    vm.exec_signextend().expect('exec_signextend failed');

    // Then
    assert(vm.stack.len() == 1, 'stack should have one element');
    assert(
        vm.stack.peek().unwrap() == 0x01, 'stack top should be 0'
    ); // The 241-th bit of x is 0, so all bits before t are switched to 0
}

