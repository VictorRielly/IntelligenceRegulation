fn group_zclaims_with_columns(claims: &[ZClaim], rows: usize, log_cols: u32, columns: bool) -> Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> {
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
            let cw = if columns { zkey_weights(&key, log_cols) } else { Vec::new() };
            keys.push(key);
            groups.push((cw, vec![(rw, c.value)]));
        }
    }
    groups
}
