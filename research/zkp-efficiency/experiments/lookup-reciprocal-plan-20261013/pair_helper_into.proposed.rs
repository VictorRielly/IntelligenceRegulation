// REVIEW ONLY: uncompiled/unapplied Rust sketch, cycle0046. No native gate passed.
// Intended private protocol.rs insertion next to helper_one/write_h.
// Construct/use/drop in one prove_inner call AFTER alpha/beta/gamma draws.
// Replace only lines908..911; all table inversions at941 and masks stay intact.
// Fp/Fp2/U8_LEN/ZERO_DENOMINATOR already imported in protocol.rs.
// For activation, convert its public i16 table to256 i64 words (2KiB) once.
// Never return a prepared handle or persist reciprocals across proof calls.

fn pair_helper_into(
    indices: &[i64], values: &[i64], table: &[i64; U8_LEN],
    alpha: Fp2, beta: Fp2, tag: Fp2,
    h: &mut [Fp], off: (usize, usize),
) -> Result<(), String> {
    const CHUNK: usize = 1024; // Public scheduling choice; native A/B still owed.
    // Preserve the original zip length, including malformed unequal slices.
    let len = indices.len().min(values.len());
    let use_cache = len >= U8_LEN; // Short-column negative from cycle0004.
    let denominator = |i: i64, v: i64| alpha.sub(
        Fp2::from_i64(i).add(beta.mul(Fp2::from_i64(v))).add(tag)
    );
    let mut recip = [Fp2::ZERO; U8_LEN];
    let mut usable = [false; U8_LEN];
    if use_cache {
        let mut ds = Vec::with_capacity(U8_LEN);
        for i in 0..U8_LEN {
            let d = denominator(i as i64, table[i]);
            usable[i] = !d.is_zero();
            if usable[i] { ds.push(d); }
        }
        crate::field::batch_inverse2(&mut ds); // Nonzero-only, never early refusal.
        let mut at = 0;
        for i in 0..U8_LEN {
            if usable[i] { recip[i] = ds[at]; at += 1; }
        }
    }
    // Borrowed input and H destination stay alive. Only chunk scratch exists;
    // batch_inverse2_checked itself adds a same-length prefix Vec.
    let mut ds = Vec::with_capacity(CHUNK);
    let mut positions = Vec::with_capacity(CHUNK);
    for start in (0..len).step_by(CHUNK) {
        ds.clear(); positions.clear();
        for j in start..(start + CHUNK).min(len) {
            let (i, v) = (indices[j], values[j]);
            let hit = if use_cache {
                usize::try_from(i).ok().filter(|&k| k < U8_LEN && table[k] == v)
            } else { None };
            if let Some(k) = hit {
                if !usable[k] { return Err(ZERO_DENOMINATOR.to_string()); }
                h[off.0 + j] = recip[k].c0;
                h[off.1 + j] = recip[k].c1;
            } else {
                ds.push(denominator(i, v)); positions.push(j);
            }
        }
        crate::field::batch_inverse2_checked(&mut ds)
            .map_err(|_| ZERO_DENOMINATOR.to_string())?;
        for (&j, x) in positions.iter().zip(ds.iter()) {
            h[off.0 + j] = x.c0; h[off.1 + j] = x.c1;
        }
    }
    // Partial private H writes on Err MUST die with the failed attempt before
    // any H commitment, RNG draw, transcript absorb, or externally visible file.
    // Owner must establish that lifetime/order condition on the actual caller.
    Ok(())
}

// Caller sketch (no external prepared Plan type):
// pair_helper_into(&deltas, &wit.planes[ids.at(A_E)], &public.exp,
//     alpha, beta, g_exp, &mut h_data, lay.h_off[hids.sexp()])?;
// let act_table: [i64; U8_LEN] = std::array::from_fn(|i| i64::from(ff.act[i]));
// pair_helper_into(&act_idx, &wit.planes[ids.at(A_A16)], &act_table,
//     alpha, beta, g_act, &mut h_data, lay.h_off[hids.fact()])?;
// Everything after these lines stays in its existing order, especially941.
