mod account;
mod vm;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};

use core::num::traits::Zero;
use core::num::traits::{CheckedAdd, CheckedSub, CheckedMul};
use core::starknet::{EthAddress, get_contract_address, ContractAddress};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::model::account::{Account, AccountTrait};
use evm::state::State;
use utils::fmt::{TSpanSetDebug};
use utils::helpers::{ResultExTrait};
use utils::set::{Set, SpanSet};
use utils::traits::{EthAddressDefault, ContractAddressDefault, SpanDefault};

const FIRST_ROLLUP_PRECOMPILE_ADDRESS: u256 = 0x100;
const LAST_ETHEREUM_PRECOMPILE_ADDRESS: u256 = 0x0a;
const ZERO: felt252 = 0x0;

#[derive(Destruct, Default)]
struct Environment {
    origin: EthAddress,
    gas_price: u128,
    chain_id: u128,
    prevrandao: u256,
    block_number: u64,
    block_gas_limit: u128,
    block_timestamp: u64,
    coinbase: EthAddress,
    base_fee: u128,
    state: State
}
#[derive(Copy, Drop, Default, PartialEq, Debug)]
struct Message {
    caller: Address,
    target: Address,
    gas_limit: u128,
    data: Span<u8>,
    code: Span<u8>,
    value: u256,
    should_transfer_value: bool,
    depth: usize,
    read_only: bool,
    accessed_addresses: SpanSet<EthAddress>,
    accessed_storage_keys: SpanSet<(EthAddress, u256)>,
}

#[derive(Drop, Debug)]
struct ExecutionResult {
    success: bool,
    return_data: Span<u8>,
    gas_left: u128,
    accessed_addresses: SpanSet<EthAddress>,
    accessed_storage_keys: SpanSet<(EthAddress, u256)>,
    gas_refund: u128,
}

#[generate_trait]
impl ExecutionResultImpl of ExecutionResultTrait {
    fn exceptional_failure(
        error: Span<u8>,
        accessed_addresses: SpanSet<EthAddress>,
        accessed_storage_keys: SpanSet<(EthAddress, u256)>
    ) -> ExecutionResult {
        ExecutionResult {
            success: false,
            return_data: error,
            gas_left: 0,
            accessed_addresses,
            accessed_storage_keys,
            gas_refund: 0,
        }
    }

    /// Decrements the gas_left field of the current execution context by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_left - value < 0
    #[inline(always)]
    fn charge_gas(ref self: ExecutionResult, value: u128) -> Result<(), EVMError> {
        self.gas_left = self.gas_left.checked_sub(value).ok_or(EVMError::OutOfGas)?;
        Result::Ok(())
    }
}

#[derive(Destruct)]
struct ExecutionSummary {
    success: bool,
    return_data: Span<u8>,
    gas_left: u128,
    state: State,
    gas_refund: u128
}

#[generate_trait]
impl ExecutionSummaryImpl of ExecutionSummaryTrait {
    fn exceptional_failure(error: Span<u8>) -> ExecutionSummary {
        ExecutionSummary {
            success: false,
            return_data: error,
            gas_left: 0,
            state: Default::default(),
            gas_refund: 0
        }
    }
}

struct TransactionResult {
    success: bool,
    return_data: Span<u8>,
    gas_used: u128,
    state: State
}

#[generate_trait]
impl TransactionResultImpl of TransactionResultTrait {
    fn exceptional_failure(error: Span<u8>, gas_used: u128) -> TransactionResult {
        TransactionResult {
            success: false, return_data: error, gas_used, state: Default::default()
        }
    }
}

/// The struct representing an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}

#[derive(Copy, Drop, PartialEq, Default, Debug)]
struct Address {
    evm: EthAddress,
    starknet: ContractAddress,
}

#[generate_trait]
impl AddressImpl of AddressTrait {
    fn is_deployed(self: @EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let address = kakarot_state.address_registry(*self);
        return address.is_non_zero();
    }

    /// Check whether an address for a call-family opcode is a precompile.
    fn is_precompile(self: EthAddress) -> bool {
        let self: felt252 = self.into();
        return self != ZERO && (self.into() < LAST_ETHEREUM_PRECOMPILE_ADDRESS || self.into() == FIRST_ROLLUP_PRECOMPILE_ADDRESS);
    }
}

/// A struct to save native token transfers to be made when finalizing
/// a tx
#[derive(Copy, Drop, PartialEq)]
struct Transfer {
    sender: Address,
    recipient: Address,
    amount: u256
}

