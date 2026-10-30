fn native_claim_point(p: &Priv, rho: &[Fp2]) -> Vec<Fp2> {
    p.coords
        .iter()
        .map(|c| match c {
            Coord::Rho(k) => rho[*k],
            Coord::Flip(k) => Fp2::ONE.sub(rho[*k]),
            Coord::Fixed(f) => *f,
        })
        .collect()
}
