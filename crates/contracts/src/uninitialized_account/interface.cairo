use starknet::ClassHash;

#[starknet::interface]
trait IUninitializedAccount<TContractState> {
    fn initialize(ref self: TContractState, new_class_hash: ClassHash);
}
