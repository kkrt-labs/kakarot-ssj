/// Sub modules.
mod block_information;
mod comparison_operations;

mod duplication_operations;
mod environmental_information;
mod exchange_operations;
mod logging_operations;
mod memory_operations;
mod push_operations;
mod sha3;
mod stop_and_arithmetic_operations;
mod system_operations;

use block_information::BlockInformationTrait;
use comparison_operations::ComparisonAndBitwiseOperationsTrait;
use duplication_operations::DuplicationOperationsTrait;
use environmental_information::EnvironmentInformationTrait;
use exchange_operations::ExchangeOperationsTrait;
use logging_operations::LoggingOperationsTrait;
use memory_operations::MemoryOperationTrait;
use push_operations::PushOperationsTrait;
use sha3::Sha3Trait;
use stop_and_arithmetic_operations::StopAndArithmeticOperationsTrait;
use system_operations::SystemOperationsTrait;