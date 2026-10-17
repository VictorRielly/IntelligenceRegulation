// Research interface, not applied to a native or CUDA caller.
// A residue has two i64 preimages only on [P-2^63, 2^63).
const SIGN: u64 = 1u64 << 63;
const AMBIGUOUS_LO: u64 = field::P - SIGN;
fn ambiguity_bit(v:i64, residue:u64) -> bool {
    v < 0 && residue >= AMBIGUOUS_LO && residue < SIGN
}
fn recover_word(residue:u64, negative_ambiguity:bool) -> u64 {
    // Unsigned word operations deliberately implement Z/(2^64).
    if residue >= SIGN || (residue >= AMBIGUOUS_LO && negative_ambiguity) {
        residue.wrapping_sub(field::P)
    } else { residue }
}
fn resident_lookup(raw:&[i64], a:&[u64], signs:&[u64], len:usize, l:&Lk, mode:u32) -> Vec<Fp> {
    (0..len).map(|x| {
        if mode == 2 {
            // Tempting, incorrect replacement: evaluate affine terms in Fp.
            l.terms.iter().fold(Fp::from_i64(l.cst), |s,(p,c)| s.add(Fp(a[*p*len+x]).mul(Fp::from_i64(*c))))
        } else {
            let mut word=l.cst as u64;
            for (p,c) in &l.terms {
                let j=*p*len+x;
                let bit=(signs[j/64] >> (j%64)) & 1 != 0;
                let v=recover_word(a[j],mode != 3 && bit);
                word=word.wrapping_add((*c as u64).wrapping_mul(v));
            }
            Fp::from_i64(word as i64)
        }
    }).collect()
}
