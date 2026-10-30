fn baseline_mask_eval(sh: &Shape, p: &Priv, data: &[Fp], point: &[Fp2]) -> Fp2 {
    let (log_n, n) = (row_log(sh, p.cm), 1usize << row_log(sh, p.cm));
    let logm = p.log.min(log_n);
    let c0 = if p.log < log_n { p.slices[0].0 % n } else { 0 };
    let eq = eq_table_msb(&point[p.log - logm..]);
    let row = |r: usize| {
        data[r * n + c0..r * n + c0 + eq.len()].iter().zip(eq.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(e.mul_base(*x)))
    };
    row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))
}
