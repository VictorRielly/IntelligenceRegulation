fn fold_rows_host(src: &[Fp], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let k = rhos.len();
    let chunk = 512usize.min(n);
    let n_chunks = (n + chunk - 1) / chunk;
    let parts: Vec<Vec<Vec<Fp2>>> = (0..n_chunks)
        .into_iter()
        .map(|ci| {
            let c0 = ci * chunk;
            let w = chunk.min(n - c0);
            let mut out = vec![vec![Fp2::ZERO; w]; k];
            for i in 0..rows {
                let row = &src[i * nn..(i + 1) * nn];
                for (g, rho) in rhos.iter().enumerate() {
                    let r = rho[i];
                    if r.is_zero() { continue; }
                    let o = &mut out[g];
                    for j in 0..w {
                        let v = row[(c0 + j) * ir];
                        if v.is_zero() { continue; }
                        o[j] = o[j].add(r.mul_base(v));
                    }
                }
            }
            out
        })
        .collect();
    let mut out = vec![vec![Fp2::ZERO; n]; k];
    for (ci, p) in parts.into_iter().enumerate() {
        let c0 = ci * chunk;
        for g in 0..k {
            for (j, v) in p[g].iter().enumerate() {
                out[g][c0 + j] = *v;
            }
        }
    }
    out
}
