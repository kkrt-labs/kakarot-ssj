use core::option::OptionTrait;
use integer::{BoundedInt, u64_wrapping_add, U64BitNot};
use alexandria_storage::vec::{Felt252Vec, VecTrait};
use utils::math::Bitshift;

/// SIGMA from spec: https://datatracker.ietf.org/doc/html/rfc7693#section-2.7
fn SIGMA() -> Span<Span<usize>> {
    array![
        array![0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].span(),
        array![14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3].span(),
        array![11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4].span(),
        array![7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8].span(),
        array![9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13].span(),
        array![2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9].span(),
        array![12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11].span(),
        array![13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10].span(),
        array![6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5].span(),
        array![10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0].span(),
    ]
        .span()
}

/// got IV from: https://en.wikipedia.org/wiki/BLAKE_(hash_function)
fn IV() -> Span<u64> {
    array![
        0x6a09e667f3bcc908,
        0xbb67ae8584caa73b,
        0x3c6ef372fe94f82b,
        0xa54ff53a5f1d36f1,
        0x510e527fade682d1,
        0x9b05688c2b3e6c1f,
        0x1f83d9abfb41bd6b,
        0x5be0cd19137e2179,
    ]
        .span()
}

fn rotate_right(value: u64, n: u32) -> u64 {
    if n == 0 {
        value // No rotation needed
    } else {
        let bits = 64; // The number of bits in a u64
        let n = n % bits; // Ensure n is less than 64
        value.shr(n.into()) | value.shl((bits - n).into())
    }
}

fn compress(rounds: usize, h: Span<u64>, m: Span<u64>, t: Span<u64>, f: bool) -> Span<u64> {
    let mut v = VecTrait::<Felt252Vec, u64>::new();
    let IV = IV();

    let mut i = 0;
    loop {
        if (i == h.len()) {
            break;
        }

        v.set(i, *h[i]);
        v.set(i + h.len(), *IV[i]);

        i += 1;
    };

    v.set(12, v.get(12).unwrap() ^ *t[0]);
    v.set(13, v.get(13).unwrap() ^ *t[1]);

    if f {
        v.set(14, U64BitNot::bitnot((v.get(14).unwrap())));
    }

    let mut i = 0;
    loop {
        if i == rounds {
            break;
        }

        let s = *(SIGMA()[i % 10]);

        g(ref v, 0, 4, 8, 12, *m[*s[0]], *m[*s[1]]);
        g(ref v, 1, 5, 9, 13, *m[*s[2]], *m[*s[3]]);
        g(ref v, 2, 6, 10, 14, *m[*s[4]], *m[*s[5]]);
        g(ref v, 3, 7, 11, 15, *m[*s[6]], *m[*s[7]]);

        g(ref v, 0, 5, 10, 15, *m[*s[8]], *m[*s[9]]);
        g(ref v, 1, 6, 11, 12, *m[*s[10]], *m[*s[11]]);
        g(ref v, 2, 7, 8, 13, *m[*s[12]], *m[*s[13]]);
        g(ref v, 3, 4, 9, 14, *m[*s[14]], *m[*s[15]]);

        i += 1;
    };

    let mut result: Array<u64> = Default::default();

    let mut i = 0;
    loop {
        if (i == 8) {
            break;
        }

        result.append(*h[i] ^ (v.get(i).unwrap() ^ v.get(i + 8).unwrap()));

        i += 1;
    };

    result.span()
}

fn g(ref v: Felt252Vec<u64>, a: usize, b: usize, c: usize, d: usize, x: u64, y: u64) {
    let mut v_a = v.get(a).unwrap();
    let mut v_b = v.get(b).unwrap();
    let mut v_c = v.get(c).unwrap();
    let mut v_d = v.get(d).unwrap();

    v_a = u64_wrapping_add(u64_wrapping_add(v_a, v_b), x);
    v_d = rotate_right(v_d ^ v_a, 32);
    v_c = u64_wrapping_add(v_c, v_d);
    v_b = rotate_right(v_b ^ v_c, 24);
    v_a = u64_wrapping_add(u64_wrapping_add(v_a, v_b), y);
    v_d = rotate_right(v_d ^ v_a, 16);
    v_c = u64_wrapping_add(v_c, v_d);
    v_b = rotate_right(v[b] ^ v[c], 63);

    v.set(a, v_a);
    v.set(b, v_b);
    v.set(c, v_c);
    v.set(d, v_d);
}
