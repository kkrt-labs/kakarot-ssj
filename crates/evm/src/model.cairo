mod account;
mod contract_account;
mod eoa;

use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::interpreter::Status;
use evm::model::account::{Account, AccountTrait};
use evm::model::contract_account::{ContractAccountTrait};
use evm::model::eoa::EOATrait;
use evm::state::State;
use evm::stack::Stack;
use evm::memory::Memory;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{EthAddress, get_contract_address, ContractAddress};
use utils::helpers::{ResultExTrait};
use utils::traits::{EthAddressDefault, ContractAddressDefault};

#[derive(Destruct)]
struct Environment {
    origin: EthAddress,
    gas_price: u128,
    chain_id: u128,
    prevrandao: u256,
    block_number: u64,
    coinbase: EthAddress,
    timestamp: u64,
    state: State
}
#[derive(Copy, Drop)]
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
}

#[generate_trait]
impl MessageImpl of MessageTrait { //TODO
}

#[derive(Destruct)]
struct VM {
    stack: Stack,
    memory: Memory,
    pc: usize,
    valid_jumpdests: Span<usize>,
    return_data: Span<u8>,
    running: bool,
    env: Environment,
    message: Message,
    gas_used: u128
}

#[generate_trait]
impl VMImpl of VMTrait {
    fn new(message: Message, env: Environment) -> VM {
        VM {
            stack: Default::default(),
            memory: Default::default(),
            pc: 0,
            valid_jumpdests: Default::default().span(),
            return_data: Default::default().span(),
            running: true,
            env,
            message,
            gas_used: 0
        }
    }

    /// Increments the gas_used field of the current execution context by the value amount.
    /// # Error : returns `EVMError::OutOfGas` if gas_used + new_gas >= limit
    #[inline(always)]
    fn charge_gas(ref self: VM, value: u128) -> Result<(), EVMError> {
        let new_gas_used = self.gas_used + value;
        if (new_gas_used >= self.message().gas_limit) {
            return Result::Err(EVMError::OutOfGas);
        }
        self.gas_used = new_gas_used;
        Result::Ok(())
    }


    fn pc(self: @VM) -> usize {
        *self.pc
    }

    fn set_pc(ref self: VM, pc: usize) {
        self.pc = pc;
    }

    fn valid_jumpdests(self: @VM) -> Span<usize> {
        *self.valid_jumpdests
    }

    fn return_data(self: @VM) -> Span<u8> {
        *self.return_data
    }

    fn running(self: @VM) -> bool {
        *self.running
    }

    fn message(self: @VM) -> Message {
        *self.message
    }

    fn gas_used(self: @VM) -> u128 {
        *self.gas_used
    }

    /// Reads and return data from bytecode.
    /// The program counter is incremented accordingly.
    ///
    /// # Arguments
    ///
    /// * `self` - The `ExecutionContext` instance to read the data from.
    /// * `len` - The length of the data to read from the bytecode.
    #[inline(always)]
    fn read_code(self: @VM, len: usize) -> Span<u8> {
        // Copy code slice from [pc, pc+len]
        let code = self.message().code.slice(self.pc(), len);
        code
    }
}

#[derive(Drop)]
struct ExecutionResult {
    success: bool,
    return_data: Span<u8>,
}

#[derive(Destruct)]
struct ExecutionSummary {
    state: State,
    return_data: Span<u8>,
    address: EthAddress,
    success: bool
}

/// The struct representing an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}

#[derive(Copy, Drop, PartialEq, Default)]
struct Address {
    evm: EthAddress,
    starknet: ContractAddress,
}

#[generate_trait]
impl AddressImpl of AddressTrait {
    fn is_deployed(self: @EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let maybe_account = kakarot_state.address_registry(*self);
        match maybe_account {
            Option::Some(_) => true,
            Option::None => false
        }
    }

    fn fetch_balance(self: @Address) -> u256 {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let native_token_address = kakarot_state.native_token();
        let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
        native_token.balanceOf(*self.starknet)
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

/// An EVM Account is either an EOA or a Contract Account.  In both cases, the
/// account is identified by an Ethereum address.  It has a corresponding
/// Starknet Address - The corresponding Starknet Contract for EOAs, and the
/// KakarotCore address for ContractAccounts.
#[derive(Copy, Drop, PartialEq, Serde)]
enum AccountType {
    EOA,
    ContractAccount,
    Unknown
}
