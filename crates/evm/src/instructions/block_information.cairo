//! Block Information.

use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::starknet::SyscallResultTrait;

use evm::errors::{
    EVMError, BLOCK_HASH_SYSCALL_FAILED, EXECUTION_INFO_SYSCALL_FAILED, TYPE_CONVERSION_ERROR
};

use evm::gas;
use evm::model::account::{AccountTrait};
use evm::model::vm::{VM, VMTrait};
use evm::model::{Account};
use evm::stack::StackTrait;
use evm::state::StateTrait;

// Corelib imports
use starknet::info::get_block_number;
use starknet::{get_block_hash_syscall, EthAddress};

use utils::helpers::ResultExTrait;
use utils::traits::{EthAddressTryIntoResultContractAddress, EthAddressIntoU256};

#[generate_trait]
impl BlockInformation of BlockInformationTrait {
    /// 0x40 - BLOCKHASH
    /// Get the hash of one of the 256 most recent complete blocks.
    /// # Specification: https://www.evm.codes/#40?fork=shanghai
    fn exec_blockhash(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BLOCKHASH)?;

        let block_number = self.stack.pop_u64()?;
        let current_block = self.env.block_number;

        // If input block number is lower than current_block - 256, return 0
        // If input block number is higher than current_block - 10, return 0
        // Note: in the specs, input block number can be equal - at most - to the current block
        // number minus one.
        // In Starknet, the `get_block_hash_syscall` is capped at current block minus ten.
        // TODO: monitor the changes in the `get_block_hash_syscall` syscall.
        // source:
        // https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/system-calls-cairo1/#get_block_hash
        if block_number + 10 > current_block || block_number + 256 < current_block {
            return self.stack.push(0);
        }

        self.stack.push(get_block_hash_syscall(block_number).unwrap_syscall().into())
    }

    /// 0x41 - COINBASE
    /// Get the block's beneficiary address.
    /// # Specification: https://www.evm.codes/#41?fork=shanghai
    fn exec_coinbase(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let coinbase = self.env.coinbase;
        self.stack.push(coinbase.into())
    }

    /// 0x42 - TIMESTAMP
    /// Get the block’s timestamp
    /// # Specification: https://www.evm.codes/#42?fork=shanghai
    fn exec_timestamp(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_timestamp.into())
    }

    /// 0x43 - NUMBER
    /// Get the block number.
    /// # Specification: https://www.evm.codes/#43?fork=shanghai
    fn exec_number(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_number.into())
    }

    /// 0x44 - PREVRANDAO
    /// # Specification: https://www.evm.codes/#44?fork=shanghai
    fn exec_prevrandao(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.prevrandao)
    }

    /// 0x45 - GASLIMIT
    /// Get the block’s gas limit
    /// # Specification: https://www.evm.codes/#45?fork=shanghai
    fn exec_gaslimit(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        self.stack.push(self.env.block_gas_limit.into())
    }

    /// 0x46 - CHAINID
    /// Get the chain ID.
    /// # Specification: https://www.evm.codes/#46?fork=shanghai
    fn exec_chainid(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        let chain_id = self.env.chain_id;
        self.stack.push(chain_id.into())
    }

    /// 0x47 - SELFBALANCE
    /// Get balance of currently executing contract
    /// # Specification: https://www.evm.codes/#47?fork=shanghai
    fn exec_selfbalance(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::LOW)?;

        let evm_address = self.message().target.evm;

        let balance = self.env.state.get_account(evm_address).balance;

        self.stack.push(balance)
    }

    /// 0x48 - BASEFEE
    /// Get base fee.
    /// # Specification: https://www.evm.codes/#48?fork=shanghai
    fn exec_basefee(ref self: VM) -> Result<(), EVMError> {
        self.charge_gas(gas::BASE)?;

        // Get the current base fee. (Kakarot doesn't use EIP 1559 so basefee
        //  doesn't really exists there so we just use the gas price)
        self.stack.push(self.env.gas_price.into())
    }
}


#[cfg(test)]
mod tests {
    use contracts::kakarot_core::interface::{
        IExtendedKakarotCoreDispatcher, IExtendedKakarotCoreDispatcherTrait
    };

    use contracts::test_utils::{
        setup_contracts_for_testing, fund_account_with_native_token, deploy_contract_account,
    };
    use core::result::ResultTrait;
    use evm::instructions::BlockInformationTrait;
    use evm::stack::StackTrait;
    use evm::test_utils::{evm_address, VMBuilderTrait, tx_gas_limit, gas_price};
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;
    use starknet::testing::{
        set_block_timestamp, set_block_number, set_block_hash, set_contract_address,
        set_sequencer_address, ContractAddress
    };
    use utils::constants;
    use utils::traits::{EthAddressIntoU256};


