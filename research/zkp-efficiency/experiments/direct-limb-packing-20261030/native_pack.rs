fn as_u64s_f2(v: &[Fp2]) -> Vec<u64> {
    let mut out = Vec::with_capacity(v.len() * 2);
    for x in v {
        out.push(x.c0.0);
        out.push(x.c1.0);
    }
    out
}

fn pack_native(rhos: &[Vec<Fp2>], rows: usize) -> Vec<u64> {
    let k = rhos.len();
    assert!(k >= 1 && k <= 4, "dev_fold_rows: {k} weight vectors (max 4)");
    let mut flat: Vec<u64> = Vec::with_capacity(k * rows * 2);
    for rho in rhos {
        assert_eq!(rho.len(), rows);
        flat.extend(as_u64s_f2(rho));
    }
    flat
}

fn pack_direct(rhos: &[Vec<Fp2>], rows: usize) -> Vec<u64> {
    let k = rhos.len();
    assert!(k >= 1 && k <= 4, "dev_fold_rows: {k} weight vectors (max 4)");
    let mut flat: Vec<u64> = Vec::with_capacity(k * rows * 2);
    for rho in rhos {
        assert_eq!(rho.len(), rows);
        for x in rho {
            flat.push(x.c0.0);
            flat.push(x.c1.0);
        }
    }
    flat
}
