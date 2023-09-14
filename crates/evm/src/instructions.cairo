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
use sha3::Sha3Trait;

mod stop_and_arithmetic_operations;
use stop_and_arithmetic_operations::StopAndArithmeticOperationsTrait;

mod system_operations;
use system_operations::SystemOperationsTrait;
