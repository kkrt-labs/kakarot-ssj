mod contract_account;
mod eoa;
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use evm::errors::EVMError;
use evm::execution::Status;
use evm::model::contract_account::{ContractAccount, ContractAccountTrait};
use evm::model::eoa::{EOA, EOATrait};
use starknet::{EthAddress, get_contract_address, ContractAddress};

#[derive(Drop)]
struct Event {
    keys: Array<u256>,
    data: Array<u8>,
}

struct ExecutionResult {
    status: Status,
    return_data: Span<u8>,
    create_addresses: Span<EthAddress>,
    destroyed_contracts: Span<EthAddress>,
    events: Span<Event>
}


/// An EVM Account is either an EOA or a Contract Account.  In both cases, the
/// account is identified by an Ethereum address.  It has a corresponding
/// Starknet Address - The corresponding Starknet Contract for EOAs, and the
/// KakarotCore address for ContractAccounts.
#[derive(Copy, Drop)]
enum Account {
    EOA: EOA,
    ContractAccount: ContractAccount
}

#[generate_trait]
impl AccountImpl of AccountTrait {
    /// Returns the Account corresponding to an Ethereum address.
    /// If the address is not an EOA or a Contract Account (meaning that it is not deployed), returns None.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to look up.
    ///
    /// # Returns
    ///
    /// A `Result` containing an `Option` of the corresponding `Account` or an `EVMError` if there was an error.
    ///
    /// # Errors
    ///
    /// Returns an `EVMError` if there was an error while retrieving the nonce account of the account contract using the read_syscall.
    fn account_at(address: EthAddress) -> Result<Option<Account>, EVMError> {
        //TODO: refactor this to directly read from the correct storage slot
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let eoa_starknet_address = kakarot_state.eoa_starknet_address(address);

        if !eoa_starknet_address.is_zero() {
            return Result::Ok(
                Option::Some(
                    Account::EOA(
                        EOA { evm_address: address, starknet_address: eoa_starknet_address }
                    )
                )
            );
        } else {
            let ca = ContractAccountTrait::new(address);
            let nonce = ca.nonce()?;
            if nonce != 0 {
                return Result::Ok(Option::Some(Account::ContractAccount(ca)));
            }
        }
        return Result::Ok(Option::None);
    }

    /// Returns `true` if the account is an Externally Owned Account (EOA).
    #[inline(always)]
    fn is_eoa(self: @Account) -> bool {
        match self {
            Account::EOA => true,
            Account::ContractAccount => false
        }
    }

    /// Returns `true` if the account is a Contract Account (CA).
    #[inline(always)]
    fn is_ca(self: @Account) -> bool {
        match self {
            Account::EOA => false,
            Account::ContractAccount => true
        }
    }


    /// Returns the balance in native token for a given EVM account (EOA or CA)
    /// This is equivalent to checking the balance in native coin, i.e. ETHER of an account in Ethereum
    #[inline(always)]
    fn balance(self: @Account) -> Result<u256, EVMError> {
        match self {
            // Case 1: EOA is deployed
            // BALANCE is the EOA's native_token.balanceOf(eoa_starknet_address)
            Account::EOA(eoa) => { eoa.balance() },
            // Case 2: EOA is not deployed and CA is deployed
            // We check if a contract account is initialized at evm_address
            // A good condition to check is nonce > 0, as deploying a contract account
            // will set its nonce to 1
            Account::ContractAccount(ca) => { ca.balance() }
        }
    }
}
