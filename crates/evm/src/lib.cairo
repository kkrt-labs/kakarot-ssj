// Kakarot main module
mod execution;

// Memory module
mod memory;

// Stack module
mod stack;

// interpreter module
mod interpreter;

// instructions module
mod instructions {
    /// Sub modules.
    mod block_information;
    use block_information::BlockInformationTrait;

    mod comparison_operations;
    use comparison_operations::ComparisonAndBitwiseOperationsTrait;

    mod duplication_operations;
    use duplication_operations::DuplicationOperationsTrait;

    mod environmental_information;
    use environmental_information::EnvironmentInformationTrait;

    mod exchange_operations;

    mod logging_operations;

    mod memory_operations;
    use memory_operations::MemoryOperationTrait;

    mod push_operations;
    use push_operations::PushOperationsTrait;

    mod sha3;

    mod stop_and_arithmetic_operations;
    use stop_and_arithmetic_operations::StopAndArithmeticOperationsTrait;

    mod system_operations;
}

// Context module
mod context;

// Data Models module
mod model;

// Errors module
mod errors;

// Helpers module
mod helpers;

// tests
#[cfg(test)]
mod tests {
    #[cfg(test)]
    mod test_kakarot;

    #[cfg(test)]
    mod test_stack;

    #[cfg(test)]
    mod test_memory;

    #[cfg(test)]
    mod test_utils;

    #[cfg(test)]
    mod test_execution_context;

    #[cfg(test)]
    mod test_instructions;
}
