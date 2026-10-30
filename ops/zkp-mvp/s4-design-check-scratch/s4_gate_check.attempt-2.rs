//! S4 design check (reviewer's own harness; adapted from Sol's cfs_lift.rs,
//! which is read-only evidence). Linked to the pinned normal-release R13 rlib.
//! Public deterministic fixtures only; not the private-block wire/profile.
//!
//! Adds a third style, PublicGate: the private smaller piece is the NATIVE
//! broadcast table (priv_table semantics: constant in the omitted feature
//! bits), the zero lift lives only in a PUBLIC factor (the zero-padded folded
//! weight for a matmul, a public gate table eq(0^k, b) for the norm), and the
//! PCS claim is the plain native claim at the projected point: data (1 - e),
//! reserved pair e, no sigma anywhere in a private functional.
//! Styles WholeLift and IndependentExperimental are Sol's, re-run here.
use hashline::field::{Fp, Fp2};
use hashline::mle::eval_mle_ext;
use hashline::ntt::NttTables;
use hashline::pcs::{self, Commitment, OpeningZk, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use hashline::sumcheck::{self, CfsMask, CfsMasker, SumcheckProof};
use hashline::transcript::Transcript;
use hashline::zk::{self, MaskFunctional, MaskOpening, ZkRng};

fn lg(n: usize) -> usize { assert!(n.is_power_of_two()); n.trailing_zeros() as usize }
fn base(x: Fp) -> Fp2 { Fp2::new(x, Fp::ZERO) }
fn eval(a: &[Fp], p: &[Fp2]) -> Fp2 { eval_mle_ext(&a.iter().copied().map(base).collect::<Vec<_>>(), p) }

#[derive(Clone, Copy, Debug)]
struct Geo { t: usize, big: usize, small: usize }
impl Geo {
    fn project(self, rho: &[Fp2], dropped: std::ops::Range<usize>) -> (Fp2, Vec<Fp2>) {
        let mut s = Fp2::ONE; let mut p = Vec::new();
        for (i, &r) in rho.iter().enumerate() { if dropped.contains(&i) { s = s.mul(Fp2::ONE.sub(r)); } else { p.push(r); } }
        (s, p)
    }
    fn lift(self, t: usize, a: &[Fp2]) -> Vec<Fp2> {
        let mut v = vec![Fp2::ZERO; t * self.big];
        for r in 0..t { v[r*self.big..r*self.big+self.small].copy_from_slice(&a[r*self.small..(r+1)*self.small]); }
        v
    }
    fn broadcast(self, t: usize, a: &[Fp2]) -> Vec<Fp2> {
        (0..t * self.big).map(|i| a[(i / self.big) * self.small + (i % self.big) % self.small]).collect()
    }
}

#[derive(Clone, Copy, Debug, PartialEq)] enum Kind { Matmul, Norm }
#[derive(Clone, Copy, Debug, PartialEq)] enum Style { WholeLift, Independent, PublicGate }
#[derive(Clone, Copy, Debug, PartialEq)]
enum Attack { Honest, OtherTableRule, DropSmall, DuplicateSmall, WrongAxis, OtherMaskScale, WrongPoint, WrongMaskRow, SwapPieces, OmitGate }
const ATTACKS: [Attack; 9] = [Attack::OtherTableRule, Attack::DropSmall, Attack::DuplicateSmall, Attack::WrongAxis,
    Attack::OtherMaskScale, Attack::WrongPoint, Attack::WrongMaskRow, Attack::SwapPieces, Attack::OmitGate];

fn normalize(claims: Vec<ZClaim>) -> Result<Vec<ZClaim>, String> {
    let mut out = Vec::new();
    for c in claims {
        if c.parts.iter().all(|p| p.coef == Fp2::ZERO) { if c.value != Fp2::ZERO { return Err("zero functional claims a nonzero value".into()); } }
        else { out.push(c); }
    }
    Ok(out)
}

#[derive(Clone)]
struct Fixture {
    g: Geo, kind: Kind, style: Style, params: PcsParams, zk: ZkOpts, data: Vec<Fp>,
    offsets: [usize; 2], mask_rows: [usize; 2], prox: usize,
    publics: Vec<Vec<Fp2>>, token_point: Option<Vec<Fp2>>, expected_sum: Fp2,
}
impl Fixture {
    fn cube_t(&self) -> usize { if self.token_point.is_some() { 1 } else { self.g.t } }
    fn new(g: Geo, kind: Kind, style: Style, fixed_tokens: bool, rng: &mut ZkRng) -> Self {
        let params = PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 8 };
        let n = params.cols(); let big_len = g.t*g.big; let small_len = g.t*g.small;
        let small_off = big_len.div_ceil(n)*n + if small_len < n { n-small_len } else { 0 };
        let rows = (small_off+small_len).div_ceil(n);
        let mask_rows = [rows, rows+2]; let prox = rows+4;
        let data = (0..(rows+5)*n).map(|_| rng.fp()).collect::<Vec<_>>();
        let token_point = if fixed_tokens { Some(rng.fp2_vec(lg(g.t))) } else { None };
        let ct = if fixed_tokens { 1 } else { g.t };
        let mut publics = match kind {
            // the second public is the ZERO-PADDED folded weight of the smaller piece: the gate is in it
            Kind::Matmul => vec![rng.fp2_vec(ct*g.big), g.lift(ct, &rng.fp2_vec(ct*g.small))],
            Kind::Norm => { let eq = hashline::mle::eq_table_msb(&rng.fp2_vec(lg(g.t))); vec![(0..big_len).map(|i| eq[i/g.big]).collect()] }
        };
        if style == Style::PublicGate && kind == Kind::Norm { publics.push(g.lift(g.t, &vec![Fp2::ONE; small_len])); }
        let zk = ZkOpts::standard(&params);
        let mut f = Self { g, kind, style, params, zk, data, offsets: [0, small_off], mask_rows, prox, publics, token_point, expected_sum: Fp2::ZERO };
        let tabs = f.tables(Attack::Honest);
        f.expected_sum = (0..tabs[0].len()).fold(Fp2::ZERO, |s,i| s.add(f.poly(&tabs.iter().map(|t|t[i]).collect::<Vec<_>>())));
        // independent reference: the two TRUE piece sums, no cube lift and no gate
        let (a, b) = (f.source(0).to_vec(), f.source(1).to_vec());
        let teq = f.token_point.as_ref().map(|p| hashline::mle::eq_table_msb(p));
        let w1 = |j: usize| f.publics[1][j]; // zero-padded fold: entries j < small are the piece's true weights
        let mut reference = Fp2::ZERO;
        for t in 0..g.t {
            for j in 0..g.big { let y = base(a[t*g.big+j]); reference = reference.add(match kind {
                Kind::Matmul => if let Some(e) = &teq { e[t].mul(f.publics[0][j]).mul(y) } else { f.publics[0][t*g.big+j].mul(y) },
                Kind::Norm => f.publics[0][t*g.big].mul(y.mul(y)) }); }
            for j in 0..g.small { let y = base(b[t*g.small+j]); reference = reference.add(match kind {
                Kind::Matmul => if let Some(e) = &teq { e[t].mul(w1(j)).mul(y) } else { f.publics[1][t*g.big+j].mul(y) },
                Kind::Norm => f.publics[0][t*g.big].mul(y.mul(y)) }); }
        }
        assert_eq!(f.expected_sum, reference, "{style:?} {kind:?}: lifted cube sum != true piece sums");
        f
    }
    fn source(&self, i: usize) -> &[Fp] { let len = self.g.t * if i == 0 { self.g.big } else { self.g.small }; &self.data[self.offsets[i]..self.offsets[i]+len] }
    fn degree(&self) -> usize { if self.kind == Kind::Matmul { 2 } else { 3 } }
    fn n(&self) -> usize { if self.token_point.is_some() { lg(self.g.big) } else { lg(self.g.t * self.g.big) } }
    fn dropped(&self) -> std::ops::Range<usize> { let s = if self.token_point.is_some() { 0 } else { lg(self.g.t) }; s..s + lg(self.g.big/self.g.small) }
    fn fresh_masks(&self, rng: &mut ZkRng) -> Self { let mut o = self.clone(); let n = self.params.cols(); for x in &mut o.data[self.mask_rows[0]*n..(self.prox+1)*n] { *x = rng.fp(); } o }
    fn poly(&self, v: &[Fp2]) -> Fp2 {
        let p = self.publics.len(); let (a, b) = (v[p], v[p+1]);
        match (self.kind, self.style) {
            (Kind::Matmul, _) => v[0].mul(a).add(v[1].mul(b)),
            (Kind::Norm, Style::PublicGate) => v[0].mul(a.mul(a).add(v[1].mul(b.mul(b)))),
            (Kind::Norm, _) => v[0].mul(a.mul(a).add(b.mul(b))),
        }
    }
    /// the smaller piece's table in the slot cube, by this style's rule
    fn small_table(&self, b: &[Fp2], gate_rule: bool) -> Vec<Fp2> {
        if gate_rule { self.g.broadcast(self.cube_t(), b) } else { self.g.lift(self.cube_t(), b) }
    }
    fn tables(&self, attack: Attack) -> Vec<Vec<Fp2>> {
        let fold = |i: usize, wrong: bool| {
            let src = self.source(i); let width = if i == 0 { self.g.big } else { self.g.small };
            if let Some(p) = &self.token_point {
                let mut p = p.clone(); if wrong { p[0] = p[0].add(Fp2::ONE); }
                let e = hashline::mle::eq_table_msb(&p);
                (0..width).map(|j| (0..self.g.t).fold(Fp2::ZERO, |v,t| v.add(e[t].mul(base(src[t*width+j]))))).collect::<Vec<_>>()
            } else { src.iter().copied().map(base).collect::<Vec<_>>() }
        };
        let mut a = fold(0, false); let mut b = fold(1, attack == Attack::WrongAxis);
        let ct = self.cube_t();
        if attack == Attack::SwapPieces { for t in 0..ct { for j in 0..self.g.small { std::mem::swap(&mut a[t*self.g.big+j], &mut b[t*self.g.small+j]); } } }
        let gate_rule = self.style == Style::PublicGate;
        let mut small = self.small_table(&b, gate_rule ^ (attack == Attack::OtherTableRule));
        match attack {
            Attack::DropSmall => small.fill(Fp2::ZERO),
            Attack::DuplicateSmall => for x in &mut small { *x = x.add(*x); },
            Attack::WrongAxis if self.token_point.is_none() => {
                // omit / replicate over the leading TOKEN bits instead of the leading feature bits
                let len = small.len();
                small = (0..len).map(|i| if gate_rule { b[i % b.len()] } else if i < b.len() { b[i] } else { Fp2::ZERO }).collect();
            }
            _ => {}
        }
        let mut pubs = self.publics.clone();
        if attack == Attack::OmitGate {
            // the prover sums with a broadcast table and NO zero lift anywhere (the "repeated cube")
            small = self.g.broadcast(ct, &b);
            if self.kind == Kind::Matmul { pubs[1] = self.g.broadcast(ct, &(0..ct).flat_map(|t| (0..self.g.small).map(move |j| (t, j))).map(|(t, j)| self.publics[1][t*self.g.big + j]).collect::<Vec<_>>()); }
            else if gate_rule { pubs[1] = vec![Fp2::ONE; pubs[1].len()]; }
        }
        pubs.push(a); pubs.push(small); pubs
    }
    /// (data scale, mask scale) of the smaller piece's claim
    fn scales(&self, sigma: Fp2) -> (Fp2, Fp2) {
        match self.style { Style::WholeLift => (sigma, sigma), Style::Independent => (sigma, Fp2::ONE), Style::PublicGate => (Fp2::ONE, Fp2::ONE) }
    }
    fn source_point(&self, i: usize, rho: &[Fp2]) -> (Fp2, Vec<Fp2>) {
        let mut full = self.token_point.clone().unwrap_or_default(); full.extend_from_slice(rho);
        if i == 0 { return (Fp2::ONE, full); }
        let off = self.token_point.as_ref().map_or(0, |p| p.len());
        let d = self.dropped(); self.g.project(&full, d.start + off..d.end + off)
    }
    fn mask_value(&self, i: usize, p: &[Fp2]) -> Fp2 {
        let n = self.params.cols(); let logm = p.len().min(self.params.log_cols as usize);
        let c0 = if p.len() < self.params.log_cols as usize { self.offsets[i] % n } else { 0 };
        let tail = &p[p.len()-logm..]; let len = 1 << logm;
        let row = |r| eval(&self.data[r*n+c0..r*n+c0+len], tail);
        row(self.mask_rows[i]).add(Fp2::U.mul(row(self.mask_rows[i]+1)))
    }
    fn claims(&self, rho: &[Fp2], e: Fp2, terms: &[Fp2]) -> Vec<ZClaim> {
        let n = self.params.cols();
        (0..2).map(|i| {
            let (sigma, p) = self.source_point(i, rho); let (sd, sm) = if i == 0 { (Fp2::ONE, Fp2::ONE) } else { self.scales(sigma) };
            let logm = p.len().min(self.params.log_cols as usize);
            let c0 = if p.len() < self.params.log_cols as usize { self.offsets[i] % n } else { 0 };
            let tail = p[p.len()-logm..].to_vec(); let mc = e.mul(sm);
            ZClaim { parts: vec![
                ZPart { slice: Slice { offset: self.offsets[i], log_size: p.len() as u32 }, coef: Fp2::ONE.sub(e).mul(sd), point: p },
                ZPart { slice: Slice { offset: self.mask_rows[i]*n+c0, log_size: logm as u32 }, coef: mc, point: tail.clone() },
                ZPart { slice: Slice { offset: (self.mask_rows[i]+1)*n+c0, log_size: logm as u32 }, coef: mc.mul(Fp2::U), point: tail }], value: terms[i] }
        }).collect()
    }
    fn transcript(&self, root: &Commitment, mroot: &[u8; 32]) -> Transcript {
        let mut tr = Transcript::new(b"s4-design-check-gate-fixture-v1");
        tr.absorb(b"A", &root.root); tr.absorb(b"M", mroot);
        tr.absorb_u64(b"style", self.style as u64); tr.absorb_u64(b"fixed-tokens", self.token_point.is_some() as u64);
        if let Some(p) = &self.token_point { tr.absorb_fp2(b"token-point", p); }
        for x in [self.g.t, self.g.big, self.g.small, self.degree()] { tr.absorb_u64(b"geometry", x as u64); }
        for p in &self.publics { tr.absorb_fp2(b"public", p); }
        tr.absorb_fp2(b"expected-sum", &[self.expected_sum]); tr
    }
    fn functionals(&self, scalar: Fp2, c: Fp2, rho: &[Fp2], g_value: Fp2) -> Vec<MaskFunctional> {
        vec![MaskFunctional { terms: vec![(0, CfsMask::sum_weights(self.n()+1, self.degree()).into_iter().map(|w| w.mul(c)).collect())], value: scalar.sub(self.expected_sum) },
             MaskFunctional { terms: vec![(0, CfsMask::eval_weights(rho, self.degree()))], value: g_value }]
    }
}

