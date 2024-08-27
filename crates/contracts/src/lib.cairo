mod account_contract;
mod cairo1_helpers;
mod components;

mod errors;

// Kakarot smart contract
mod kakarot_core;

mod storage;

#[cfg(target: 'test')]
mod test_data;

#[cfg(target: 'test')]
mod test_utils;

// Account transparent proxy
mod uninitialized_account;

//TODO: hide this behind a feature flag
mod test_contracts {
    mod test_upgradeable;
}

mod mocks {
    mod cairo1_helpers_fixture;
}