    /// 0x40 - BLOCKHASH
    #[test]
    fn test_exec_blockhash_below_bounds() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        set_block_number(500);

        // When
        vm.stack.push(243).expect('push failed');
        vm.exec_blockhash().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    #[test]
    fn test_exec_blockhash_above_bounds() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        set_block_number(500);

        // When
        vm.stack.push(491).expect('push failed');
        vm.exec_blockhash().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == 0, 'stack top should be 0');
    }

    // TODO: implement exec_blockhash testing for block number within bounds
    // https://github.com/starkware-libs/cairo/blob/77a7e7bc36aa1c317bb8dd5f6f7a7e6eef0ab4f3/crates/cairo-lang-starknet/cairo_level_tests/interoperability.cairo#L173
    #[test]
    fn test_exec_blockhash_within_bounds() {
        // If not set the default block number is 0.
        let queried_block = 244;
        set_block_number(500);
        set_block_hash(queried_block, 0xF);

        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.stack.push(queried_block.into()).expect('push failed');
        vm.exec_blockhash().expect('exec failed');
        //TODO the CASM runner used in tests doesn't implement
        //`get_block_hash_syscall` yet. As such, this test should fail no if the
        //queried block is within bounds
        // Then
        assert(vm.stack.peek().unwrap() == 0xF, 'stack top should be 0xF');
    }


    #[test]
    fn test_block_timestamp_set_to_1692873993() {
        // 24/08/2023 12h46 33s
        // If not set the default timestamp is 0.
        set_block_timestamp(1692873993);

        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_timestamp().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 1692873993, 'stack top should be 1692873993');
    }

    #[test]
    fn test_block_number_set_to_32() {
        // If not set the default block number is 0.
        set_block_number(32);

        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_number().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == 32, 'stack top should be 32');
    }

    #[test]
    fn test_gaslimit() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_gaslimit().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        // This value is set in [new_with_presets].
        assert_eq!(vm.stack.peek().unwrap(), constants::BLOCK_GAS_LIMIT.into())
    }

    // *************************************************************************
    // 0x47: SELFBALANCE
    // *************************************************************************
    #[test]
    fn test_exec_selfbalance_eoa() {
        // Given
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let eoa = kakarot_core.deploy_externally_owned_account(evm_address());

        fund_account_with_native_token(eoa, native_token, 0x1);

        // And
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        set_contract_address(kakarot_core.contract_address);
        vm.exec_selfbalance().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == native_token.balanceOf(eoa), 'wrong balance');
    }

    #[test]
    fn test_exec_selfbalance_zero() {
        // Given
        let (_, kakarot_core) = setup_contracts_for_testing();

        // And
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        set_contract_address(kakarot_core.contract_address);
        vm.exec_selfbalance().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == 0x00, 'wrong balance');
    }

    #[test]
    fn test_exec_selfbalance_contract_account() {
        // Given
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let mut ca_address = deploy_contract_account(evm_address(), [].span());

        fund_account_with_native_token(ca_address.starknet, native_token, 0x1);
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        set_contract_address(kakarot_core.contract_address);
        vm.exec_selfbalance().unwrap();

        // Then
        assert(vm.stack.peek().unwrap() == 0x1, 'wrong balance');
    }


    #[test]
    fn test_basefee() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_basefee().unwrap();

        // Then
        assert(vm.stack.len() == 1, 'stack should have one element');
        assert(vm.stack.peek().unwrap() == gas_price().into(), 'stack top should be gas_price');
    }

    #[test]
    fn test_chainid_should_push_chain_id_to_stack() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_chainid().unwrap();

        // Then
        let chain_id = vm.stack.peek().unwrap();
        assert(vm.env.chain_id.into() == chain_id, 'stack should have chain id');
    }


    #[test]
    fn test_randao_should_push_zero_to_stack() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_prevrandao().unwrap();

        // Then
        let result = vm.stack.peek().unwrap();
        assert(result == 0x00, 'stack top should be zero');
    }

    // *************************************************************************
    // 0x41: COINBASE
    // *************************************************************************
    #[test]
    fn test_exec_coinbase() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        // When
        vm.exec_coinbase().unwrap();

        // Then
        let coinbase_address = vm.stack.peek().unwrap();
        assert(vm.env.coinbase.into() == coinbase_address, 'wrong coinbase address');
    }
}