struct Proof { root: Commitment, mroot: [u8; 32], scalar: Fp2, sc: SumcheckProof, terms: Vec<Fp2>, a: OpeningZk, m: MaskOpening }
fn prove(f: &Fixture, attack: Attack, ntt: &NttTables, rng: &mut ZkRng) -> Proof {
    let owned = f.fresh_masks(rng); let f = &owned;
    let mut cm = pcs::commit_zk_owned(&f.params, f.data.clone(), ntt, &f.zk, rng);
    cm.mask_rows = (f.mask_rows[0]..f.prox).collect(); cm.prox_mask_row = Some(f.prox);
    let root = cm.commitment(); let specs = [(f.n()+1, f.degree())];
    let mc = zk::mask_commit(&specs, ntt, rng); let mroot = mc.tree.root(); let mask = &mc.masks[0];
    let mut tr = f.transcript(&root, &mroot); let c = tr.challenge_fp2(); assert!(!c.is_zero());
    let mut tables = f.tables(attack);
    let poly = |v: &[Fp2]| { if attack == Attack::OmitGate { let p = f.publics.len(); let (a, b) = (v[p], v[p+1]); match f.kind {
        Kind::Matmul => v[0].mul(a).add(v[1].mul(b)), Kind::Norm => v[0].mul(a.mul(a).add(b.mul(b))) } } else { f.poly(v) } };
    let actual = (0..tables[0].len()).fold(Fp2::ZERO, |s,i| s.add(poly(&tables.iter().map(|t| t[i]).collect::<Vec<_>>())));
    let scalar = actual.add(c.mul(mask.total())); tr.absorb_fp2(b"scalar", &[scalar]);
    tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
    let out = sumcheck::prove(&mut tables, f.degree(), |v| poly(v), &mut tr); let (_, mut rounds) = tr.take_masker();
    let mut exts = vec![Fp2::ZERO; out.finals.len()];
    let p0 = f.publics.len();
    for i in 0..2 {
        let (sigma, p) = f.source_point(i, &out.challenges);
        let (_, sm) = if i == 0 { (Fp2::ONE, Fp2::ONE) } else { f.scales(sigma) };
        // the attack scales the extension mask by the OTHER rule (sigma <-> 1)
        let sm = if attack == Attack::OtherMaskScale && i == 1 { if sm == Fp2::ONE { sigma } else { Fp2::ONE } } else { sm };
        exts[p0 + i] = f.mask_value(i, &p).mul(sm);
    }
    assert_eq!(poly(&exts), Fp2::ZERO, "extension-zero property");
    let sk = sumcheck::extension_round(&out.finals, &exts, f.degree(), |v| poly(v));
    let gk = mask.round(f.n(), &out.challenges);
    let sk = sk.iter().zip(gk).map(|(x, g)| x.add(c.mul(g))).collect::<Vec<_>>();
    tr.absorb_fp2(b"sc-round", &sk); rounds.push(sk); let e = tr.challenge_fp2(); assert!(e != Fp2::ZERO && e != Fp2::ONE);
    let mut terms = (0..2).map(|i| sumcheck::masked_terminal(out.finals[p0+i], exts[p0+i], e)).collect::<Vec<_>>();
    // perturb a RETAINED coordinate (the last feature bit): under PublicGate the
    // omitted leading feature bit enters no private functional, so moving it
    // would be a vacuous control (first run of this harness: "accepted")
    let wrong_rho = || { let mut w = out.challenges.clone(); let l = w.len() - 1; w[l] = w[l].add(Fp2::ONE); w };
    if attack == Attack::WrongPoint {
        let w = wrong_rho(); let (s, p) = f.source_point(1, &w); let (sd, sm) = f.scales(s);
        let forged = Fp2::ONE.sub(e).mul(sd).mul(eval(f.source(1), &p)).add(e.mul(sm).mul(f.mask_value(1, &p)));
        assert_ne!(forged, terms[1], "non-vacuity: the wrong-point terminal must differ");
        terms[1] = forged;
    }
    tr.absorb_fp2(b"terms", &terms);
    let mut claims = f.claims(&out.challenges, e, &terms);
    if attack == Attack::WrongPoint { claims[1] = f.claims(&wrong_rho(), e, &terms).remove(1); }
    if attack == Attack::WrongMaskRow { claims[1].parts[1].slice.offset = f.mask_rows[0]*f.params.cols() + claims[1].parts[1].slice.offset % f.params.cols(); }
    let a = pcs::open_zk(&cm, &normalize(claims).unwrap(), &mut tr);
    let mut full = out.challenges; full.push(e);
    let fs = f.functionals(scalar, c, &full, mask.eval(&full)); let m = zk::mask_open(&mc, &fs, ntt, &mut tr);
    Proof { root, mroot, scalar, sc: SumcheckProof { rounds }, terms, a, m }
}
fn verify(f: &Fixture, p: &Proof, ntt: &NttTables) -> Result<(), String> {
    let mut tr = f.transcript(&p.root, &p.mroot); let c = tr.challenge_fp2(); if c.is_zero() { return Err("zero c".into()); }
    tr.absorb_fp2(b"scalar", &[p.scalar]); let (fin, full) = sumcheck::verify(p.scalar, f.degree(), f.n()+1, &p.sc, &mut tr)?;
    let rho = &full[..f.n()]; let e = full[f.n()]; if e == Fp2::ZERO || e == Fp2::ONE { return Err("zero/one extension".into()); }
    if p.terms.len() != 2 { return Err("terms".into()); }
    let mut vals = f.publics.iter().map(|v| Fp2::ONE.sub(e).mul(eval_mle_ext(v, rho))).collect::<Vec<_>>(); vals.extend_from_slice(&p.terms);
    let g_value = fin.sub(f.poly(&vals)).mul(c.inv()); tr.absorb_fp2(b"terms", &p.terms);
    pcs::verify_zk(&f.params, &f.zk, &p.root, &normalize(f.claims(rho, e, &p.terms))?, &p.a, ntt, &mut tr)?;
    zk::mask_verify(&p.mroot, &[(f.n()+1, f.degree())], &f.functionals(p.scalar, c, &full, g_value), &p.m, ntt, &mut tr)
}

