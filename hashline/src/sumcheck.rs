//! A generic multilinear sumcheck over tables in F_{p^2}.
//!
//! Convention: tables are indexed with variable 0 as the MOST
//! significant bit (row-major matrices flatten as (row bits || col
//! bits)); round j fixes variable j, pairing index i with i + L/2.
//! The prover sends the round polynomial as its values at 0..=degree;
//! the verifier checks s(0) + s(1) == claim, absorbs, draws r_j, and
//! continues with s(r_j). The terminal check (the polynomial's value at
//! the final point from the tables' terminal values) is the caller's.

use crate::field::Fp2;
use crate::mle::interpolate_eval;
use crate::transcript::Transcript;
use rayon::prelude::*;

#[derive(Clone, Debug, Default)]
pub struct SumcheckProof {
    /// rounds[j] = values of the round-j polynomial at 0..=degree.
    pub rounds: Vec<Vec<Fp2>>,
}

impl SumcheckProof {
    pub fn size_bytes(&self) -> usize {
        self.rounds.iter().map(|r| r.len() * 16).sum()
    }
    /// [UPERF3-XX] The flat little-endian encoding `size_bytes` counts.
    pub fn write_bytes(&self, out: &mut Vec<u8>) {
        for r in &self.rounds {
            for v in r {
                out.extend_from_slice(&v.to_bytes());
            }
        }
    }
}

pub struct ProverOutput {
    pub proof: SumcheckProof,
    pub challenges: Vec<Fp2>,
    /// Each table folded down to a single value (its MLE at the challenge point).
    pub finals: Vec<Fp2>,
}

/// Prove sum_{x in {0,1}^n} poly(tables[0][x], ..., tables[k-1][x]).
/// `degree` is the degree of `poly` in each single table variable's
/// linear interpolation (i.e. the round-polynomial degree). Tables are
/// consumed (folded in place).
pub fn prove<F>(tables: &mut Vec<Vec<Fp2>>, degree: usize, poly: F, tr: &mut Transcript) -> ProverOutput
where
    F: Fn(&[Fp2]) -> Fp2 + Sync,
{
    let k = tables.len();
    assert!(k > 0);
    let n_total = tables[0].len();
    assert!(n_total.is_power_of_two());
    for t in tables.iter() {
        assert_eq!(t.len(), n_total);
    }
    let n_rounds = n_total.trailing_zeros() as usize;
    let mut rounds = Vec::with_capacity(n_rounds);
    let mut challenges = Vec::with_capacity(n_rounds);
    let mut len = n_total;
    for _round in 0..n_rounds {
        let half = len / 2;
        let chunk = 1024usize.min(half).max(1);
        let n_chunks = (half + chunk - 1) / chunk;
        // parallel over chunks of pair indices
        let sums: Vec<Fp2> = (0..n_chunks)
            .into_par_iter()
            .map(|ci| {
                let lo = ci * chunk;
                let hi = (lo + chunk).min(half);
                let mut acc = vec![Fp2::ZERO; degree + 1];
                let mut cur = vec![Fp2::ZERO; k];
                let mut dif = vec![Fp2::ZERO; k];
                for i in lo..hi {
                    for (t, tb) in tables.iter().enumerate() {
                        let v0 = tb[i];
                        let v1 = tb[i + half];
                        cur[t] = v0;
                        dif[t] = v1.sub(v0);
                    }
                    acc[0] = acc[0].add(poly(&cur));
                    for d in 1..=degree {
                        for t in 0..k {
                            cur[t] = cur[t].add(dif[t]);
                        }
                        acc[d] = acc[d].add(poly(&cur));
                    }
                }
                acc
            })
            .reduce(
                || vec![Fp2::ZERO; degree + 1],
                |mut a, b| {
                    for (x, y) in a.iter_mut().zip(b.iter()) {
                        *x = x.add(*y);
                    }
                    a
                },
            );
        tr.absorb_fp2(b"sc-round", &sums);
        let r = tr.challenge_fp2();
        challenges.push(r);
        rounds.push(sums);
        // fold every table: new[i] = v0 + r (v1 - v0)
        for tb in tables.iter_mut() {
            let (lo, hi) = tb.split_at_mut(half);
            lo.par_iter_mut().zip(hi[..half].par_iter()).for_each(|(a, b)| {
                *a = a.add(r.mul(b.sub(*a)));
            });
            tb.truncate(half);
        }
        len = half;
    }
    let finals = tables.iter().map(|t| t[0]).collect();
    ProverOutput { proof: SumcheckProof { rounds }, challenges, finals }
}

