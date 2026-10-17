// RESEARCH CANDIDATE: not compiled or executed in Rust. Insert after
// helper_one in the inspected shaped candidate's private_block/protocol.rs.
// The public table and challenges belong to this proof only. No static cache.

fn pair_denominator_inverses(
    table: &[i64], alpha: Fp2, beta: Fp2, tag: Fp2,
) -> Vec<Option<Fp2>> {
    let den: Vec<Fp2> = table.iter().enumerate().map(|(i, v)| {
        alpha.sub(Fp2::from_i64(i as i64)
            .add(beta.mul(Fp2::from_i64(*v))).add(tag))
    }).collect();
    // Construction MUST NOT refuse: an unused zero is still checked later
    // by the unchanged public-table inversions, in their original order.
    let mut nonzero: Vec<Fp2> = den.iter().copied()
        .filter(|d| !d.is_zero()).collect();
    crate::field::batch_inverse2(&mut nonzero);
    let mut next = nonzero.into_iter();
    den.iter().map(|d| if d.is_zero() { None } else { next.next() }).collect()
}

fn helper_inverses_pairs(
    indices: &[i64], values: &[i64], table: &[i64],
    alpha: Fp2, beta: Fp2, tag: Fp2,
) -> Result<Vec<Fp2>, String> {
    let cache = pair_denominator_inverses(table, alpha, beta, tag);
    // Preserve the old zip semantics; the caller's existing witness-shape
    // gate establishes equal lengths. Do not introduce a new refusal here.
    indices.iter().zip(values.iter()).map(|(i, v)| {
        if let Ok(k) = usize::try_from(*i) {
            if table.get(k) == Some(v) {
                return cache[k].ok_or_else(|| ZERO_DENOMINATOR.to_string());
            }
        }
        // Invalid pairs remain invalid witness values, evaluated using the
        // original denominator, rather than silently replaced by table[i].
        let den = alpha.sub(Fp2::from_i64(*i)
            .add(beta.mul(Fp2::from_i64(*v))).add(tag));
        if den.is_zero() {
            Err(ZERO_DENOMINATOR.to_string())
        } else {
            Ok(den.inv())
        }
    }).collect()
}
