//! **D63 step L6 (Lean lane, 2026-11-06): the agreement corpus between zkp-core's GENERIC sumcheck verifier, its
//! zero-knowledge pieces and the multilinear helpers, and the executable Lean mirrors** (`formal/ZK60Formal/ExecMle.lean`,
//! `ExecSumcheck.lean`, `ExecCfs.lean`; the checker is `formal/ZK60Formal/L6Check.lean`).
//!
//! TEST ONLY: an integration test, so no production source changes and nothing in the crate calls it. It records,
//! from the crate's own public code paths (`mle::{interpolate_eval, eq_point, eq_table, eq_table_msb, eval_mle_ext,
//! eval_mle_base}`, `sumcheck::{prove, verify, CfsMask, CfsMasker, extension_round, masked_terminal}`, the transcript's
//! `set_masker` / `take_masker`):
//! * `IE` interpolate_eval at degrees 0..6 (at the nodes and elsewhere); `EQP` eq_point; `EQT` both eq tables;
//!   `MLX` / `MLB` the multilinear evaluations of extension and base vectors;
//! * `CFSW` / `CFSE` the CFS weight vectors; `CFSM` a mask (`CfsMask::random`) with its total, `CFSV` its value at a
//!   point, `CFSR` its round messages; `MT` masked terminals; `EXR` extension rounds;
//! * `SC…` whole sumchecks: made by `prove` (plain, masked by `CfsMasker`, and masked with the last-round extension as
//!   `argument.rs` runs a private slot), then checked by `verify`, honest and tampered (a wrong round count, a wrong
//!   round length, `s(0) + s(1)` off by one, a flipped value, a wrong claimed sum, wrong `degree` / `n_rounds`
//!   arguments), each with the verifier's verdict (the error message bytes on a refusal) and its transcript state.
//! All data are public synthetic values (fixed seeds; the one key is the public transcript key of the development
//! rung's profile string).
//!
//! Output: one record per line, space-separated; an `Fp2` is `c0,c1` in decimal, a vector is the flat comma list of
//! its `Fp2`s (`-` when empty), bytes are lowercase hex. Run with
//! `LEAN_L6_CORPUS=<path> cargo test --release --offline --locked --test lean_l6_export`; without the variable the
//! test only builds the corpus and checks its own assertions.
use std::fmt::Write as _;
use zkp_core::field::{Fp, Fp2, P};
use zkp_core::hashtag::HashTag;
use zkp_core::mle::{eq_point, eq_table, eq_table_msb, eval_mle_base, eval_mle_ext, interpolate_eval};
use zkp_core::rng::ZkRng;
use zkp_core::sumcheck::{self, extension_round, masked_terminal, CfsMask, CfsMasker, SumcheckProof};
use zkp_core::transcript::Transcript;

const RUNG_G: &str = "hashline-zk-mr1/private-block-rung-g-t24-dev/1";

fn hex(b: &[u8]) -> String {
    if b.is_empty() {
        return "-".into();
    }
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// xorshift64* (the generator `field.rs`'s tests and the L5 corpus use)
struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }
    fn fp(&mut self) -> Fp {
        Fp(self.next() % P)
    }
    /// mostly uniform canonical values, with the field's edges mixed in
    fn fp2(&mut self) -> Fp2 {
        match self.next() % 16 {
            0 => Fp2::ZERO,
            1 => Fp2::ONE,
            2 => Fp2::new(Fp(P - 1), Fp(P - 1)),
            3 => Fp2::new(Fp(P - 1), Fp::ZERO),
            4 => Fp2::new(Fp::ZERO, Fp(1)),
            _ => Fp2::new(self.fp(), self.fp()),
        }
    }
    fn vec(&mut self, n: usize) -> Vec<Fp2> {
        (0..n).map(|_| self.fp2()).collect()
    }
}

fn f2(x: Fp2) -> String {
    format!("{},{}", x.c0.0, x.c1.0)
}

fn csv(v: &[Fp2]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| f2(*x)).collect::<Vec<_>>().join(",")
}

fn fcsv(v: &[Fp]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| x.0.to_string()).collect::<Vec<_>>().join(",")
}

struct Corpus {
    out: String,
    n: usize,
}
impl Corpus {
    fn line(&mut self, s: String) {
        self.out.push_str(&s);
        self.out.push('\n');
        self.n += 1;
    }
}