#[cfg(test)]
mod tests {
    use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
    use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
    use contracts::test_utils::{
        setup_contracts_for_testing, fund_account_with_native_token, deploy_contract_account
    };
    use core::starknet::EthAddress;
    use core::starknet::testing::set_contract_address;
    use core::iter::{IntoIterator, Iterator};
    use evm::backend::starknet_backend;
    use evm::model::account::AccountTrait;

    use evm::model::{Address, Account, AddressTrait};
    use evm::state::StateTrait;
    use evm::state::{State, StateChangeLog, StateChangeLogTrait};
    use evm::test_utils::{evm_address};
    use openzeppelin::token::erc20::interface::IERC20CamelDispatcherTrait;

    #[test]
    fn test_is_deployed_eoa_exists() {
        // Given
        let (_, kakarot_core) = setup_contracts_for_testing();
        starknet_backend::deploy(evm_address()).expect('failed deploy eoa account',);

        // When
        set_contract_address(kakarot_core.contract_address);
        let is_deployed = evm_address().is_deployed();

        // Then
        assert(is_deployed, 'account should be deployed');
    }

    #[test]
    fn test_is_deployed_ca_exists() {
        // Given
        setup_contracts_for_testing();
        deploy_contract_account(evm_address(), [].span());

        // When
        let is_deployed = evm_address().is_deployed();

        // Then
        assert(is_deployed, 'account should be deployed');
    }

    #[test]
    fn test_is_deployed_undeployed() {
        // Given
        let (_, kakarot_core) = setup_contracts_for_testing();

        // When
        set_contract_address(kakarot_core.contract_address);
        let is_deployed = evm_address().is_deployed();

        // Then
        assert(!is_deployed, 'account shouldnt be deployed');
    }


    #[test]
    fn test_account_balance_eoa() {
        // Given
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let eoa_address = starknet_backend::deploy(evm_address())
            .expect('failed deploy eoa account',);

        fund_account_with_native_token(eoa_address.starknet, native_token, 0x1);

        // When
        set_contract_address(kakarot_core.contract_address);
        let account = AccountTrait::fetch(evm_address()).unwrap();
        let balance = account.balance();

        // Then
        assert(balance == native_token.balanceOf(eoa_address.starknet), 'wrong balance');
    }

    #[test]
    fn test_address_balance_eoa() {
        // Given
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        let eoa_address = starknet_backend::deploy(evm_address())
            .expect('failed deploy eoa account',);

        fund_account_with_native_token(eoa_address.starknet, native_token, 0x1);

        // When
        set_contract_address(kakarot_core.contract_address);
        let account = AccountTrait::fetch(evm_address()).unwrap();
        let balance = account.balance();

        // Then
        assert(balance == native_token.balanceOf(eoa_address.starknet), 'wrong balance');
    }


    #[test]
    fn test_account_has_code_or_nonce_empty() {
        // Given
        setup_contracts_for_testing();
        let mut _eoa_address = starknet_backend::deploy(evm_address()).expect('failed deploy eoa',);

        // When
        let account = AccountTrait::fetch(evm_address()).unwrap();

        // Then
        assert_eq!(account.has_code_or_nonce(), false);
    }


    #[test]
    fn test_account_has_code_or_nonce_contract_account() {
        // Given
        setup_contracts_for_testing();
        let mut _ca_address = deploy_contract_account(evm_address(), [].span());

        // When
        let account = AccountTrait::fetch(evm_address()).unwrap();

        // Then
        assert(account.has_code_or_nonce() == true, 'account shouldhave codeornonce');
    }


    #[test]
    fn test_account_has_code_or_nonce_undeployed() {
        // Given
        setup_contracts_for_testing();

        // When
        let account = AccountTrait::fetch_or_create(evm_address());

        // Then
        assert(account.has_code_or_nonce() == false, 'account has codeornonce');
    }

    #[test]
    fn test_account_has_code_or_nonce_account_to_deploy() {
        // Given
        setup_contracts_for_testing();

        // When
        let mut account = AccountTrait::fetch_or_create(evm_address());
        // Mock account as an existing contract account in the cached state.
        account.nonce = 1;
        account.code = [0x1].span();

        // Then
        assert(account.has_code_or_nonce() == true, 'account should exist');
    }


