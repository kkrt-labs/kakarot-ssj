// Migrate https://github.com/kkrt-labs/kakarot/blob/7ec7a96074394ddb592a2b6fbea279c6c5cb25a6/src/kakarot/accounts/contract/contract_account.cairo#L4
// Note that we don't need proxies anymore with the new idiomatic way to replace implementations.
// For now, as discussed with Shahar Papini, we can still use storage slots to store bytecode.
// That being said, we can modify the way we store it with new mappings and storage outlays to optimize steps.
// Use Traits, impls blocks and idiomatic Cairo 1.0

