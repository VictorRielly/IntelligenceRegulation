// Research review snippet; NOT COMPILED, NOT a production patch.
// Insert beside SC_SZC in argument.rs; trusted Layout supplies dimensions.
// Keep the actual native constructor's pad_on policy, not geometry alone.
fn sc_szc_round0_mask_active(lay: &Layout, slot: usize, round: usize) -> Option<bool> {
    if slot != SC_SZC || round != 0 { return None; }
    let sh = lay.shape();
    let (h, t) = (sh.h_pad, sh.t_pad);
    if !h.is_power_of_two() || !t.is_power_of_two() { return None; }
    let (n, ext, _) = sh.slots()[SC_SZC];
    let lh = h.trailing_zeros() as usize;
    let lt = t.trailing_zeros() as usize;
    if n != lh + 2 * lt || ext != 1 || n == 0 { return None; }
    let pad_on = ALL_DOMS.into_iter().any(|d|
        super::pad::pad_zero_host(d) == SC_SZC &&
        !super::pad::zero_rule_a_planes(sh, lay.ids(), d).is_empty());
    if pad_on { return None; }
    // causal_mask_at(sh) is j<=t at every padded head slot. MSB data rounds
    // bind (head,t,j). Public terminal extensions are separate and zero.
    Some(lh == 0)
}

// Separate future representation change: evaluate the same public table
// without materialization on the verifier. Native Tab::Pub remains the oracle.
// To use this, add a trusted public descriptor at construction and preserve
// its position/count, length checks and original prover scalar fallback.
fn causal_public_mle(sh: &Shape, point: &[Fp2], e: Fp2) -> Option<Fp2> {
    if !sh.h_pad.is_power_of_two() || !sh.t_pad.is_power_of_two() { return None; }
    let lh = sh.h_pad.trailing_zeros() as usize;
    let lt = sh.t_pad.trailing_zeros() as usize;
    if point.len() != lh + 2 * lt { return None; }
    let mut le = Fp2::ONE;
    for k in (0..lt).rev() {
        let (t, j) = (point[lh + k], point[lh + lt + k]);
        let same = Fp2::ONE.sub(t).mul(Fp2::ONE.sub(j)).add(t.mul(j));
        le = t.mul(Fp2::ONE.sub(j)).add(same.mul(le));
    }
    Some(le.mul(Fp2::ONE.sub(e)))
}