/// sigma = 0 (an omitted feature challenge equal to 1), direct functional test.
fn zero_edge(f: &Fixture, ntt: &NttTables, rng: &mut ZkRng) -> usize {
    let owned = f.fresh_masks(rng); let f = &owned;
    let mut cm = pcs::commit_zk_owned(&f.params, f.data.clone(), ntt, &f.zk, rng);
    cm.mask_rows = (f.mask_rows[0]..f.prox).collect(); cm.prox_mask_row = Some(f.prox);
    let root = cm.commitment();
    let mut rho = (0..f.n()).map(|i| Fp2::new(Fp::new(3+i as u64), Fp::new(11+i as u64))).collect::<Vec<_>>();
    rho[f.dropped().start] = Fp2::ONE; let (sigma, _) = f.source_point(1, &rho); assert_eq!(sigma, Fp2::ZERO);
    let e = Fp2::new(Fp::new(13), Fp::new(17));
    let terms = (0..2).map(|i| { let (s, p) = f.source_point(i, &rho); let (sd, sm) = if i == 0 { (Fp2::ONE, Fp2::ONE) } else { f.scales(s) };
        Fp2::ONE.sub(e).mul(sd).mul(eval(f.source(i), &p)).add(e.mul(sm).mul(f.mask_value(i, &p))) }).collect::<Vec<_>>();
    let tr = || { let mut t = Transcript::new(b"s4-design-check-zero-direct"); t.absorb(b"root", &root.root); t };
    let claims = f.claims(&rho, e, &terms);
    let mut bad = claims.clone(); bad[1].value = bad[1].value.add(Fp2::ONE);
    let mut rejected = 0;
    match f.style {
        Style::PublicGate => {
            // every private functional is the native one: no normalization, the native mask assertion holds
            assert!(claims.iter().all(|c| c.parts.iter().all(|p| p.coef != Fp2::ZERO)));
            let a = pcs::open_zk(&cm, &claims, &mut tr()); pcs::verify_zk(&f.params, &f.zk, &root, &claims, &a, ntt, &mut tr()).unwrap();
            assert!(pcs::verify_zk(&f.params, &f.zk, &root, &bad, &a, ntt, &mut tr()).is_err()); rejected += 1;
            // the public gate factor of the smaller piece's monomial vanishes at this point
            let gate = if f.kind == Kind::Matmul { eval_mle_ext(&f.publics[1], &rho) } else { eval_mle_ext(&f.publics[1], &rho) };
            assert_eq!(gate, Fp2::ZERO);
            // and the smaller piece's terminal is still the masked value: (1-e) Y(p') + e R(tail)
            let (_, p1) = f.source_point(1, &rho); assert_ne!(terms[1], Fp2::ONE.sub(e).mul(eval(f.source(1), &p1)));
            rejected += 1;
        }
        Style::WholeLift => {
            let normalized = normalize(claims.clone()).unwrap(); assert_eq!(normalized.len(), 1);
            let a = pcs::open_zk(&cm, &normalized, &mut tr()); pcs::verify_zk(&f.params, &f.zk, &root, &normalized, &a, ntt, &mut tr()).unwrap();
            assert!(normalize(bad).is_err()); rejected += 1;
            assert_eq!(terms[1], Fp2::ZERO); rejected += 1;
        }
        Style::Independent => {
            let a = pcs::open_zk(&cm, &claims, &mut tr()); pcs::verify_zk(&f.params, &f.zk, &root, &claims, &a, ntt, &mut tr()).unwrap();
            assert!(pcs::verify_zk(&f.params, &f.zk, &root, &bad, &a, ntt, &mut tr()).is_err()); rejected += 1;
            let (_, p1) = f.source_point(1, &rho); assert_eq!(terms[1], e.mul(f.mask_value(1, &p1))); rejected += 1;
        }
    }
    rejected
}

