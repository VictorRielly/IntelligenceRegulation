fn as_u64s_f2_unclocked(v: &[Fp2]) -> Vec<u64> {
    let mut out = Vec::with_capacity(v.len() * 2);
    for x in v {
        out.push(x.c0.0);
        out.push(x.c1.0);
    }
    out
}
