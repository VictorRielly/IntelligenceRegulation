fn native_priv_table(p: &Priv, data: &[Fp], n_vars: usize) -> Vec<Fp2> {
    let fixed: Vec<Fp2> = p.coords.iter().filter_map(|c| if let Coord::Fixed(f) = c { Some(*f) } else { None }).collect();
    let eqf = eq_table_msb(&fixed);
    let mut used = 0usize;
    for c in &p.coords {
        if let Coord::Rho(k) | Coord::Flip(k) = c {
            used |= 1usize << (n_vars - 1 - *k);
        }
    }
    let mut out = vec![Fp2::ZERO; 1usize << n_vars];
    // the index maps, one per half of `idx`. Coordinate `j` reads bit
    // `p.log - 1 - j` of `idx`, so coordinates `0 .. hi` are the high half.
    let lo_len = p.log / 2;
    let hi_len = p.log - lo_len;
    let fixed_lo = p.coords[hi_len..].iter().filter(|c| matches!(c, Coord::Fixed(_))).count();
    let map = |coords: &[Coord], bits: usize| -> Vec<(usize, usize)> {
        (0..1usize << bits)
            .map(|v| {
                let (mut x, mut z) = (0usize, 0usize);
                for (j, c) in coords.iter().enumerate() {
                    let b = (v >> (bits - 1 - j)) & 1;
                    match c {
                        Coord::Rho(k) => x |= b << (n_vars - 1 - *k),
                        Coord::Flip(k) => x |= (1 - b) << (n_vars - 1 - *k),
                        Coord::Fixed(_) => z = (z << 1) | b,
                    }
                }
                (x, z)
            })
            .collect()
    };
    let hi_map = map(&p.coords[..hi_len], hi_len);
    let lo_map = map(&p.coords[hi_len..], lo_len);
    let lo_mask = (1usize << lo_len) - 1;
    // The write is a plain store only when NOTHING can land on the same `x`
    // twice: no fixed coordinate (so `eqf` is the one-element table `[1]`)
    // AND no challenge index used twice (which the construction promises and
    // this counts rather than assumes — a duplicate index would make two
    // `idx` share an `x`, where the old form ADDED them).
    let moving = p.coords.iter().filter(|c| !matches!(c, Coord::Fixed(_))).count();
    let simple = eqf.len() == 1 && eqf[0] == Fp2::ONE && used.count_ones() as usize == moving;
    let one_slice = if p.slices.len() == 1 && p.slices[0].1 == Fp2::ONE { Some(p.slices[0].0) } else { None };
    for idx in 0..1usize << p.log {
        let (x_hi, z_hi) = hi_map[idx >> lo_len];
        let (x_lo, z_lo) = lo_map[idx & lo_mask];
        let (x, z) = (x_hi | x_lo, (z_hi << fixed_lo) | z_lo);
        let v = match one_slice {
            Some(off) => Fp2::from_base(data[off + idx]),
            None => p.slices.iter().fold(Fp2::ZERO, |a, (off, coef)| a.add(coef.mul_base(data[*off + idx]))),
        };
        if simple {
            out[x] = v;
        } else {
            out[x] = out[x].add(eqf[z].mul(v));
        }
    }
    // broadcast over the variables the plane does not depend on
    if used != (1usize << n_vars) - 1 {
        for x in 0..out.len() {
            if x & !used != 0 {
                out[x] = out[x & used];
            }
        }
    }
    out
}