fn main() {
    let ntt = NttTables::new(13); let mut rng = ZkRng::new(4242, b"s4-design-check-public-fixtures-only");
    let (mut accepted, mut rejected, mut zero) = (0, 0, 0);
    let mut by_style = std::collections::BTreeMap::new();
    for g in [Geo { t: 2, big: 8, small: 4 }, Geo { t: 2, big: 32, small: 4 }, Geo { t: 16, big: 8, small: 4 }, Geo { t: 16, big: 32, small: 4 }, Geo { t: 8, big: 64, small: 8 }] {
        for (kind, fixed) in [(Kind::Matmul, false), (Kind::Matmul, true), (Kind::Norm, false)] {
            for style in [Style::WholeLift, Style::Independent, Style::PublicGate] {
                let f = Fixture::new(g, kind, style, fixed, &mut rng);
                let p = prove(&f, Attack::Honest, &ntt, &mut rng); verify(&f, &p, &ntt).unwrap(); accepted += 1;
                for attack in ATTACKS {
                    let p = prove(&f, attack, &ntt, &mut rng);
                    let err = verify(&f, &p, &ntt).expect_err(&format!("FORGERY ACCEPTED {g:?} {kind:?} fixed={fixed} {style:?} {attack:?}"));
                    println!("rejected {g:?} {kind:?} fixed_tokens={fixed} {style:?} {attack:?}: {err}"); rejected += 1;
                    *by_style.entry(format!("{style:?}")).or_insert(0usize) += 1;
                }
                zero += zero_edge(&f, &ntt, &mut rng);
            }
        }
    }
    println!("{{\"honest_microproofs\":{accepted},\"forgeries_rejected\":{rejected},\"rejected_by_style\":{by_style:?},\"zero_edge_checks\":{zero},\"scope\":\"reviewer harness: native CFS/sumcheck/PCS/M components, three mask styles incl. PublicGate; not the private-block wire/profile; not a privacy acceptance\"}}");
}