/// The named round polynomials of the corpus (`L6Check.lean`'s `polyOf` mirrors them).
fn poly_eval(name: &str, v: &[Fp2]) -> Fp2 {
    match name {
        "prod" => v.iter().fold(Fp2::ONE, |a, x| a.mul(*x)),
        "zc" => v[0].mul(v[1].mul(v[2]).sub(v[3])),
        _ => panic!("unknown poly {name}"),
    }
}

fn interp_records(c: &mut Corpus, r: &mut Rng) {
    for d in 0..=6usize {
        for k in 0..14usize {
            let vals = r.vec(d + 1);
            let x = if k <= d {
                Fp2::from_u64(k as u64)
            } else if k == d + 1 {
                Fp2::new(Fp(P - 1), Fp::ZERO)
            } else if k == d + 2 {
                Fp2::from_u64(d as u64 + 1)
            } else {
                r.fp2()
            };
            c.line(format!("IE {} {} {}", csv(&vals), f2(x), f2(interpolate_eval(&vals, x))));
        }
    }
}

fn eq_records(c: &mut Corpus, r: &mut Rng) {
    for n in 0..=7usize {
        for rep in 0..3usize {
            let pt = r.vec(n);
            let s = r.vec(n);
            c.line(format!("EQP {} {} {}", csv(&pt), csv(&s), f2(eq_point(&pt, &s))));
            if rep == 0 {
                c.line(format!("EQT {} {} {}", csv(&pt), csv(&eq_table(&pt)), csv(&eq_table_msb(&pt))));
            }
        }
    }
    for n in 0..=7usize {
        for _ in 0..2 {
            let v = r.vec(1 << n);
            let pt = r.vec(n);
            c.line(format!("MLX {} {} {}", csv(&v), csv(&pt), f2(eval_mle_ext(&v, &pt))));
            let vb: Vec<Fp> = (0..1usize << n).map(|_| r.fp()).collect();
            c.line(format!("MLB {} {} {}", fcsv(&vb), csv(&pt), f2(eval_mle_base(&vb, &pt))));
        }
    }
}

fn cfs_records(c: &mut Corpus, r: &mut Rng) {
    for (nv, d) in [(1usize, 1usize), (1, 3), (2, 2), (3, 2), (4, 4), (5, 1), (6, 3), (7, 5), (8, 6), (11, 3)] {
        c.line(format!("CFSW {nv} {d} {}", csv(&CfsMask::sum_weights(nv, d))));
        let rho = r.vec(nv);
        c.line(format!("CFSE {d} {} {}", csv(&rho), csv(&CfsMask::eval_weights(&rho, d))));
    }
    let mut zr = ZkRng::new(61, b"lean-l6 cfs corpus");
    for (nv, d) in [(1usize, 1usize), (1, 2), (2, 2), (3, 3), (4, 4), (5, 2), (3, 6), (7, 3), (6, 1)] {
        let m = CfsMask::random(&mut zr, nv, d);
        c.line(format!("CFSM {nv} {d} {} {}", csv(&m.coeffs), f2(m.total())));
        for _ in 0..2 {
            let rho = r.vec(nv);
            c.line(format!("CFSV {} {}", csv(&rho), f2(m.eval(&rho))));
            for j in 0..nv {
                c.line(format!("CFSR {j} {} {}", csv(&rho[..j]), csv(&m.round(j, &rho[..j]))));
            }
        }
    }
    for _ in 0..40 {
        let (fin, ext, rho) = (r.fp2(), r.fp2(), r.fp2());
        c.line(format!("MT {} {} {} {}", f2(fin), f2(ext), f2(rho), f2(masked_terminal(fin, ext, rho))));
    }
    for (name, k, deg) in [("prod", 1usize, 1usize), ("prod", 2, 2), ("zc", 4, 3), ("prod", 3, 3), ("prod", 5, 5), ("prod", 6, 6)] {
        for _ in 0..3 {
            let fins = r.vec(k);
            let exts: Vec<Fp2> = (0..k).map(|i| if i == 0 && name == "zc" { Fp2::ZERO } else { r.fp2() }).collect();
            let out = extension_round(&fins, &exts, deg, |v| poly_eval(name, v));
            c.line(format!("EXR {name} {deg} {} {} {}", csv(&fins), csv(&exts), csv(&out)));
        }
    }
}

