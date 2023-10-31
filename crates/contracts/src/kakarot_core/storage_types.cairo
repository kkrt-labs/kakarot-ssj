use core::traits::Into;
use starknet::{ContractAddress, StorePacking};
use utils::constants::POW_2_8;
use utils::math::Bitshift;
use utils::traits::U256TryIntoContractAddress;

// Local enum to differentiate EOA and CA in storage
// TODO: remove distinction between EOA and CA as EVM accounts
// As soon as EOA::nonce can be handled at the application level
#[derive(Drop, Serde, PartialEq, Default)]
enum StoredAccountType {
    #[default]
    UninitializedAccount,
    EOA: ContractAddress,
    ContractAccount: ContractAddress,
}

const MASK_8: u256 = 0xff;


impl StoredAccountTypeStorePacking of StorePacking<StoredAccountType, felt252> {
    fn pack(value: StoredAccountType) -> felt252 {
        match value {
            StoredAccountType::UninitializedAccount => 0,
            StoredAccountType::EOA(address) => 1 + address.into() * POW_2_8.into(),
            StoredAccountType::ContractAccount(address) => 2 + address.into() * POW_2_8.into(),
        }
    }

    fn unpack(value: felt252) -> StoredAccountType {
        let value: u256 = value.into();
        let discriminant: u8 = (value & MASK_8).try_into().expect('Type flag should be 1 byte');
        if discriminant == 0 {
            return StoredAccountType::UninitializedAccount;
        }

        let address: ContractAddress = value
            .shr(8)
            .try_into()
            .expect('Address should fit in 251 bytes');
        if discriminant == 1 {
            return StoredAccountType::EOA(address);
        }
        if discriminant == 2 {
            return StoredAccountType::ContractAccount(address);
        }

        // SHOULD be unreachable code
        return StoredAccountType::UninitializedAccount;
    }
}
