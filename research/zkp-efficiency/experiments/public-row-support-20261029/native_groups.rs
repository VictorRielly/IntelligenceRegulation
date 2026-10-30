fn zpart_weights(p: &ZPart, rows: usize, log_cols: u32) -> (Vec<Fp2>, ZKey) {
    let n = 1usize << log_cols;
    let mut row_w = vec![Fp2::ZERO; rows];
    let ls = p.slice.log_size;
    let key;
    if p.point.is_empty() {
        if ls >= log_cols {
            assert!(p.slice.offset % n == 0);
            let r0 = p.slice.offset / n;
            for i in 0..(1usize << (ls - log_cols)) {
                row_w[r0 + i] = row_w[r0 + i].add(p.coef);
            }
            key = ZKey { tail: vec![], c0: 0, len: n };
        } else {
            let r0 = p.slice.offset / n;
            let c0 = p.slice.offset % n;
            assert!(c0 + (1usize << ls) <= n);
            row_w[r0] = row_w[r0].add(p.coef);
            key = ZKey { tail: vec![], c0, len: 1usize << ls };
        }
    } else {
        assert_eq!(p.point.len() as u32, ls, "zk claim: point arity != slice size");
        if ls >= log_cols {
            assert!(p.slice.offset % n == 0);
            let lr = (ls - log_cols) as usize;
            let r0 = p.slice.offset / n;
            let eq_r = eq_table_msb(&p.point[..lr]);
            for (i, e) in eq_r.iter().enumerate() {
                row_w[r0 + i] = row_w[r0 + i].add(p.coef.mul(*e));
            }
            key = ZKey { tail: p.point[lr..].to_vec(), c0: 0, len: n };
        } else {
            let r0 = p.slice.offset / n;
            let c0 = p.slice.offset % n;
            assert!(c0 + (1usize << ls) <= n);
            row_w[r0] = row_w[r0].add(p.coef);
            key = ZKey { tail: p.point.clone(), c0, len: 1usize << ls };
        }
    }
    (row_w, key)
}

fn zkey_weights(k: &ZKey, log_cols: u32) -> Vec<Fp2> {
    let n = 1usize << log_cols;
    let mut col_w = vec![Fp2::ZERO; n];
    if k.tail.is_empty() {
        for c in col_w[k.c0..k.c0 + k.len].iter_mut() {
            *c = Fp2::ONE;
        }
    } else {
        let eq_c = eq_table_msb(&k.tail);
        col_w[k.c0..k.c0 + k.len].copy_from_slice(&eq_c);
    }
    col_w
}

fn group_zclaims(claims: &[ZClaim], rows: usize, log_cols: u32) -> Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> {
    let mut keys: Vec<ZKey> = Vec::new();
    let mut groups: Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> = Vec::new();
    for c in claims {
        assert!(!c.parts.is_empty());
        let (mut rw, key) = zpart_weights(&c.parts[0], rows, log_cols);
        for p in &c.parts[1..] {
            let (rw2, key2) = zpart_weights(p, rows, log_cols);
            assert!(key2 == key, "zk claim: parts with different column weights");
            for (a, b) in rw.iter_mut().zip(rw2.iter()) {
                *a = a.add(*b);
            }
        }
        if let Some(gi) = keys.iter().position(|k| *k == key) {
            groups[gi].1.push((rw, c.value));
        } else {
            let cw = zkey_weights(&key, log_cols);
            keys.push(key);
            groups.push((cw, vec![(rw, c.value)]));
        }
    }
    groups
}

fn zk_rhos(groups: &[(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)], rows: usize, tr: &mut Transcript) -> (Vec<Vec<Fp2>>, Vec<Fp2>) {
    let mut rhos: Vec<Vec<Fp2>> = Vec::with_capacity(groups.len() + 1);
    let mut wants = Vec::with_capacity(groups.len());
    for (_, members) in groups {
        let lambdas = tr.challenge_fp2_vec(members.len());
        let mut rho = vec![Fp2::ZERO; rows];
        let mut want = Fp2::ZERO;
        for ((rw, val), lam) in members.iter().zip(lambdas.iter()) {
            for i in 0..rows {
                if !rw[i].is_zero() {
                    rho[i] = rho[i].add(lam.mul(rw[i]));
                }
            }
            want = want.add(lam.mul(*val));
        }
        rhos.push(rho);
        wants.push(want);
    }
    let prox_rho = tr.challenge_fp2_vec(rows);
    rhos.push(prox_rho);
    (rhos, wants)
}