fn mk_tr(domain: &[u8], key: Option<[u8; 32]>) -> Transcript {
    match key {
        Some(k) => Transcript::new_tagged(domain, k),
        None => Transcript::new(domain),
    }
}

/// One `verify` call, recorded: the header, the pre-drawn mask challenge (if any), the rounds, the verdict and the
/// verifier transcript's state after the call.
#[allow(clippy::too_many_arguments)]
fn emit_verify(c: &mut Corpus, name: &str, domain: &[u8], key: Option<[u8; 32]>, pre_c: bool, claimed: Fp2, deg: usize, nr: usize, proof: &SumcheckProof) -> (Result<(Fp2, Vec<Fp2>), String>, [u8; 32]) {
    c.line(format!("SC {name} {} {} {deg} {nr} {}", hex(domain), key.map(|k| hex(&k)).unwrap_or_else(|| "-".into()), f2(claimed)));
    let mut tv = mk_tr(domain, key);
    if pre_c {
        let cv = tv.challenge_fp2();
        c.line(format!("SCPRE {}", f2(cv)));
    }
    for rd in &proof.rounds {
        c.line(format!("SCR {}", csv(rd)));
    }
    let res = sumcheck::verify(claimed, deg, nr, proof, &mut tv);
    match &res {
        Ok((fin, ch)) => c.line(format!("SCEND ok {} {} {}", f2(*fin), csv(ch), hex(&tv.state()))),
        Err(e) => c.line(format!("SCEND err {} {}", hex(e.as_bytes()), hex(&tv.state()))),
    }
    (res, tv.state())
}

fn tables_lines(c: &mut Corpus, tables: &[Vec<Fp2>]) {
    c.line("SCNEW".into());
    for t in tables {
        c.line(format!("SCTAB {}", csv(t)));
    }
}

fn cube_sum(name: &str, tables: &[Vec<Fp2>]) -> Fp2 {
    let len = tables[0].len();
    (0..len).fold(Fp2::ZERO, |a, i| {
        let row: Vec<Fp2> = tables.iter().map(|t| t[i]).collect();
        a.add(poly_eval(name, &row))
    })
}

