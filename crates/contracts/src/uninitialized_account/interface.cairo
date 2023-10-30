use starknet::ClassHash;

#[starknet::interface]
trait IUninitializedAccount<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