    #[test]
    fn test_account_balance_contract_account() {
        // Given
        let (native_token, _) = setup_contracts_for_testing();
        let mut ca_address = deploy_contract_account(evm_address(), [].span());

        fund_account_with_native_token(ca_address.starknet, native_token, 0x1);

        // When
        let account = AccountTrait::fetch(evm_address()).unwrap();
        let balance = account.balance();

        // Then
        assert(balance == native_token.balanceOf(ca_address.starknet), 'wrong balance');
    }

    #[test]
    fn test_account_commit_already_deployed_should_not_change_code() {
        setup_contracts_for_testing();
        let mut ca_address = deploy_contract_account(evm_address(), [].span());

        let mut state: State = Default::default();

        // When
        let mut account = AccountTrait::fetch(evm_address()).unwrap();
        account.nonce = 420;
        account.code = [0x1].span();
        state.set_account(account);
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then
        let account_dispatcher = IAccountDispatcher { contract_address: ca_address.starknet };
        let nonce = account_dispatcher.get_nonce();
        let code = account_dispatcher.bytecode();
        assert(nonce == 420, 'account should be committed');
        assert!(code != [0x1].span(), "code should not be mofidied unless account is created")
    }

    #[test]
    fn test_account_commit_created_but_already_deployed() {
        setup_contracts_for_testing();
        let mut ca_address = deploy_contract_account(evm_address(), [].span());

        // When created in this same tx, the account should have a new code.

        let mut state: State = Default::default();
        let mut account = AccountTrait::fetch(evm_address()).unwrap();
        account.set_created(true);
        account.nonce = 420;
        account.code = [0x1].span();
        state.set_account(account);
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then
        let account_dispatcher = IAccountDispatcher { contract_address: ca_address.starknet };
        let nonce = account_dispatcher.get_nonce();
        let code = account_dispatcher.bytecode();
        assert(nonce == 420, 'nonce should be modified');
        assert(code == [0x1].span(), 'code should be modified');
    }

    #[test]
    fn test_account_commit_undeployed() {
        let (_, kakarot_core) = setup_contracts_for_testing();

        let evm = evm_address();
        let starknet = kakarot_core.compute_starknet_address(evm);
        let mut state: State = Default::default();
        // When
        let mut account = Account {
            address: Address { evm, starknet }, nonce: 420, code: [
                0x69
            ].span(), balance: 0, selfdestruct: false, is_created: true,
        };
        state.set_account(account);
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then
        let account_dispatcher = IAccountDispatcher { contract_address: starknet };
        let nonce = account_dispatcher.get_nonce();
        let code = account_dispatcher.bytecode();
        assert(nonce == 420, 'nonce should be committed');
        assert(code == [0x69].span(), 'code should be committed');
    }

    #[test]
    fn test_address_balance_contract_account() {
        // Given
        let (native_token, _) = setup_contracts_for_testing();
        let mut ca_address = deploy_contract_account(evm_address(), [].span());

        fund_account_with_native_token(ca_address.starknet, native_token, 0x1);

        // When
        let account = AccountTrait::fetch(evm_address()).unwrap();
        let balance = account.balance();

        // Then
        assert(balance == native_token.balanceOf(ca_address.starknet), 'wrong balance');
    }

    #[test]
    fn test_is_precompile(){
       // Given
       let mut i = 0;
       let valid_precompiles = array![0x1,0x2,0x3,0x4,0x5,0x6,0x7,0x8,0x9,0x100];
       let to = valid_precompiles.len() - 1;

       // When
       loop {
               if i >= to{
                   break();
               }
               let evm_address: EthAddress = (*valid_precompiles.at(i)).try_into().unwrap();
               //Then
               assert_eq!(true, evm_address.is_precompile());
               i = i + 1;
           };
    }

    #[test]
    fn test_is_precompile_zero(){
      // Given
      let evm_address: EthAddress = 0.try_into().unwrap();

      // When
      let is_precompile = evm_address.is_precompile();

      // Then
      assert_eq!(false, is_precompile);
    }

    #[test]
    fn test_is_not_precompile(){
      // Given
      let mut i = 0;
      let not_valid_precompiles = array![0xa,0xb,0xc,0xd,0xe,0xf,0x99];
      let to = not_valid_precompiles.len() - 1;

      // When
      loop {
               if i >= to{
                   break();
               }
               let evm_address: EthAddress = (*not_valid_precompiles.at(i)).try_into().unwrap();
               //Then
               assert_eq!(false, evm_address.is_precompile());
               i = i + 1;
           };
    }
}
