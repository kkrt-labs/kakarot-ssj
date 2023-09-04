# Kakarot's Execution Context

The execution context is the environment in which the EVM bytecode code is
executed. It is modeled through the ExecutionContext struct, which contains the
following fields

> Note: the
> [actual implementation of the execution context](https://github.com/kkrt-labs/kakarot-ssj/blob/main/crates/evm/src/context.cairo#L163)
> doesn't match the description below, as some fields are packed together in
> sub-structs for optimisation purposes. However, the general idea remains the
> same.

```mermaid
classDiagram
    class ExecutionContext{
    +call_context: CallContext
    +starknet_address: ContractAddress
    +evm_address: EthAddress
    +read_only: bool
    destroyed_contracts: Array~EthAddress~,
    events: Array~Event~,
    create_addresses: Array~EthAddress~,
    revert_contract_state: Felt252Dict~felt252~,
    return_data: Array~u8~,
    reverted: bool,
    stopped: bool,
    +gas_limit: u64
    +gas_price:u64
    +memory Memory
    +stack Stack
    +u32 program_counter
    }

    class CallContext{
        bytecode: Span~u8~,
        calldata: Span~u8~,
        value: u256,
    }
    ExecutionContext *-- CallContext
```

When submitting a transaction to the EVM, the `call_context` field of the
`ExecutionContext` is initialized with the bytecode of the contract to execute,
the call data sent in the transaction, and the value of the transaction. The
stack and memory are initialized empty.

Executing opcodes mutates the execution context. For example, executing the ADD
opcode removes the top two elements from the stack and pushes back their sum.

## Run execution flow

The following diagram describe the flow of the execution context when executing
the `run` function given an instance of the `ExecutionContext` struct.

The run function is responsible for executing EVM bytecode. The flow of
execution involves decoding and executing the current opcode, handling the
execution, and continue executing the next opcode if the execution of the
previous one succeeded. If the execution of an opcode fails, the execution
context reverts and all the changes made to the blockchain state are reverted.

```mermaid
flowchart TD
AA["START"] --> A
A["run()"] --> B[Decode and Execute Opcode]
B --> C{Result OK?}
C -->|Yes| D{Execution stopped?}
D -->|No => pc+=1| A
D -->|Yes| F{Reverted?}
C -->|No| RA
F --> |No| J["emit pending events"]
J --> END["return"]
F -->|Yes| RA[Erase contracts created]

subgraph revert context changes
RA --> RB["Clear un-emitted events"]
RB --> RC["Revert state updates"]
end
RC --> END
```

<!-- TODO -->

> Note: The revert context changes subgraph is not implemented yet.

> Note: The event emission is not implemented yet.
