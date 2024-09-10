/// The transaction environment.
#[derive(Copy, Drop, Debug, PartialEq)]
pub struct TxEnv {
    /// Transaction signer
    pub origin: EthAddress,
    /// The gas limit of the transaction.
    pub gas_limit: u64,
    /// The gas price of the transaction.
    pub gas_price: u128,
    /// The destination of the transaction.
    pub transact_to: TransactTo,
    /// The value sent to `transact_to`.
    pub value: u256,
    /// The data of the transaction.
    pub data: Span<u8>,
    /// The nonce of the transaction.
    pub nonce: u64,
    /// The chain ID of the transaction. If set to `None`, no checks are performed.
    ///
    /// Incorporated as part of the Spurious Dragon upgrade via [EIP-155].
    ///
    /// [EIP-155]: https://eips.ethereum.org/EIPS/eip-155
    pub chain_id: Option<u64>,
    /// A list of addresses and storage keys that the transaction plans to access.
    ///
    /// Added in [EIP-2930].
    ///
    /// [EIP-2930]: https://eips.ethereum.org/EIPS/eip-2930
    pub access_list: Span<AccessListItem>,
    /// The priority fee per gas.
    ///
    /// Incorporated as part of the London upgrade via [EIP-1559].
    ///
    /// [EIP-1559]: https://eips.ethereum.org/EIPS/eip-1559
    pub gas_priority_fee: Option<u256>,
}
