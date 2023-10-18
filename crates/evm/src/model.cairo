use evm::execution::Status;
use starknet::EthAddress;
#[derive(Drop)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}

struct ExecutionResult {
    status: Status,
    return_data: Span<u8>,
    create_addresses: Span<EthAddress>,
    destroyed_contracts: Span<EthAddress>,
    events: Span<Event>
}