/// A plain sumcheck: `prove`, then `verify` honest and tampered.
fn plain_run(c: &mut Corpus, r: &mut Rng, name: &str, key: Option<[u8; 32]>, n: usize, poly: &str, tables: Vec<Vec<Fp2>>, deg: usize) {
    let domain = format!("lean-l6/sc/{name}");
    let domain = domain.as_bytes();
    let claimed = cube_sum(poly, &tables);
    let mut tp = mk_tr(domain, key);
    let mut tb = tables.clone();
    let out = sumcheck::prove(&mut tb, deg, |v| poly_eval(poly, v), &mut tp);
    assert_eq!(out.proof.rounds.len(), n);
    tables_lines(c, &tables);
    // honest
    let (res, st) = emit_verify(c, name, domain, key, false, claimed, deg, n, &out.proof);
    let (fin, ch) = res.expect("the honest sumcheck verifies");
    assert_eq!(ch, out.challenges);
    assert_eq!(st, tp.state(), "prover and verifier transcripts end in the same state");
    assert_eq!(fin, poly_eval(poly, &out.finals));
    c.line(format!("SCFIN {poly} {} 1", csv(&out.finals)));
    c.line(format!("SCSUM {poly}"));
    for (k, t) in tables.iter().enumerate() {
        assert_eq!(out.finals[k], eval_mle_ext(t, &ch));
        c.line(format!("SCMLE {k}"));
    }
    if n == 0 {
        return;
    }
    let one = Fp2::ONE;
    let mid = n / 2;
    let last = n - 1;
    // T1, T2: a wrong round count
    let mut p = out.proof.clone();
    p.rounds.pop();
    assert!(emit_verify(c, &format!("{name}-drop"), domain, key, false, claimed, deg, n, &p).0.is_err());
    let mut p = out.proof.clone();
    p.rounds.push(out.proof.rounds[last].clone());
    assert!(emit_verify(c, &format!("{name}-extra"), domain, key, false, claimed, deg, n, &p).0.is_err());
    // T3, T4: a wrong round length
    for j in [0, mid, last] {
        let mut p = out.proof.clone();
        p.rounds[j].pop();
        assert!(emit_verify(c, &format!("{name}-short{j}"), domain, key, false, claimed, deg, n, &p).0.is_err());
        let mut p = out.proof.clone();
        p.rounds[j].push(r.fp2());
        assert!(emit_verify(c, &format!("{name}-long{j}"), domain, key, false, claimed, deg, n, &p).0.is_err());
    }
    // T5: s(0) + s(1) off by one in round j; T6: the claimed sum off by one
    for j in [0, mid, last] {
        let mut p = out.proof.clone();
        p.rounds[j][0] = p.rounds[j][0].add(one);
        assert!(emit_verify(c, &format!("{name}-sum{j}"), domain, key, false, claimed, deg, n, &p).0.is_err());
    }
    assert!(emit_verify(c, &format!("{name}-claim"), domain, key, false, claimed.add(one), deg, n, &out.proof).0.is_err());
    // T7: a flipped value that passes its own round check (the last value): a later round, or the terminal, fails
    for j in [0, mid, last] {
        let mut p = out.proof.clone();
        let e = p.rounds[j].len() - 1;
        p.rounds[j][e] = p.rounds[j][e].add(one);
        let (res, _) = emit_verify(c, &format!("{name}-flip{j}"), domain, key, false, claimed, deg, n, &p);
        match res {
            Err(_) => {}
            Ok((f, _)) => {
                let good = f == poly_eval(poly, &out.finals);
                assert!(!good || deg == 1 && e == 1, "a flipped value passed the terminal check");
                c.line(format!("SCFIN {poly} {} {}", csv(&out.finals), good as u8));
            }
        }
    }
    // T8, T9: wrong `n_rounds` / `degree` arguments
    assert!(emit_verify(c, &format!("{name}-nr+1"), domain, key, false, claimed, deg, n + 1, &out.proof).0.is_err());
    assert!(emit_verify(c, &format!("{name}-nr-1"), domain, key, false, claimed, deg, n - 1, &out.proof).0.is_err());
    assert!(emit_verify(c, &format!("{name}-deg+1"), domain, key, false, claimed, deg + 1, n, &out.proof).0.is_err());
}

/// A masked sumcheck (`CfsMasker` installed on the prover's transcript), as `--zk` runs a standalone slot: the claim
/// `S + c·G`, the masked rounds in the proof, the terminal `poly(finals) + c·g(ρ)`.
fn masked_run(c: &mut Corpus, r: &mut Rng, name: &str, key: Option<[u8; 32]>, n: usize, poly: &str, tables: Vec<Vec<Fp2>>, deg: usize, seed: u64) {
    let domain = format!("lean-l6/msc/{name}");
    let domain = domain.as_bytes();
    let mut zr = ZkRng::new(seed, b"lean-l6 masked sumcheck");
    let mask = CfsMask::random(&mut zr, n, deg);
    let mut tp = mk_tr(domain, key);
    let cc = tp.challenge_fp2();
    let claimed = cube_sum(poly, &tables).add(cc.mul(mask.total()));
    tp.set_masker(Box::new(CfsMasker { mask: mask.clone(), c: cc, challenges: Vec::new() }));
    let mut tb = tables.clone();
    let out = sumcheck::prove(&mut tb, deg, |v| poly_eval(poly, v), &mut tp);
    let (_, masked) = tp.take_masker();
    assert_eq!(masked.len(), n);
    tables_lines(c, &tables);
    c.line(format!("SCMASK {n} {deg} {}", csv(&mask.coeffs)));
    let proof = SumcheckProof { rounds: masked };
    let (res, st) = emit_verify(c, name, domain, key, true, claimed, deg, n, &proof);
    let (fin, ch) = res.expect("the masked sumcheck verifies");
    assert_eq!(st, tp.state());
    assert_eq!(fin, poly_eval(poly, &out.finals).add(cc.mul(mask.eval(&ch))));
    for (j, u) in out.proof.rounds.iter().enumerate() {
        c.line(format!("SCUNM {j} {}", csv(u)));
    }
    c.line(format!("SCMFIN {poly} {} 1", csv(&out.finals)));
    c.line(format!("SCMSUM {poly}"));
    for (k, t) in tables.iter().enumerate() {
        assert_eq!(out.finals[k], eval_mle_ext(t, &ch));
        c.line(format!("SCMLE {k}"));
    }
    // tampered: s(0) + s(1) off by one, a flipped last value
    let mut p = proof.clone();
    p.rounds[n / 2][0] = p.rounds[n / 2][0].add(Fp2::ONE);
    assert!(emit_verify(c, &format!("{name}-sum"), domain, key, true, claimed, deg, n, &p).0.is_err());
    let mut p = proof.clone();
    p.rounds[0][deg] = p.rounds[0][deg].add(Fp2::ONE);
    assert!(emit_verify(c, &format!("{name}-flip"), domain, key, true, claimed, deg, n, &p).0.is_err() || n == 1);
    let _ = r;
}

