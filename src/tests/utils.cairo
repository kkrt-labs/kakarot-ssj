
fn setup_call_context() -> CallContext {
    let bytecode: Span<u8> = array![1, 2, 3].span();
    let call_data: Span<u8> = array![4, 5, 6].span();
    let value: u256 = 100;

    CallContextTrait::new(bytecode, call_data, value)
}

fn setup_execution_context() -> ExecutionContext {
    let call_context = setup_call_context();
    let starknet_address: ContractAddress = starknet_address();
    let evm_address: EthAddress = evm_address();
    let gas_limit: u64 = 1000;
    let gas_price: u64 = 10;
    let read_only: bool = false;
    let returned_data = Default::default();

    ExecutionContextTrait::new(
        call_context, starknet_address, evm_address, gas_limit, gas_price, returned_data, read_only
    )
}

impl CallContextPartialEq of PartialEq<CallContext> {
    fn eq(lhs: @CallContext, rhs: @CallContext) -> bool {
        lhs.bytecode() == rhs.bytecode() && lhs.call_data == rhs.call_data && lhs.value == rhs.value
    }
    fn ne(lhs: @CallContext, rhs: @CallContext) -> bool {
        !(lhs == rhs)
    }
}
