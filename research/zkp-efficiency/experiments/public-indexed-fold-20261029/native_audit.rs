fn part_rows(p: &ZPart, n: usize) -> std::ops::Range<usize> {
    let r0 = p.slice.offset / n;
    r0..r0 + (1usize << p.slice.log_size).div_ceil(n)
}

pub(crate) fn audit_claims(claims: &[ZClaim], n: usize, rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize) -> Result<(), String> {
    let fail = |what: &str| Err(format!("private block: mask schedule audit: {what}"));
    if prox + 2 != rows || site_rows.len() % 2 != 0 {
        return fail("proximity pair placement");
    }
    let mut uses = vec![0usize; rows];
    let is_site = |r: usize| site_rows.binary_search(&r).is_ok();
    for (ci, claim) in claims.iter().enumerate() {
        let mut touched: Vec<usize> = Vec::new();
        for part in &claim.parts {
            let pr = part_rows(part, n);
            if pr.end > prox {
                return fail("a claim reaches the proximity pair or leaves the commitment");
            }
            for r in pr.filter(|r| is_site(*r)) {
                if part.coef.is_zero() {
                    return fail("zero terminal mask coefficient; discard attempt");
                }
                touched.push(r);
            }
        }
        let is_sum = claim.parts.iter().all(|p| p.point.is_empty());
        match (is_sum, sum_rows) {
            (true, Some(u)) if ci + 1 == claims.len() => {
                let covered = |row: usize| claim.parts.iter().any(|p| part_rows(p, n).contains(&row) && !p.coef.is_zero());
                if !touched.is_empty() || !covered(u[0]) || !covered(u[1]) {
                    return fail("the sum claim is not masked by the zero-sum pair alone");
                }
            }
            (false, _) => {
                if touched.len() != 2 || touched[1] != touched[0] + 1 || (touched[0] - site_rows[0]) % 2 != 0 {
                    return fail("a claim does not carry exactly its own reserved pair");
                }
            }
            _ => return fail("unexpected sum claim"),
        }
        for r in touched {
            uses[r] += 1;
        }
    }
    if site_rows.iter().any(|r| uses[*r] != 1) {
        return fail("a reserved pair is unused or shared between claims");
    }
    Ok(())
}
