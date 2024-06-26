use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait, IAccount};
use contracts::kakarot_core::kakarot::KakarotCore::KakarotCoreInternal;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::num::traits::Zero;
use core::traits::TryInto;
use evm::backend::starknet_backend::fetch_balance;
use evm::errors::{EVMError, CONTRACT_SYSCALL_FAILED};
use evm::model::{Address, AddressTrait, Transfer};
use evm::state::State;
use evm::state::StateTrait;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use starknet::{
    ContractAddress, EthAddress, get_contract_address, deploy_syscall, get_tx_info,
    SyscallResultTrait
};
use utils::helpers::{ResultExTrait, ByteArrayExTrait, compute_starknet_address};

#[derive(Drop)]
struct AccountBuilder {
    account: Account
}

#[generate_trait]
impl AccountBuilderImpl of AccountBuilderTrait {
    fn new(address: Address) -> AccountBuilder {
        AccountBuilder {
            account: Account {
                address: address,
                code: array![].span(),
                nonce: 0,
                balance: 0,
                selfdestruct: false,
                is_created: false
            }
        }
    }

    #[inline(always)]
    fn fetch_balance(mut self: AccountBuilder) -> AccountBuilder {
        self.account.balance = fetch_balance(@self.account.address);
        self
    }

    #[inline(always)]
    fn fetch_nonce(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        self.account.nonce = account.get_nonce();
        self
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a
    /// Span<u8>.
    /// # Arguments
    /// * `self` - The address of the Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    fn fetch_bytecode(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        let bytecode = account.bytecode();
        self.account.code = bytecode;
        self
    }

    #[inline(always)]
    fn build(self: AccountBuilder) -> Account {
        self.account
    }
}

#[derive(Copy, Drop, PartialEq)]
struct Account {
    address: Address,
    code: Span<u8>,
    nonce: u64,
    balance: u256,
    selfdestruct: bool,
    is_created: bool,
}

#[generate_trait]
impl AccountImpl of AccountTrait {
    /// Fetches an account from Starknet
    /// An non-deployed account is just an empty account.
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise a new empty account.
    fn fetch_or_create(evm_address: EthAddress) -> Account {
        let maybe_acc = Self::fetch(evm_address);

        match maybe_acc {
            Option::Some(account) => account,
            Option::None => {
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let starknet_address = kakarot_state.compute_starknet_address(evm_address);
                // If no account exists at `address`, then we are trying to
                // access an undeployed account (CA or EOA). We create an
                // empty account with the correct address and return it.
                AccountBuilderTrait::new(Address { starknet: starknet_address, evm: evm_address })
                    .fetch_balance()
                    .build()
            }
        }
    }

    /// Fetches an account from Starknet
    ///
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise `None`.
    fn fetch(evm_address: EthAddress) -> Option<Account> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let starknet_address = kakarot_state.address_registry(evm_address);
        if starknet_address.is_zero() {
            return Option::None;
        }
        let address = Address { starknet: starknet_address, evm: evm_address };
        Option::Some(
            AccountBuilderTrait::new(address).fetch_nonce().fetch_bytecode().fetch_balance().build()
        )
    }


    /// Returns whether an account exists at the given address by checking
    /// whether it has code or a nonce.
    ///
    /// # Arguments
    ///
    /// * `account` - The instance of the account to check.
    ///
    /// # Returns
    ///
    /// `true` if an account exists at this address (has code or nonce), `false` otherwise.
    #[inline(always)]
    fn has_code_or_nonce(self: @Account) -> bool {
        return !(*self.code).is_empty() || *self.nonce != 0;
    }

    #[inline(always)]
    fn is_created(self: @Account) -> bool {
        *self.is_created
    }

    #[inline(always)]
    fn set_created(ref self: Account, is_created: bool) {
        self.is_created = is_created;
    }

    #[inline(always)]
    fn balance(self: @Account) -> u256 {
        *self.balance
    }

    #[inline(always)]
    fn address(self: @Account) -> Address {
        *self.address
    }

    #[inline(always)]
    fn evm_address(self: @Account) -> EthAddress {
        *self.address.evm
    }

    #[inline(always)]
    fn starknet_address(self: @Account) -> ContractAddress {
        *self.address.starknet
    }

    /// Returns the bytecode of the EVM account (EOA or CA)
    #[inline(always)]
    fn bytecode(self: @Account) -> Span<u8> {
        *self.code
    }


    /// Sets the nonce of the Account
    /// # Arguments
    /// * `self` The Account to set the nonce on
    /// * `nonce` The new nonce
    #[inline(always)]
    fn set_nonce(ref self: Account, nonce: u64) {
        self.nonce = nonce;
    }

    #[inline(always)]
    fn nonce(self: @Account) -> u64 {
        *self.nonce
    }

    /// Sets the code of the Account
    /// # Arguments
    /// * `self` The Account to set the code on
    /// * `code` The new code
    #[inline(always)]
    fn set_code(ref self: Account, code: Span<u8>) {
        self.code = code;
    }

    /// Registers an account for SELFDESTRUCT
    /// This will cause the account to be erased at the end of the transaction
    #[inline(always)]
    fn selfdestruct(ref self: Account) {
        self.selfdestruct = true;
    }

    /// Returns whether the account is registered for SELFDESTRUCT
    /// `true` means that the account will be erased at the end of the transaction
    #[inline(always)]
    fn is_selfdestruct(self: @Account) -> bool {
        *self.selfdestruct
    }

    /// Initializes a dictionary of valid jump destinations in EVM bytecode.
    ///
    /// This function iterates over the bytecode from the current index 'i'.
    /// If the opcode at the current index is between 0x5f and 0x7f (PUSHN opcodes) (inclusive),
    /// it skips the next 'n_args' opcodes, where 'n_args' is the opcode minus 0x5f.
    /// If the opcode is 0x5b (JUMPDEST), it marks the current index as a valid jump destination.
    /// It continues by jumping back to the body flag until it has processed the entire bytecode.
    ///
    /// # Arguments
    /// * `bytecode` The bytecode to analyze
    ///
    /// # Returns
    /// A dictionary of valid jump destinations in the bytecode
    fn get_jumpdests(mut bytecode: Span<u8>) -> Felt252Dict<bool> {
        let mut jumpdests: Felt252Dict<bool> = Default::default();
        let mut i: usize = 0;
        loop {
            if (i >= bytecode.len()) {
                break;
            }

            let opcode = *bytecode[i];
            // checking for PUSH opcode family
            if opcode >= 0x5f && opcode <= 0x7f {
                let n_args = opcode.into() - 0x5f;
                i += n_args + 1;
                continue;
            }

            if opcode == 0x5b {
                jumpdests.insert(i.into(), true);
            }

            i += 1;
        };
        jumpdests
    }
}

#[generate_trait]
impl AccountInternals of AccountInternalTrait {
    #[inline(always)]
    fn set_balance(ref self: Account, value: u256) {
        self.balance = value;
    }
}
