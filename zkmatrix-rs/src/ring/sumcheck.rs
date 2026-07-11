// U-K2 (M4_LOOKUP_DESIGN.md Section 8): the sumcheck core over the
// slot field K = GF(q^16) — the transcript layer every LogUp/GKR round
// of the lookup rides (and the engine GATE_ALTERNATIVES option 2 would
// reuse for a hash-sumcheck gate).
//
// Conventions (the design's, pinned by the spike's recorded bug class):
// multilinear tables are stored little-endian — VARIABLE 0 IS THE
// LOWEST BIT, so binding variable 0 pairs adjacent entries
// (T[2i], T[2i+1]) and a GKR layer's child bit is the first variable
// bound. A degree-d round polynomial is sent as its d+1 evaluations at
// X = 0..d; the verifier checks g(0) + g(1) = C, then folds
// C <- g(r) by Lagrange interpolation on the nodes 0..d (denominators
// are small FIXED integers, inverted in the base field — the verifier
// never inverts in K).
//
// The relation shape is caller-supplied: the prover sums, over the
// unbound hypercube, `combine` applied to one extrapolated value per
// factor table. combine must be a polynomial of total degree <= the
// declared degree in its inputs' shared variable (degree 3 for the
// fractional-GKR layer relation p0 q1 + p1 q0 + lambda q0 q1 with the
// eq weight; the U-K2 battery drives it with a plain triple product).
//
// Hash ordering (the E3-N4 edge, SOUNDNESS_REFERENCE Section 7
// discipline): every round challenge r_t is drawn from the transcript
// state AFTER round t's polynomial is absorbed — a challenge known
// before its polynomial lets a cheating prover interpolate any false
// claim's defect into an unchecked node (the [U-K2] battery
// demonstrates the exact crafting in both directions, F5 style).

use sha2::{Digest, Sha256};

use super::XofReader;
use super::kfield::{KElem, KField};

// ---------------------------------------------------------------------------
// The transcript: a ratcheting hash chain. Every absorbed message and
// every drawn challenge extends the state, so nothing can be reordered
// or replayed without changing every later challenge.

pub struct LkpTranscript {
    state: [u8; 32],
    /// Honest-verifier coin mode: absorbs are NO-OPS and challenges
    /// stream from the seed alone. This is NOT a protocol path — it is
    /// the leak-harness tool that models the honest-verifier view
    /// (challenges independent of the prover's messages), exactly the
    /// spike's content-blind Tape; the U-K5c m-recovery harness needs
    /// it so the transcript stays an affine function of the witness.
    fixed_coins: bool,
}

impl LkpTranscript {
    /// Seed from a statement hash that must already bind everything the
    /// first challenge is required to follow (h0_lkp: ctx, CRS, every
    /// witness/multiplicity commitment — the alpha edge).
    pub fn new(domain: &str, h0: &[u8]) -> LkpTranscript {
        let mut hasher = Sha256::new();
        hasher.update(domain.as_bytes());
        hasher.update(h0);
        LkpTranscript { state: hasher.finalize().into(), fixed_coins: false }
    }

    /// The HONEST-VERIFIER coin tape (see the field doc). Battery use
    /// only.
    pub fn fixed_coins(domain: &str, seed: &[u8]) -> LkpTranscript {
        let mut t = LkpTranscript::new(domain, seed);
        t.fixed_coins = true;
        t
    }

    pub fn absorb(&mut self, label: &str, bytes: &[u8]) {
        if self.fixed_coins {
            return;
        }
        let mut hasher = Sha256::new();
        hasher.update(self.state);
        hasher.update(label.as_bytes());
        hasher.update((bytes.len() as u64).to_le_bytes());
        hasher.update(bytes);
        self.state = hasher.finalize().into();
    }

    pub fn absorb_k(&mut self, kf: &KField, label: &str, elems: &[KElem]) {
        let mut bytes = Vec::with_capacity(elems.len() * 16 * 8);
        for e in elems {
            bytes.extend_from_slice(&kf.bytes(e));
        }
        self.absorb(label, &bytes);
    }

    /// Draw a uniform K challenge from the current state, then ratchet
    /// the state with the drawn value (fixed-coins mode ratchets by a
    /// content-independent tick instead, so successive draws differ
    /// while staying independent of every absorbed message).
    pub fn challenge_k(&mut self, kf: &KField) -> KElem {
        let mut reader = XofReader::new("lkp-chal", &[&self.state]);
        let e = kf.uniform(&mut reader);
        if self.fixed_coins {
            let mut hasher = Sha256::new();
            hasher.update(self.state);
            hasher.update(b"hv-tick");
            self.state = hasher.finalize().into();
        } else {
            self.absorb("chal", &kf.bytes(&e));
        }
        e
    }

    /// The current state — the downstream binding handle: E4 seeds its
    /// psi randomizers and the ct-round's h0 from this, so the round
    /// binds the ENTIRE lookup transcript (the design's Section 3.3
    /// rule: round restarts re-derive c but never any lookup challenge).
    pub fn state(&self) -> [u8; 32] {
        self.state
    }
}

// ---------------------------------------------------------------------------
// Table primitives shared by the sumcheck, the GKR descent (U-K3) and
// the E4 evaluation claims.

