# Kakarot's Execution Context

The execution context is the environment in which the EVM bytecode code is
executed. It contains information such as the bytecode being currently executed,
the value of the program counter, the gas limit, etc.

It is modeled through the ExecutionContext struct, which contains the following
fields

> Note: the
> [actual implementation of the execution context](https://github.com/kkrt-labs/kakarot-ssj/blob/main/crates/evm/src/context.cairo#L163)
> doesn't match the description below, as some fields are packed together in
> sub-structs for optimisation purposes. However, the general idea remains the
> same.

```mermaid
classDiagram
    class ExecutionContext{
        id: usize,
        evm_address: EthAddress,
        starknet_address: ContractAddress,
        program_counter: u32,
        status: Status,
        call_ctx: CallContext,
        events: Array~Event~,
        return_data: Span~u8~,
        parent_ctx: Nullable~ExecutionContext~,
    }

    class CallContext{
        caller: EthAddress,
        bytecode: Span~u8~,
        calldata: Span~u8~,
        value: u256,
        gas_price: u128,
        gas_limit: u128,
        read_only: bool,
    }

    class Event{
        keys: Array~u256~,
        data: Array~u8~
    }

    class Status{
    <<enumeration>>
      Active,
      Stopped,
      Reverted
    }

    ExecutionContext *-- CallContext
    ExecutionContext *-- Event
    ExecutionContext *-- Status
```

When submitting a transaction to the EVM, the `call_ctx` field of the
`ExecutionContext` is initialized with the bytecode of the contract to execute,
the call data sent in the transaction, and the value of the transaction. The
`ExecutionContext` could also hold the `Stack` and `Memory` data structures
relative to the current code execution. However, due to Cairo's limitations,
these data structures have been moved to the `Machine` struct - which is
explained in detail in the [Machine](./machine.md) docs.

Executing opcodes mutates both the execution context and the state of the
Machine in general. For example, executing the ADD opcode removes the top two
elements from the stack, pushes back their sum, updates the value of `pc`.

## Run execution flow

The following diagram describe the flow of the execution context when executing
the `run` function given an instance of the `Machine` struct.

The run function is responsible for executing EVM bytecode. The flow of
execution involves decoding and executing the current opcode, handling the
execution, and continue executing the next opcode if the execution of the
previous one succeeded. If the execution of an opcode fails, the execution
context reverts and changes made to the blockchain state are not finalized.

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
J --> K["finalize local storage updates"]
K --> END["return"]
F -->|Yes| RA[Erase contracts created]

subgraph revert context changes
RA --> RB["Clear un-emitted events"]
RB --> RC["Revert state updates"]
end
RC --> END
```

<!-- TODO -->

> Note: The revert context changes subgraph is not implemented yet. Note: The
> event emission is not implemented yet.