/// A masked zero-check with the last-round extension, as `argument.rs` runs a private slot (one extension round): the
/// prover's rounds `0..n` masked by `CfsMasker`, round `n` the extension round `extension_round(finals, exts) + c·g_n`;
/// the verifier checks `n + 1` rounds and `poly((1 − ρ_n)·eq(τ, ρ), masked terminals) + c·g(ρ)`.
fn extended_run(c: &mut Corpus, r: &mut Rng, name: &str, key: Option<[u8; 32]>, n: usize, seed: u64) {
    let domain = format!("lean-l6/xsc/{name}");
    let domain = domain.as_bytes();
    let a = r.vec(1 << n);
    let b = r.vec(1 << n);
    let cab: Vec<Fp2> = a.iter().zip(b.iter()).map(|(x, y)| x.mul(*y)).collect();
    let tau = r.vec(n);
    let mut zr = ZkRng::new(seed, b"lean-l6 extended sumcheck");
    let mask = CfsMask::random(&mut zr, n + 1, 3);
    let ra: Vec<Fp2> = (0..1 << n).map(|_| zr.fp2()).collect();
    let rb: Vec<Fp2> = (0..1 << n).map(|_| zr.fp2()).collect();
    let rc: Vec<Fp2> = (0..1 << n).map(|_| zr.fp2()).collect();
    let poly = |v: &[Fp2]| poly_eval("zc", v);
    let mut tp = mk_tr(domain, key);
    let cc = tp.challenge_fp2();
    let claimed = Fp2::ZERO.add(cc.mul(mask.total()));
    tp.set_masker(Box::new(CfsMasker { mask: mask.clone(), c: cc, challenges: Vec::new() }));
    let tables = vec![eq_table_msb(&tau), a.clone(), b.clone(), cab.clone()];
    let mut tb = tables.clone();
    let out = sumcheck::prove(&mut tb, 3, poly, &mut tp);
    let (_, masked) = tp.take_masker();
    let rho = out.challenges.clone();
    let exts = vec![Fp2::ZERO, eval_mle_ext(&ra, &rho), eval_mle_ext(&rb, &rho), eval_mle_ext(&rc, &rho)];
    let mut sk = extension_round(&out.finals, &exts, 3, poly);
    let gk = mask.round(n, &rho);
    for (x, g) in sk.iter_mut().zip(gk.iter()) {
        *x = x.add(cc.mul(*g));
    }
    tp.absorb_fp2(b"sc-round", &sk);
    let rho_k = tp.challenge_fp2();
    let mut proof = SumcheckProof { rounds: masked };
    proof.rounds.push(sk);
    tables_lines(c, &tables);
    c.line(format!("SCMASK {} 3 {}", n + 1, csv(&mask.coeffs)));
    let (res, st) = emit_verify(c, name, domain, key, true, claimed, 3, n + 1, &proof);
    let (fin, ch) = res.expect("the extended sumcheck verifies");
    assert_eq!(st, tp.state());
    assert_eq!(ch[n], rho_k);
    let m: Vec<Fp2> = (1..4).map(|t| masked_terminal(out.finals[t], exts[t], rho_k)).collect();
    let eq_ext = Fp2::ONE.sub(ch[n]).mul(eq_point(&tau, &ch[..n]));
    assert_eq!(fin, poly(&[eq_ext, m[0], m[1], m[2]]).add(cc.mul(mask.eval(&ch))));
    for (j, u) in out.proof.rounds.iter().enumerate() {
        c.line(format!("SCUNM {j} {}", csv(u)));
    }
    c.line(format!("SCEXT zc {} {}", csv(&out.finals), csv(&exts)));
    c.line(format!("SCXTERM zc {} {} {} 1", csv(&tau), csv(&out.finals), csv(&exts)));
    c.line("SCMSUM zc".into());
    for k in 0..tables.len() {
        c.line(format!("SCMLE {k}"));
    }
    // tampered: the extension round's s(0) + s(1) off by one; a flipped masked terminal input
    let mut p = proof.clone();
    p.rounds[n][0] = p.rounds[n][0].add(Fp2::ONE);
    assert!(emit_verify(c, &format!("{name}-extsum"), domain, key, true, claimed, 3, n + 1, &p).0.is_err());
    let mut bad = exts.clone();
    bad[2] = bad[2].add(Fp2::ONE);
    tables_lines(c, &tables);
    c.line(format!("SCMASK {} 3 {}", n + 1, csv(&mask.coeffs)));
    let _ = emit_verify(c, name, domain, key, true, claimed, 3, n + 1, &proof);
    let mb: Vec<Fp2> = (1..4).map(|t| masked_terminal(out.finals[t], bad[t], rho_k)).collect();
    assert_ne!(fin, poly(&[eq_ext, mb[0], mb[1], mb[2]]).add(cc.mul(mask.eval(&ch))));
    c.line(format!("SCXTERM zc {} {} {} 0", csv(&tau), csv(&out.finals), csv(&bad)));
}

