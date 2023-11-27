use contracts::tests::test_data::counter_evm_bytecode;
use evm::create_helpers::MachineCreateHelpers;
use evm::tests::test_utils::{MachineBuilderTestTrait};
use starknet::EthAddress;
use utils::address::{compute_contract_address, compute_create2_contract_address};
