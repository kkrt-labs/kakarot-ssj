use starknet::ClassHash;

#[starknet::interface]
trait IAccount<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
