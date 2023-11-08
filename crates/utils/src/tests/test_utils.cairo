fn bytes_to_felt252_array(bytes: Span<u8>) -> Span<felt252> {
    let mut result: Array<felt252> = array![];

    let mut i = 0;
    loop {
        if (i == bytes.len()) {
            break ();
        }
        result.append((*bytes.at(i)).into());
        i += 1;
    };

    result.span()
}
