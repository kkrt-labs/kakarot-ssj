use array::ArrayTrait;
use evm::context::ExecutionContextTrait;
use evm::instructions::exchange_operations::ExchangeOperationsTrait;
use evm::machine::Machine;
use evm::stack::StackTrait;
use evm::tests::test_utils::setup_machine;


#[test]
#[available_gas(20000000)]
fn test_exec_swap1() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap1();

    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
    assert(machine.stack.peek_at(1).unwrap() == 1, 'val at index 1 should be now 1');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap2() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap2();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
    assert(machine.stack.peek_at(2).unwrap() == 1, 'val at index 2 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap3() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap3();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be now 0xf');
    assert(machine.stack.peek_at(3).unwrap() == 1, 'val at index 3 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap4() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap4();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(4).unwrap() == 1, 'val at index 4 should be now 1');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap5() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap5();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(5).unwrap() == 1, 'val at index 5 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap6() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap6();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(6).unwrap() == 1, 'val at index 6 should be now 1');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap7() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap7();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(7).unwrap() == 1, 'val at index 7 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap8() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap8();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(8).unwrap() == 1, 'val at index 8 should be now 1');
}


#[test]
#[available_gas(20000000)]
fn test_exec_swap9() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap9();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(9).unwrap() == 1, 'val at index 9 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap10() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap10();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(10).unwrap() == 1, 'val at index 10 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap11() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap11();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(11).unwrap() == 1, 'val at index 11 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap12() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap12();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(12).unwrap() == 1, 'val at index 12 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap13() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap13();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(13).unwrap() == 1, 'val at index 13 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap14() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap14();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(14).unwrap() == 1, 'val at index 14 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap15() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap15();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(15).unwrap() == 1, 'val at index 15 should be now 1');
}

#[test]
#[available_gas(20000000)]
fn test_exec_swap16() {
    let mut machine = setup_machine();
    // given
    machine.stack.push(0xf).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(0).unwrap();
    machine.stack.push(1).unwrap();
    machine.exec_swap16();
    assert(machine.stack.peek().unwrap() == 0xf, 'Top should be  now 0xf');
    assert(machine.stack.peek_at(16).unwrap() == 1, 'val at index 16 should be now 1');
}
