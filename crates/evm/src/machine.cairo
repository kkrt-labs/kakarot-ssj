use evm::{context::{ExecutionContext,}, stack::Stack, memory::Memory};

struct Journal {
    local_changes: Felt252Dict<felt252>,
    local_keys: Array<felt252>,
    global_changes: Felt252Dict<felt252>,
    global_keys: Array<felt252>
}

struct Machine {
    current_ctx: usize,
    ctx_count: usize,
    root_ctx: ExecutionContext,
    stack: Stack,
    memory: Memory,
    storage_journal: Journal
}
