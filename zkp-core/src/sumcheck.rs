//! A generic multilinear sumcheck over tables in F_{p^2}.
//!
//! Convention: tables are indexed with variable 0 as the MOST
//! significant bit (row-major matrices flatten as (row bits || col
//! bits)); round j fixes variable j, pairing index i with i + L/2.
//! The prover sends the round polynomial as its values at 0..=degree;
//! the verifier checks s(0) + s(1) == claim, absorbs, draws r_j, and
//! continues with s(r_j). The terminal check (the polynomial's value at
//! the final point from the tables' terminal values) is the caller's.

use crate::field::{Fp, Fp2};
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
        // [UPERF3-ZA] small rounds run on one thread: a rayon region per round and
        // per table fold cost ~0.3 ms of pool wake-up each and dominated the 2^14
        // sumchecks (the field sums are order-independent: the values are identical).
        let small = half * k <= 1 << 16;
        let chunk = if small { half.max(1) } else { 1024usize.min(half).max(1) };
        let n_chunks = (half + chunk - 1) / chunk;
        let round_of = |ci: usize| {
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
            };
        let sums: Vec<Fp2> = if small {
            round_of(0)
        } else {
            (0..n_chunks)
                .into_par_iter()
                .map(round_of)
                .reduce(
                    || vec![Fp2::ZERO; degree + 1],
                    |mut a, b| {
                        for (x, y) in a.iter_mut().zip(b.iter()) {
                            *x = x.add(*y);
                        }
                        a
                    },
                )
        };
        tr.absorb_fp2(b"sc-round", &sums);
        let r = tr.challenge_fp2();
        challenges.push(r);
        rounds.push(sums);
        // fold every table: new[i] = v0 + r (v1 - v0)
        for tb in tables.iter_mut() {
            let (lo, hi) = tb.split_at_mut(half);
            if small {
                for (a, b) in lo.iter_mut().zip(hi[..half].iter()) {
                    *a = a.add(r.mul(b.sub(*a)));
                }
            } else {
                lo.par_iter_mut().zip(hi[..half].par_iter()).for_each(|(a, b)| {
                    *a = a.add(r.mul(b.sub(*a)));
                });
            }
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


// ===========================================================================
// [UPERF3-ZA] The zero-knowledge sumcheck pieces (behind `--zk`).
//
// (i) The Chiesa-Forbes-Spooner / Libra masking polynomial over N
//     variables with per-variable degree d:
//        g(x) = a_0 + a' * prod_j x_j + sum_j sum_{e=1..d} a_{j,e} x_j^e
//     (N d + 2 coefficients; a' is the extra freedom that makes the
//     total G = sum_x g(x) AND the terminal g(rho) jointly uniform given
//     the round messages). The sumcheck runs on f + c g: the prover adds
//     c g_j(X) to every round message (closed form below), the verifier
//     checks the masked rounds as usual, and the terminal identity is
//     fin = f(rho) + c g(rho), g(rho) being opened from the mask
//     commitment (zk.rs) as a linear functional of the coefficients.
// (ii) The last-round extension: the private tables are extended by a
//     trailing variable y, T_ext(x, y) = (1 - y) T(x) + y R_T(x), the
//     eq / public factors carry (1 - y). Rounds 0..k-1 equal the
//     unmasked sumcheck's; round k is computed from the finals:
//     s_k(X) = poly((1 - X) fin_t + X ext_t) with ext_t = R_T~ for a
//     private table and 0 for a public one. The verifier then checks
//     poly on the MASKED terminals m_t = (1 - rho_k) T~ + rho_k R_T~.
// ===========================================================================

use crate::transcript::RoundMask;

/// The masking polynomial g and the state of its use in one sumcheck.
#[derive(Clone, Debug)]
pub struct CfsMask {
    pub n_vars: usize,
    pub degree: usize,
    /// coefficients in the layout [a_0, a', a_{0,1..d}, a_{1,1..d}, ..., a_{N-1,1..d}]
    pub coeffs: Vec<Fp2>,
}

impl CfsMask {
    pub fn len(n_vars: usize, degree: usize) -> usize {
        n_vars * degree + 2
    }

    pub fn random(rng: &mut crate::rng::ZkRng, n_vars: usize, degree: usize) -> CfsMask {
        CfsMask { n_vars, degree, coeffs: rng.fp2_vec(Self::len(n_vars, degree)) }
    }

    fn a(&self, j: usize, e: usize) -> Fp2 {
        self.coeffs[2 + j * self.degree + (e - 1)]
    }

    /// u_j(X) = sum_e a_{j,e} X^e
    fn u(&self, j: usize, x: Fp2) -> Fp2 {
        let mut acc = Fp2::ZERO;
        let mut xp = Fp2::ONE;
        for e in 1..=self.degree {
            xp = xp.mul(x);
            acc = acc.add(self.a(j, e).mul(xp));
        }
        acc
    }

    /// The weight vector w such that <coeffs, w> = sum_x g(x):
    /// 2^N on a_0, 1 on a', 2^(N-1) on every a_{j,e}.
    pub fn sum_weights(n_vars: usize, degree: usize) -> Vec<Fp2> {
        let mut w = vec![Fp2::from_u64(1u64 << (n_vars - 1)); Self::len(n_vars, degree)];
        w[0] = Fp2::from_u64(1u64 << n_vars);
        w[1] = Fp2::ONE;
        w
    }

    /// The weight vector w such that <coeffs, w> = g(rho).
    pub fn eval_weights(rho: &[Fp2], degree: usize) -> Vec<Fp2> {
        let n = rho.len();
        let mut w = Vec::with_capacity(Self::len(n, degree));
        w.push(Fp2::ONE);
        w.push(rho.iter().fold(Fp2::ONE, |a, r| a.mul(*r)));
        for r in rho {
            let mut xp = Fp2::ONE;
            for _ in 0..degree {
                xp = xp.mul(*r);
                w.push(xp);
            }
        }
        w
    }

    pub fn total(&self) -> Fp2 {
        Self::sum_weights(self.n_vars, self.degree).iter().zip(self.coeffs.iter()).fold(Fp2::ZERO, |a, (w, c)| a.add(w.mul(*c)))
    }

    pub fn eval(&self, rho: &[Fp2]) -> Fp2 {
        assert_eq!(rho.len(), self.n_vars);
        Self::eval_weights(rho, self.degree).iter().zip(self.coeffs.iter()).fold(Fp2::ZERO, |a, (w, c)| a.add(w.mul(*c)))
    }

    /// The round-j message of g at X = 0..=degree, given the earlier challenges.
    pub fn round(&self, j: usize, prev: &[Fp2]) -> Vec<Fp2> {
        assert_eq!(prev.len(), j);
        let n = self.n_vars;
        let half = Fp::new(2).inv();
        let mut base = self.coeffs[0];
        for (i, r) in prev.iter().enumerate() {
            base = base.add(self.u(i, *r));
        }
        for i in j + 1..n {
            base = base.add(self.u(i, Fp2::ONE).mul_base(half));
        }
        let scale = Fp2::from_u64(1u64 << (n - 1 - j));
        let prod_prev = prev.iter().fold(Fp2::ONE, |a, r| a.mul(*r));
        (0..=self.degree)
            .map(|x| {
                let xv = Fp2::from_u64(x as u64);
                scale.mul(base.add(self.u(j, xv))).add(self.coeffs[1].mul(prod_prev).mul(xv))
            })
            .collect()
    }
}

/// The transcript masker for one masked sumcheck: adds c g_j(X) to round j.
pub struct CfsMasker {
    pub mask: CfsMask,
    pub c: Fp2,
    pub challenges: Vec<Fp2>,
}

impl RoundMask for CfsMasker {
    fn mask_round(&mut self, sums: &[Fp2]) -> Vec<Fp2> {
        let j = self.challenges.len();
        assert_eq!(sums.len(), self.mask.degree + 1, "masked sumcheck: round degree mismatch");
        let g = self.mask.round(j, &self.challenges);
        sums.iter().zip(g.iter()).map(|(s, gj)| s.add(self.c.mul(*gj))).collect()
    }
    fn note_challenge(&mut self, r: Fp2) {
        self.challenges.push(r);
    }
}

/// The extension round's message: s_k(X) = poly((1 - X) fin_t + X ext_t) at X = 0..=degree.
pub fn extension_round<F>(finals: &[Fp2], exts: &[Fp2], degree: usize, poly: F) -> Vec<Fp2>
where
    F: Fn(&[Fp2]) -> Fp2,
{
    assert_eq!(finals.len(), exts.len());
    (0..=degree)
        .map(|x| {
            let xv = Fp2::from_u64(x as u64);
            let v: Vec<Fp2> = finals.iter().zip(exts.iter()).map(|(f, e)| f.add(xv.mul(e.sub(*f)))).collect();
            poly(&v)
        })
        .collect()
}

/// The masked terminal of a table after the extension round: (1 - rho_k) fin + rho_k ext.
pub fn masked_terminal(fin: Fp2, ext: Fp2, rho_k: Fp2) -> Fp2 {
    fin.add(rho_k.mul(ext.sub(fin)))
}

#[cfg(test)]
mod zk_tests {
    use super::*;
    use crate::mle::{eq_point, eq_table_msb, eval_mle_ext};
    use crate::rng::ZkRng;

    fn rnd(seed: &mut u64) -> Fp2 {
        *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let a = *seed >> 1;
        *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let b = *seed >> 1;
        Fp2::new(Fp::new(a), Fp::new(b))
    }

    /// The closed-form round messages of g agree with a brute-force sumcheck of g itself.
    #[test]
    fn cfs_mask_rounds_match_brute_force() {
        let mut rng = ZkRng::new(3, b"t");
        for (n, d) in [(3usize, 2usize), (4, 4), (5, 1)] {
            let m = CfsMask::random(&mut rng, n, d);
            // g on the cube as a table, then the plain sumcheck prover on it (degree d in every variable)
            let g_tab: Vec<Fp2> = (0..1 << n)
                .map(|idx| {
                    let x: Vec<Fp2> = (0..n).map(|i| if (idx >> (n - 1 - i)) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO }).collect();
                    m.eval(&x)
                })
                .collect();
            let total: Fp2 = g_tab.iter().fold(Fp2::ZERO, |a, b| a.add(*b));
            assert_eq!(total, m.total());
            // brute force: round j at X in 0..=d by evaluating g at (prev, X, boolean rest)
            let mut prev: Vec<Fp2> = Vec::new();
            let mut s = 77u64;
            for j in 0..n {
                let want: Vec<Fp2> = (0..=d)
                    .map(|xv| {
                        let mut acc = Fp2::ZERO;
                        for rest in 0..1usize << (n - 1 - j) {
                            let mut pt = prev.clone();
                            pt.push(Fp2::from_u64(xv as u64));
                            for i in 0..n - 1 - j {
                                pt.push(if (rest >> (n - 2 - j - i)) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO });
                            }
                            acc = acc.add(m.eval(&pt));
                        }
                        acc
                    })
                    .collect();
                let got = m.round(j, &prev);
                assert_eq!(got, want, "n {n} d {d} round {j}");
                assert_eq!(got[0].add(got[1]), if j == 0 { total } else { crate::mle::interpolate_eval(&m.round(j - 1, &prev[..j - 1]), prev[j - 1]) });
                prev.push(rnd(&mut s));
            }
            let _ = eval_mle_ext(&g_tab, &prev);
        }
    }

    /// A masked zero-check with the last-round extension, end to end:
    /// prover with the masker + the extension round; verifier checks the
    /// masked rounds, the masked terminals, and never sees an unmasked
    /// table evaluation.
    #[test]
    fn masked_zero_check_with_extension_roundtrip() {
        let n = 6usize;
        let mut s = 11u64;
        let a: Vec<Fp2> = (0..1 << n).map(|_| rnd(&mut s)).collect();
        let b: Vec<Fp2> = (0..1 << n).map(|_| rnd(&mut s)).collect();
        let c: Vec<Fp2> = a.iter().zip(b.iter()).map(|(x, y)| x.mul(*y)).collect();
        let tau: Vec<Fp2> = (0..n).map(|_| rnd(&mut s)).collect();
        let mut rng = ZkRng::new(5, b"zc");
        let mask = CfsMask::random(&mut rng, n + 1, 3);
        // the mask rows for a, b, c: uniform "rows" whose MLE at rho_col masks the terminal
        let ra: Vec<Fp2> = (0..1 << n).map(|_| rng.fp2()).collect();
        let rb: Vec<Fp2> = (0..1 << n).map(|_| rng.fp2()).collect();
        let rc: Vec<Fp2> = (0..1 << n).map(|_| rng.fp2()).collect();
        let poly = |v: &[Fp2]| v[0].mul(v[1].mul(v[2]).sub(v[3]));
        // prover
        let mut tr = Transcript::new(b"zc");
        let cc = tr.challenge_fp2();
        let g_total = mask.total();
        let claim = Fp2::ZERO.add(cc.mul(g_total));
        tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c: cc, challenges: Vec::new() }));
        let mut tables = vec![eq_table_msb(&tau), a.clone(), b.clone(), c.clone()];
        let out = prove(&mut tables, 3, poly, &mut tr);
        let (_, masked_rounds) = tr.take_masker();
        assert_eq!(masked_rounds.len(), n);
        let rho = out.challenges.clone();
        let exts = vec![Fp2::ZERO, eval_mle_ext(&ra, &rho), eval_mle_ext(&rb, &rho), eval_mle_ext(&rc, &rho)];
        let mut sk = extension_round(&out.finals, &exts, 3, poly);
        let gk = mask.round(n, &rho);
        for (x, g) in sk.iter_mut().zip(gk.iter()) { *x = x.add(cc.mul(*g)); }
        tr.absorb_fp2(b"sc-round", &sk);
        let rho_k = tr.challenge_fp2();
        let m_a = masked_terminal(out.finals[1], exts[1], rho_k);
        let m_b = masked_terminal(out.finals[2], exts[2], rho_k);
        let m_c = masked_terminal(out.finals[3], exts[3], rho_k);
        let mut full_rho = rho.clone();
        full_rho.push(rho_k);
        let g_rho = mask.eval(&full_rho);
        let mut proof = SumcheckProof { rounds: masked_rounds };
        proof.rounds.push(sk.clone());
        // verifier
        let mut tv = Transcript::new(b"zc");
        let cv = tv.challenge_fp2();
        assert_eq!(cv, cc);
        let (fin, ch) = verify(claim, 3, n + 1, &proof, &mut tv).unwrap();
        assert_eq!(ch, full_rho);
        let eq_ext = Fp2::ONE.sub(ch[n]).mul(eq_point(&tau, &ch[..n]));
        let want = poly(&[eq_ext, m_a, m_b, m_c]).add(cv.mul(g_rho));
        assert_eq!(want, fin, "masked terminal check");
        // the masked terminals differ from the unmasked evaluations
        assert_ne!(m_a, eval_mle_ext(&a, &rho));
        // a broken identity is still caught
        let mut c2 = c.clone();
        c2[5] = c2[5].add(Fp2::ONE);
        let mut tr = Transcript::new(b"zc");
        let cc = tr.challenge_fp2();
        tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c: cc, challenges: Vec::new() }));
        let mut tables = vec![eq_table_msb(&tau), a.clone(), b.clone(), c2.clone()];
        let out2 = prove(&mut tables, 3, poly, &mut tr);
        let (_, mr2) = tr.take_masker();
        let proof2 = SumcheckProof { rounds: mr2 };
        let mut tv = Transcript::new(b"zc");
        let _ = tv.challenge_fp2();
        let r = verify(claim, 3, n, &proof2, &mut tv);
        assert!(r.is_err() || r.unwrap().0 != poly(&[eq_point(&tau, &out2.challenges), out2.finals[1], out2.finals[2], out2.finals[3]]).add(cc.mul(mask.eval(&[out2.challenges.clone(), vec![Fp2::ZERO]].concat()))));
    }
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
