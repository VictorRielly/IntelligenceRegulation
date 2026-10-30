fn build_claim(sh: &Shape, p: &Priv, point: &[Fp2], cd: Fp2, cm: Fp2, value: Fp2) -> ZClaim {
    let (log_n, n) = (row_log(sh, p.cm), 1usize << row_log(sh, p.cm));
    let logm = p.log.min(log_n);
    let c0 = if p.log < log_n { p.slices[0].0 % n } else { 0 };
    let tail = point[p.log - logm..].to_vec();
    let mut parts: Vec<ZPart> = p
        .slices
        .iter()
        .map(|(off, coef)| ZPart { slice: Slice { offset: *off, log_size: p.log as u32 }, coef: coef.mul(cd), point: point.to_vec() })
        .collect();
    for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        parts.push(ZPart { slice: Slice { offset: (p.mask_row + k) * n + c0, log_size: logm as u32 }, coef: cm.mul(u), point: tail.clone() });
    }
    ZClaim { parts, value }
}