/// Bind variable 0 of a little-endian multilinear table to r:
/// T'[i] = T[2i] + r (T[2i+1] - T[2i]). Halves the table.
pub fn fold(kf: &KField, table: &[KElem], r: &KElem) -> Vec<KElem> {
    assert!(table.len() >= 2 && table.len() % 2 == 0);
    (0..table.len() / 2)
        .map(|i| {
            let d = kf.sub(&table[2 * i + 1], &table[2 * i]);
            kf.add(&table[2 * i], &kf.mul(r, &d))
        })
        .collect()
}

/// Evaluate the multilinear extension of a table at a point (variable
/// 0 first — the fold order). The E4 claim value v = MLE(T)(r).
pub fn mle_eval(kf: &KField, table: &[KElem], point: &[KElem]) -> KElem {
    assert_eq!(table.len(), 1 << point.len());
    let mut cur = table.to_vec();
    for r in point {
        cur = fold(kf, &cur, r);
    }
    cur.remove(0)
}

/// One round's polynomial for the relation sum_b combine(T_1(X, b), ..,
/// T_m(X, b)): evaluations at X = 0..degree, where each factor is
/// extrapolated linearly in the bound variable
/// (T(X, b) = T(0, b) + X (T(1, b) - T(0, b))).
pub fn round_poly(
    kf: &KField,
    tables: &[Vec<KElem>],
    degree: usize,
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
) -> Vec<KElem> {
    let half = tables[0].len() / 2;
    let mut g = vec![kf.zero(); degree + 1];
    let mut vals = vec![kf.zero(); tables.len()];
    for i in 0..half {
        for (x, gx) in g.iter_mut().enumerate() {
            for (t, table) in tables.iter().enumerate() {
                let d = kf.sub(&table[2 * i + 1], &table[2 * i]);
                vals[t] = kf.add(&table[2 * i], &kf.scale(x as u64, &d));
            }
            *gx = kf.add(gx, &combine(kf, &vals));
        }
    }
    g
}

/// Lagrange evaluation of a round polynomial (evals at nodes 0..d) at
/// an arbitrary K point r. Node differences are fixed small integers,
/// inverted in the BASE field.
pub fn lagrange_eval(kf: &KField, evals: &[KElem], r: &KElem) -> KElem {
    let d = evals.len() - 1;
    let zq = &kf.zq;
    let mut acc = kf.zero();
    for i in 0..=d {
        // denominator prod_{j != i} (i - j), a signed integer
        let mut den: i64 = 1;
        for j in 0..=d {
            if j != i {
                den *= i as i64 - j as i64;
            }
        }
        let mut num = kf.one();
        for j in 0..=d {
            if j != i {
                num = kf.mul(&num, &kf.sub(r, &kf.embed(j as u64)));
            }
        }
        let coeff = zq.inv(zq.to_mod(den));
        acc = kf.add(&acc, &kf.mul(&kf.scale(coeff, &num), &evals[i]));
    }
    acc
}

// ---------------------------------------------------------------------------
// The sumcheck proper.

pub struct SumcheckProof {
    /// Per round: the polynomial's evaluations at 0..degree.
    pub rounds: Vec<Vec<KElem>>,
    /// The factor tables' values at the final point (variable order =
    /// fold order). The CALLER decides how these are checked: against
    /// direct MLE claims (E4), the next GKR layer, or public data.
    pub final_evals: Vec<KElem>,
}

/// Prove sum_{b in {0,1}^n} combine(T_1(b), .., T_m(b)) = claimed.
/// Consumes the tables (they are folded in place). Returns the proof
/// and the final point.
pub fn sumcheck_prove(
    kf: &KField,
    mut tables: Vec<Vec<KElem>>,
    degree: usize,
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    let n = tables[0].len().trailing_zeros() as usize;
    assert!(tables.iter().all(|t| t.len() == 1 << n));
    let mut rounds = Vec::with_capacity(n);
    let mut point = Vec::with_capacity(n);
    for _ in 0..n {
        let g = round_poly(kf, &tables, degree, combine);
        tr.absorb_k(kf, "round-poly", &g);
        let r = tr.challenge_k(kf);
        tables = tables.iter().map(|t| fold(kf, t, &r)).collect();
        rounds.push(g);
        point.push(r);
    }
    let final_evals: Vec<KElem> = tables.into_iter().map(|mut t| t.remove(0)).collect();
    (SumcheckProof { rounds, final_evals }, point)
}

/// Verify the round chain against a claimed sum. Returns the final
/// point and the reduced claim C; the CALLER must still check C ==
/// combine(final claims) through whatever mechanism grounds the final
/// evaluations (this function checks it against proof.final_evals; the
/// final_evals themselves must be grounded separately — E4 or the next
/// GKR layer). None = reject.
pub fn sumcheck_verify(
    kf: &KField,
    n: usize,
    degree: usize,
    claimed: &KElem,
    proof: &SumcheckProof,
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
    tr: &mut LkpTranscript,
) -> Option<(Vec<KElem>, KElem)> {
    if proof.rounds.len() != n {
        return None;
    }
    let mut c = claimed.clone();
    let mut point = Vec::with_capacity(n);
    for g in &proof.rounds {
        if g.len() != degree + 1 {
            return None;
        }
        if kf.add(&g[0], &g[1]) != c {
            return None;
        }
        tr.absorb_k(kf, "round-poly", g);
        let r = tr.challenge_k(kf);
        c = lagrange_eval(kf, g, &r);
        point.push(r);
    }
    if combine(kf, &proof.final_evals) != c {
        return None;
    }
    Some((point, c))
}
