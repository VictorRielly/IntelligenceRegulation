pub(crate) fn logup_sum_claim(lay: &Layout) -> ZClaim {
    let (sh, hids) = (lay.shape(), lay.hids());
    let mut parts = Vec::with_capacity(2 * hids.n_h());
    // (test builds: the lapse of D30 condition 3 leaves the dictionary's two
    // LogUp columns out of the single sum claim)
    let out_of_sum = sh.dd_cap > 0 && super::argument::dd_lapse(super::argument::DD_LAPSE_OUT_OF_SUM);
    for p in lay.h_planes() {
        if out_of_sum && (p == hids.stuple() || p == hids.gdd()) {
            continue;
        }
        let sign = if hids.is_table(p) { Fp2::ONE.neg() } else { Fp2::ONE };
        let (re, im) = lay.h_off[p];
        let log_size = sh.log(hids.dom(p)) as u32;
        parts.push(ZPart { slice: Slice { offset: re, log_size }, coef: sign, point: vec![] });
        parts.push(ZPart { slice: Slice { offset: im, log_size }, coef: sign.mul(Fp2::U), point: vec![] });
    }
    ZClaim { parts, value: Fp2::ZERO }
}