/// Verify the round structure; returns (final claim, challenges). The
/// caller must check `final claim == poly(terminal values)`.
pub fn verify(
    claimed_sum: Fp2,
    degree: usize,
    n_rounds: usize,
    proof: &SumcheckProof,
    tr: &mut Transcript,
) -> Result<(Fp2, Vec<Fp2>), String> {
    if proof.rounds.len() != n_rounds {
        return Err(format!("sumcheck: expected {n_rounds} rounds, got {}", proof.rounds.len()));
    }
    let mut claim = claimed_sum;
    let mut challenges = Vec::with_capacity(n_rounds);
    for (j, s) in proof.rounds.iter().enumerate() {
        if s.len() != degree + 1 {
            return Err(format!("sumcheck round {j}: expected degree {degree}, got {} values", s.len()));
        }
        if s[0].add(s[1]) != claim {
            return Err(format!("sumcheck round {j}: s(0) + s(1) != claim"));
        }
        tr.absorb_fp2(b"sc-round", s);
        let r = tr.challenge_fp2();
        challenges.push(r);
        claim = interpolate_eval(s, r);
    }
    Ok((claim, challenges))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::Fp;
    use crate::mle::{eq_table_msb, eval_mle_ext};

    fn rnd(seed: &mut u64) -> Fp2 {
        *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let a = *seed >> 1;
        *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let b = *seed >> 1;
        Fp2::new(Fp::new(a), Fp::new(b))
    }

    #[test]
    fn product_sumcheck_roundtrip_and_tamper() {
        let n = 10usize;
        let mut s = 5u64;
        let a: Vec<Fp2> = (0..1 << n).map(|_| rnd(&mut s)).collect();
        let b: Vec<Fp2> = (0..1 << n).map(|_| rnd(&mut s)).collect();
        let sum = a.iter().zip(b.iter()).fold(Fp2::ZERO, |acc, (x, y)| acc.add(x.mul(*y)));
        let mut tr = Transcript::new(b"test");
        let mut tables = vec![a.clone(), b.clone()];
        let out = prove(&mut tables, 2, |v| v[0].mul(v[1]), &mut tr);
        let mut tv = Transcript::new(b"test");
        let (fin, ch) = verify(sum, 2, n, &out.proof, &mut tv).unwrap();
        assert_eq!(ch, out.challenges);
        assert_eq!(fin, out.finals[0].mul(out.finals[1]));
        assert_eq!(out.finals[0], eval_mle_ext(&a, &ch));
        assert_eq!(out.finals[1], eval_mle_ext(&b, &ch));
        // wrong claimed sum
        let mut tv = Transcript::new(b"test");
        assert!(verify(sum.add(Fp2::ONE), 2, n, &out.proof, &mut tv).is_err());
        // tampered round
        let mut bad = out.proof.clone();
        bad.rounds[3][2] = bad.rounds[3][2].add(Fp2::ONE);
        let mut tv = Transcript::new(b"test");
        let r = verify(sum, 2, n, &bad, &mut tv);
        // round 3's s(2) is not used in the s(0)+s(1) check but changes the next claim -> a later round fails
        assert!(r.is_err() || r.unwrap().0 != out.finals[0].mul(out.finals[1]));
    }

    #[test]
    fn zero_check_with_eq() {
        let n = 8usize;
        let mut s = 11u64;
        let a: Vec<Fp2> = (0..1 << n).map(|_| rnd(&mut s)).collect();
        let b: Vec<Fp2> = (0..1 << n).map(|_| rnd(&mut s)).collect();
        let c: Vec<Fp2> = a.iter().zip(b.iter()).map(|(x, y)| x.mul(*y)).collect();
        let tau: Vec<Fp2> = (0..n).map(|_| rnd(&mut s)).collect();
        let eq = eq_table_msb(&tau);
        let mut tr = Transcript::new(b"zc");
        let mut tables = vec![eq.clone(), a.clone(), b.clone(), c.clone()];
        let out = prove(&mut tables, 3, |v| v[0].mul(v[1].mul(v[2]).sub(v[3])), &mut tr);
        let mut tv = Transcript::new(b"zc");
        let (fin, ch) = verify(Fp2::ZERO, 3, n, &out.proof, &mut tv).unwrap();
        let e = crate::mle::eq_point(&tau, &ch);
        assert_eq!(fin, e.mul(out.finals[1].mul(out.finals[2]).sub(out.finals[3])));
        // (the terminal value is NOT zero off the hypercube: (ab)~ != a~ b~ there)
        // a broken identity: flip one c
        let mut c2 = c.clone();
        c2[17] = c2[17].add(Fp2::ONE);
        let mut tr = Transcript::new(b"zc");
        let mut tables = vec![eq.clone(), a.clone(), b.clone(), c2.clone()];
        let out2 = prove(&mut tables, 3, |v| v[0].mul(v[1].mul(v[2]).sub(v[3])), &mut tr);
        let mut tv = Transcript::new(b"zc");
        // the honest prover's proof of a false statement: round 0 fails (sum != 0) or the terminal check fails
        match verify(Fp2::ZERO, 3, n, &out2.proof, &mut tv) {
            Err(_) => {}
            Ok((fin2, ch2)) => {
                let e2 = crate::mle::eq_point(&tau, &ch2);
                let want = e2.mul(eval_mle_ext(&a, &ch2).mul(eval_mle_ext(&b, &ch2)).sub(eval_mle_ext(&c2, &ch2)));
                assert_ne!(fin2, want);
            }
        }
    }
}