fn sumcheck_records(c: &mut Corpus, r: &mut Rng) {
    let key = *HashTag::for_profile(RUNG_G).transcript_key().expect("a tagged profile carries a transcript key");
    // plain sumchecks: degrees 1..6, 0..8 variables, the legacy and the keyed transcript
    for (name, tagged, n, k) in [("p1", false, 4usize, 1usize), ("p2", true, 5, 2), ("p3", false, 3, 3), ("p4", false, 2, 4), ("p5", true, 3, 5), ("p6", false, 1, 6), ("p2n0", false, 0, 2), ("p2n8", false, 8, 2)] {
        let tables: Vec<Vec<Fp2>> = (0..k).map(|_| r.vec(1 << n)).collect();
        plain_run(c, r, name, if tagged { Some(key) } else { None }, n, "prod", tables, k);
    }
    // the zero-check form (eq table, degree 3)
    let n = 6usize;
    let a = r.vec(1 << n);
    let b = r.vec(1 << n);
    let cab: Vec<Fp2> = a.iter().zip(b.iter()).map(|(x, y)| x.mul(*y)).collect();
    let tau = r.vec(n);
    plain_run(c, r, "zc6", None, n, "zc", vec![eq_table_msb(&tau), a, b, cab], 3);
    // masked
    for (name, tagged, n, k, seed) in [("m2", false, 4usize, 2usize, 71u64), ("m3", true, 3, 3, 72), ("m1", false, 1, 2, 73)] {
        let tables: Vec<Vec<Fp2>> = (0..k).map(|_| r.vec(1 << n)).collect();
        masked_run(c, r, name, if tagged { Some(key) } else { None }, n, "prod", tables, k, seed);
    }
    // masked with the last-round extension
    extended_run(c, r, "x4", None, 4, 81);
    extended_run(c, r, "x5", Some(key), 5, 82);
    extended_run(c, r, "x1", None, 1, 83);
}

#[test]
fn lean_l6_export_the_agreement_corpus() {
    let mut c = Corpus { out: String::new(), n: 0 };
    let _ = writeln!(c.out, "# D63 L6 agreement corpus (zkp-core tests/lean_l6_export.rs); one record per line");
    let mut r = Rng(0x16_d63_16_d63);
    interp_records(&mut c, &mut r);
    eq_records(&mut c, &mut r);
    cfs_records(&mut c, &mut r);
    sumcheck_records(&mut c, &mut r);
    eprintln!("LEAN-L6: {} records, {} bytes", c.n, c.out.len());
    assert!(c.out.len() < 1 << 20, "the corpus must stay under 1 MB");
    if let Ok(path) = std::env::var("LEAN_L6_CORPUS") {
        std::fs::write(&path, &c.out).expect("write the corpus");
        eprintln!("LEAN-L6: written to {path}");
    }
}
