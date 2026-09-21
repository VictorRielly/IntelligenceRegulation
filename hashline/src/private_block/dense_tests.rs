//! **STAGE 19: DENSE public weights, and a numerically non-trivial witness at
//! the shaped geometries.** TEST CODE ONLY — nothing here is reachable from
//! the library or the binary, and no production path was changed to add it.
//!
//! **THE GAP THIS CLOSES.** Every PROOF this lane has ever made at a shape
//! with `f > d` — the rung, rung-G and 125M, all of them `f = 2d` or more —
//! used `grow_tests::tame_case`, whose matrices are DIAGONAL: `Wg` and `Wu`
//! are `diag(d, f)` and `Wd` is `diag(f, d)`, so the only nonzero entries sit
//! at `row == column`, which exists only for indices below `d`. Hidden unit
//! `j` with `d <= j < f` therefore has **zero input weight and zero output
//! weight** in every honest shaped proof, and the whole upper half of every
//! `Dom::F` plane — `g8`, `u16`, `a16`, `h16` and their limbs — is
//! identically zero. The geometry was exercised STRUCTURALLY (sizes, pads,
//! indicators, gates) and never NUMERICALLY. An indexing error confined to
//! hidden indices `>= d`, or to off-diagonal weights, would have been
//! invisible to everything that existed.
//!
//! What is here: a deterministic DENSE recipe (every public weight entry
//! nonzero) whose honest witness is admissible at the shaped geometries, the
//! non-triviality of that witness asserted from the witness itself, the proof
//! and the verification it supports, and the perturbation battery on the
//! upper hidden half.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A CORRECTNESS result for the
//! rung-G profile with dense public weights. It is NOT a privacy result and
//! NOT an acceptance of anything: the rung profiles are development grade
//! (ruling P-7) and no privacy tool has been run at this recipe.
//!
//! **THE CAPTURE RULE.** Everything generated here is PUBLIC SYNTHETIC test
//! data from a fixed-seed integer stream: no OS randomness, no real model, no
//! real input, nothing read from or written to disk. The COUNTS the
//! non-triviality tests print are functions of the (synthetic) hidden input,
//! so they go to the test's own stdout and nowhere else: the retained logs of
//! this stage are taken WITHOUT `--nocapture`, which is what keeps them out
//! of `results/`.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;

// ---------------------------------------------------------------- the recipe

/// **THE SEED.** One fixed lane constant; the whole recipe is this stream
/// read in a fixed order, so the same shape gives the same bytes forever.
pub(super) const DENSE_SEED: u64 = 0xD15E_ED19_0000_0001;

/// the attention band: every entry of `Wq`, `Wk`, `Wv`, `Wo` is drawn
/// uniformly from `[-56, -1] u [1, 56]`
const BAND_ATTN: i64 = 56;

/// the gate and up band: every entry of `Wg` and `Wu` is drawn uniformly from
/// `[-96, -1] u [1, 96]`
const BAND_GATE: i64 = 96;

/// the two norm gains are drawn uniformly from `[40, 127]` (positive, as a
/// trained RMSNorm gain in this calibration is)
const GAIN: (i64, i64) = (40, 127);

/// the hidden input is drawn uniformly from `[-6000, -1] u [1, 6000]`
const INPUT_MAG: i64 = 6_000;

/// **THE ONE SHAPE-DEPENDENT BAND: the down projection.** `Wd` accumulates
/// over the HIDDEN axis, and that axis grows from 192 at the rung to 2,048 at
/// 125M. `z16` is the one site with no headroom to spare — it is requantized
/// into `int16` and then ADDED to `xres1`, which is also `int16` — so its
/// band is scaled as `48 * sqrt(192 / f)`, which keeps the standard deviation
/// of `z16` the same at every shape: 48 at both rungs, 14 at 125M. Every
/// other band is shape-free, because the pipeline is already scale-invariant
/// in `d` (the norm divides by `sqrt(d)` and the matmul multiplies by it).
/// the down band of the PROVABLE recipe (`dense_ff_case`), shape-free
const BAND_DOWN_PROVABLE: i64 = 2;

fn band_down(s: &Shape) -> i64 {
    let rung_f = Shape::rung().hidden as u64;
    (witness::isqrt(48 * 48 * rung_f / s.hidden as u64) as i64).clamp(2, 127)
}

/// SplitMix64: a fixed, portable integer stream. No OS randomness anywhere.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    /// uniform in `[lo, hi]`
    fn pick(&mut self, lo: i64, hi: i64) -> i64 {
        lo + (self.next() % ((hi - lo + 1) as u64)) as i64
    }
    /// uniform on `[-mag, -1] u [1, mag]` — NEVER zero, which is what makes
    /// "dense" a literal statement about this recipe and not a hope
    fn nonzero(&mut self, mag: i64) -> i64 {
        let v = self.pick(1, 2 * mag);
        if v <= mag {
            -v
        } else {
            v - mag
        }
    }
}

/// **THE RECIPE, in the reference kernel's own word order**: the nine TRUE-
/// sized public words `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd]` and
/// the hidden input, at any shape. `Wq`/`Wo` are `(d, d)`, `Wk`/`Wv` are
/// `(kv_heads * head_dim, d)`, `Wg`/`Wu` are `(d, f)` and `Wd` is `(f, d)`,
/// all row-major, all with EVERY entry nonzero.
pub(super) fn dense_words(s: &Shape) -> ([Vec<i8>; 9], Vec<i16>) {
    dense_words_with(s, BAND_ATTN, BAND_GATE, band_down(s), GAIN, INPUT_MAG)
}

/// The same recipe with every band given explicitly — the form the stage's
/// bisection diagnostic drives, and the one place the numbers live.
fn dense_words_with(s: &Shape, attn: i64, gate: i64, down: i64, gains: (i64, i64), xmag: i64) -> ([Vec<i8>; 9], Vec<i16>) {
    let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
    let mut r = Rng(DENSE_SEED);
    let mat = |r: &mut Rng, outer: usize, inner: usize, mag: i64| -> Vec<i8> { (0..outer * inner).map(|_| r.nonzero(mag) as i8).collect() };
    let gain = |r: &mut Rng, n: usize| -> Vec<i8> { (0..n).map(|_| r.pick(gains.0, gains.1) as i8).collect() };
    let words = [
        mat(&mut r, d, d, attn),
        mat(&mut r, kvw, d, attn),
        mat(&mut r, kvw, d, attn),
        mat(&mut r, d, d, attn),
        gain(&mut r, d),
        gain(&mut r, d),
        mat(&mut r, d, f, gate),
        mat(&mut r, d, f, gate),
        mat(&mut r, f, d, down),
    ];
    let input: Vec<i16> = (0..s.tokens * d).map(|_| r.nonzero(xmag) as i16).collect();
    (words, input)
}

/// `tame_case`'s own nine words, in the same order — the diagonal fixture the
/// dense recipe replaces, needed by the bisection diagnostic so that a
/// half-dense statement can be built.
fn tame_words(s: &Shape) -> ([Vec<i8>; 9], Vec<i16>) {
    let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
    let diag = |outer: usize, inner: usize| -> Vec<i8> { (0..outer * inner).map(|k| if k / inner == k % inner { 64i8 } else { 0 }).collect() };
    let gamma = vec![64i8; d];
    let input: Vec<i16> = (0..s.tokens * d)
        .map(|k| {
            let base: i64 = if k % 2 == 0 { 24_000 } else { -24_000 };
            (base + ((k * 37 + 11) % 401) as i64 - 200) as i16
        })
        .collect();
    ([diag(d, d), diag(kvw, d), diag(kvw, d), diag(d, d), gamma.clone(), gamma, diag(d, f), diag(d, f), diag(f, d)], input)
}

/// the public statement of any nine words at a shape
fn statement_of_words(s: &Shape, w: &[Vec<i8>; 9]) -> (AttentionPublic, FeedForwardPublic) {
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member");
    let aw = super::grow_tests::pad_attention_weights(s, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let fw = super::grow_tests::pad_ff_weights(s, &w[5], &w[6], &w[7], &w[8]);
    let public = AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("the attention statement");
    let ff = FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("the feed-forward statement");
    (public, ff)
}

/// The same recipe as this module's public STATEMENT — the padded,
/// head-permuted matrices of ruling P-2 — with `tame_case`'s exact signature,
/// so that any harness built for the tame fixture takes it unchanged.
pub(super) fn dense_case(s: &Shape) -> (AttentionPublic, FeedForwardPublic, Vec<i16>) {
    let (w, input) = dense_words(s);
    let (public, ff) = statement_of_words(s, &w);
    (public, ff, input)
}

/// **THE PROVABLE HALF OF THE RECIPE (finding S19-F1).** The dense
/// FEED-FORWARD words — `gamma_m`, `Wg`, `Wu`, `Wd`, every entry nonzero —
/// on `tame_case`'s attention words and `tame_case`'s hidden input.
///
/// Why this exists. S19-F1 (below) is a production defect in the
/// grouped-query claim construction that rejects any honest proof whose
/// KEY-VALUE heads carry different activations; the fully dense recipe walks
/// straight into it, so nothing that PROVES could be delivered on it. The
/// feed-forward half of the block has no head axis at all — `Dom::F` is
/// `(t, j)` — so this variant leaves the attention side exactly in the regime
/// every earlier stage proved in, and makes the FEED-FORWARD numerically
/// non-trivial: the upper hidden half `[d, f)` of the gate, up, activation
/// and product planes, which the diagonal fixture leaves identically zero, is
/// live. It is the recipe every PROVING test of this stage uses.
///
/// **Its DOWN band is held at [`BAND_DOWN_PROVABLE`] rather than the
/// recipe's own `band_down`, for two reasons that are really one.** `z16` is
/// added to `xres1`, and `xres1` here is the fixture's own `|x| = 24,000`, so
/// a large `z16` leaves `int16` at 125M — measured, and refused by name:
/// `fixed oracle range refusal: residual 2`. And in a RUN, block `k+1`'s
/// hidden input IS `xres2`, so a large `z16` moves the norm quotient off its
/// bin and block `k+1`'s hidden state starts to VARY BETWEEN HEADS, which
/// finding S19-F1 then rejects. At band 2 the whole chain stays in the regime
/// every earlier stage proved in, and the gate, up, activation and product
/// planes are as dense on `[d, f)` as ever, because those come from `Wg` and
/// `Wu`.
pub(super) fn dense_ff_case(s: &Shape) -> (AttentionPublic, FeedForwardPublic, Vec<i16>) {
    let (dw, _) = dense_words_with(s, BAND_ATTN, BAND_GATE, BAND_DOWN_PROVABLE, GAIN, INPUT_MAG);
    let (tw, tx) = tame_words(s);
    let w: [Vec<i8>; 9] = [
        tw[0].clone(),
        tw[1].clone(),
        tw[2].clone(),
        tw[3].clone(),
        tw[4].clone(),
        dw[5].clone(),
        dw[6].clone(),
        dw[7].clone(),
        dw[8].clone(),
    ];
    let (public, ff) = statement_of_words(s, &w);
    (public, ff, tx)
}

// ------------------------------------------------------------ the recipe itself

/// **THE RECIPE IS DENSE AND DETERMINISTIC**, and the fixture it replaces is
/// neither dense nor able to reach the upper hidden half.
#[test]
fn the_dense_recipe_is_dense_deterministic_and_reaches_the_upper_hidden_half() {
    for s in [Shape::rung(), Shape::rung_g()] {
        let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
        let (w, input) = dense_words(&s);
        let (again, input2) = dense_words(&s);
        assert_eq!(w, again, "{}: the recipe is not deterministic", s.name);
        assert_eq!(input, input2, "{}: the input is not deterministic", s.name);
        let lens = [d * d, kvw * d, kvw * d, d * d, d, d, d * f, d * f, f * d];
        for (k, (m, want)) in w.iter().zip(lens).enumerate() {
            assert_eq!(m.len(), want, "{}: word {k} is the wrong length", s.name);
            assert!(m.iter().all(|v| *v != 0), "{}: word {k} has a ZERO entry, so the recipe is not dense", s.name);
        }
        assert!(w[4].iter().all(|g| (GAIN.0..=GAIN.1).contains(&(*g as i64))), "{}: gamma_a leaves its band", s.name);
        assert!(w[5].iter().all(|g| (GAIN.0..=GAIN.1).contains(&(*g as i64))), "{}: gamma_m leaves its band", s.name);
        // the hidden input is non-trivial: nonzero, not constant, both signs
        assert_eq!(input.len(), s.tokens * d);
        assert!(input.iter().all(|v| *v != 0), "{}: the hidden input has a zero", s.name);
        assert!(input.iter().any(|v| *v != input[0]), "{}: the hidden input is constant", s.name);
        assert!(input.iter().any(|v| *v > 0) && input.iter().any(|v| *v < 0), "{}: the hidden input is one-signed", s.name);
        // THE POINT: `Wg` and `Wu` reach hidden column `j` for every
        // `j in [d, f)`, and `Wd` reaches hidden ROW `j` for every one of
        // them — which the diagonal fixture does for none of them
        for (m, name) in [(&w[6], "Wg"), (&w[7], "Wu")] {
            for j in d..f {
                assert!((0..d).any(|i| m[i * f + j] != 0), "{}: {name} column {j} is empty", s.name);
            }
        }
        for j in d..f {
            assert!((0..d).any(|i| w[8][j * d + i] != 0), "{}: Wd row {j} is empty", s.name);
        }
        // and the fixture it replaces reaches none of them
        let (_, ff_tame, _) = super::grow_tests::tame_case(&s);
        let (dp, fp) = (s.d_pad, s.f_pad);
        let tame_upper = (0..dp).flat_map(|i| (d..f).map(move |j| (i, j))).filter(|(i, j)| ff_tame.wg_t[i * fp + j] != 0).count();
        assert_eq!(tame_upper, 0, "{}: the tame fixture's Wg is no longer empty on [{d}, {f}) — the premise of stage 19 has changed", s.name);
        eprintln!("{}: dense recipe bands attn {BAND_ATTN} / gate {BAND_GATE} / down {} / gain {GAIN:?} / input {INPUT_MAG}", s.name, band_down(&s));
    }
    // and the one shape-dependent band is what its rule says
    assert_eq!(band_down(&Shape::rung()), 48, "the rung's down band");
    assert_eq!(band_down(&Shape::rung_g()), 48, "the rung-G's down band");
    assert_eq!(band_down(&Shape::m125()), 14, "125M's down band");
}

// -------------------------------------------------- admissibility and non-triviality

/// The upper hidden half `[d, f)` of a `Dom::F` plane, and its padded tail.
fn upper_half_counts(s: &Shape, plane: &[i64]) -> (usize, usize, usize) {
    let (d, f, fp) = (s.width, s.hidden, s.f_pad);
    let mut nz = 0usize;
    let mut pad_nz = 0usize;
    for t in 0..s.tokens {
        for j in d..f {
            if plane[t * fp + j] != 0 {
                nz += 1;
            }
        }
        for j in f..fp {
            if plane[t * fp + j] != 0 {
                pad_nz += 1;
            }
        }
    }
    (nz, s.tokens * (f - d), pad_nz)
}

/// the largest absolute value a plane reaches on its own domain (a diagnostic
/// on the recipe's headroom, printed and never retained)
fn peak(plane: &[i64]) -> i64 {
    plane.iter().map(|v| v.abs()).max().unwrap_or(0)
}

/// **THE ACCEPTANCE OF ITEM 3.** The dense recipe's honest witness BUILDS at
/// the rung-G shape — every int8 / int16 class, both norm windows, the
/// softmax window, the exp-table domain and both residuals hold — and it is
/// numerically non-trivial exactly where the diagonal fixture is empty: a
/// large fraction of the gate, up, activation and product planes is nonzero
/// on the upper hidden half `[d, f)`, every live head slot has a nonzero
/// attention output, and the padded tail `[f, f_pad)` is still all zero.
#[test]
fn the_dense_witness_is_admissible_and_non_trivial_at_the_rung_g() {
    the_witness_is_admissible_and_non_trivial(&Shape::rung_g(), dense_case(&Shape::rung_g()));
}

/// The same for the PROVABLE recipe: `tame_case`'s attention words and input
/// with DENSE feed-forward words. The feed-forward non-triviality is the same
/// statement; the attention side is the fixture's, so only the live-head-slot
/// check is weaker there (it is the fixture's own attention).
#[test]
fn the_dense_feed_forward_witness_is_admissible_and_non_trivial_at_the_rung_g() {
    the_witness_is_admissible_and_non_trivial(&Shape::rung_g(), dense_ff_case(&Shape::rung_g()));
}

fn the_witness_is_admissible_and_non_trivial(s: &Shape, case: (AttentionPublic, FeedForwardPublic, Vec<i16>)) {
    let s = s.clone();
    let (d, f) = (s.width, s.hidden);
    let (public, ff, input) = case;
    let w = match witness::build_shaped(&s, &public, &ff, &input) {
        Ok(w) => w,
        // the builder's refusals are the guide the recipe was tuned against;
        // printing the site is the whole diagnostic
        Err(m) => panic!("the dense recipe is NOT admissible at {}: {m}", s.name),
    };
    let ids = Ids::new(&s).expect("the rung-G plane map");
    // the four planes the brief names, plus their limbs, on `[d, f)`
    for (toy, name, floor) in [(A_G8, "gate g8", 90u64), (A_U16, "up u16", 90), (A_A16, "activation a16", 40), (A_H16, "product h16", 40)] {
        let (nz, total, pad_nz) = upper_half_counts(&s, &w.planes[ids.at(toy)]);
        let pct = (100 * nz as u64) / total as u64;
        assert_eq!(pad_nz, 0, "{name}: the padded hidden tail [{f}, {}) is not zero", s.f_pad);
        assert!(pct >= floor, "{name}: only {pct}% of the upper hidden half [{d}, {f}) is nonzero, under the floor of {floor}%");
        eprintln!("{}: {name} on [{d}, {f}): {nz} of {total} nonzero ({pct}%), peak |v| {}", s.name, peak(&w.planes[ids.at(toy)]));
    }
    // EVERY LIVE HEAD SLOT has a nonzero attention output
    let (dp, dh) = (s.d_pad, s.head_dim);
    for h in 0..s.q_heads {
        let sl = s.head_slot(h);
        let any = (0..s.tokens).any(|t| (0..dh).any(|i| w.planes[ids.at(A_O8)][t * dp + sl * dh + i] != 0));
        assert!(any, "head {h} (slot {sl}) has an identically zero attention output");
    }
    // and every PADDED head slot is still zero, as the pad rule requires
    for sl in 0..s.h_pad {
        if s.slot_is_true_head(sl) {
            continue;
        }
        let any = (0..s.tokens).any(|t| (0..dh).any(|i| w.planes[ids.at(A_O8)][t * dp + sl * dh + i] != 0));
        assert!(!any, "padded head slot {sl} carries an attention output");
    }
    // the headroom of every class-checked site, as a diagnostic on how much
    // of this recipe's margin a bigger shape may spend
    for (toy, name, bound) in [
        (A_Y, "norm_a y", 127i64),
        (A_Q8, "q8", 127),
        (A_K8, "k8", 127),
        (A_V8, "v8", 127),
        (A_QR8, "qr8", 127),
        (A_KR8, "kr8", 127),
        (A_S8, "s8", 127),
        (A_O8, "o8", 127),
        (A_AO, "ao", 32767),
        (A_X1, "xres1", 32767),
        (A_YM, "norm_m y", 127),
        (A_G8, "g8", 128),
        (A_U16, "u16", 32767),
        (A_H16, "h16", 32767),
        (A_Z16, "z16", 32767),
        (A_X2, "xres2", 32767),
    ] {
        let p = peak(&w.planes[ids.at(toy)]);
        eprintln!("{}: headroom {name}: peak |v| {p} of {bound} ({}x)", s.name, if p == 0 { 0 } else { bound / p });
    }
}

/// The same recipe's PUBLIC STATEMENTS construct at the 125M shape — the
/// padded, head-permuted matrices pass every ruling P-2 support check at
/// `(512, 768, 2048)`. Weights only: no witness is built here, so this costs
/// a few megabytes and a moment.
#[test]
fn the_dense_public_statements_construct_at_125m() {
    let s = Shape::m125();
    let (public, ff, input) = dense_case(&s);
    assert_eq!(input.len(), s.tokens * s.width, "the 125M dense input length");
    assert_eq!(public.wq.len(), s.d_pad * s.d_pad, "the padded Wq");
    assert_eq!(ff.wg_t.len(), s.d_pad * s.f_pad, "the padded Wg");
    // the upper hidden half of the padded `Wg` is genuinely populated at 125M
    let (d, f, dp, fp) = (s.width, s.hidden, s.d_pad, s.f_pad);
    let nz = (0..d).flat_map(|i| (d..f).map(move |j| (i, j))).filter(|(i, j)| ff.wg_t[i * fp + j] != 0).count();
    assert_eq!(nz, d * (f - d), "125M: the padded Wg is not dense on the upper hidden half");
    let pad_nz = (0..dp).flat_map(|i| (f..fp).map(move |j| (i, j))).filter(|(i, j)| ff.wg_t[i * fp + j] != 0).count();
    assert_eq!(pad_nz, 0, "125M: the padded Wg is nonzero off the hidden support");
    eprintln!("125M: the dense statements construct; down band {}", band_down(&s));
}

/// **ITEM 7's ADMISSIBILITY CHECK at the 125M shape, WITNESS BUILDER ONLY.**
/// No proof. Both recipes: the fully dense one (which the heavy test takes
/// under `HL_PB_WEIGHTS=dense`, and which S19-F1 will reject at the proof
/// even though the witness is fine) and the provable dense feed-forward one
/// (`HL_PB_WEIGHTS=dense-ff`). It answers in seconds what a 125M proof would
/// answer in half an hour: whether the recipe's magnitudes survive the
/// eight-fold wider `d` and eleven-fold wider `f`.
///
/// It is measured and kept in the gate; each witness is dropped before the
/// next is built, so only one is ever resident.
#[test]
fn the_dense_recipes_are_admissible_and_non_trivial_at_125m() {
    let s = Shape::m125();
    let (d, f) = (s.width, s.hidden);
    let ids = Ids::new(&s).expect("the 125M plane map");
    for (label, case) in [("dense", dense_case(&s)), ("dense-ff", dense_ff_case(&s))] {
        let (public, ff, input) = case;
        let t0 = std::time::Instant::now();
        let w = match witness::build_shaped(&s, &public, &ff, &input) {
            Ok(w) => w,
            Err(m) => panic!("the {label} recipe is NOT admissible at 125M: {m}"),
        };
        println!("125M {label} witness built in {:.2} s", t0.elapsed().as_secs_f64());
        for (toy, name, floor) in [(A_G8, "gate g8", 90u64), (A_U16, "up u16", 90), (A_A16, "activation a16", 40), (A_H16, "product h16", 40)] {
            let (nz, total, pad_nz) = upper_half_counts(&s, &w.planes[ids.at(toy)]);
            let pct = (100 * nz as u64) / total as u64;
            assert_eq!(pad_nz, 0, "125M {label}: {name}: the padded hidden tail is not zero");
            assert!(pct >= floor, "125M {label}: {name}: only {pct}% of [{d}, {f}) is nonzero, under the floor of {floor}%");
            println!("125M {label}: {name} on [{d}, {f}): {nz} of {total} nonzero ({pct}%), peak |v| {}", peak(&w.planes[ids.at(toy)]));
        }
        // every class-checked site's remaining headroom at the wider shape
        for (toy, name, bound) in [(A_Q8, "q8", 127i64), (A_S8, "s8", 127), (A_G8, "g8", 128), (A_U16, "u16", 32767), (A_H16, "h16", 32767), (A_Z16, "z16", 32767), (A_X2, "xres2", 32767)] {
            println!("125M {label}: headroom {name}: peak |v| {} of {bound}", peak(&w.planes[ids.at(toy)]));
        }
    }
}

// ------------------------------------------------------------------ the proof

fn dense_context() -> Digest {
    *blake3::hash(b"private block: stage 19, the dense recipe at the shaped geometries").as_bytes()
}

/// the two caller-fixed endpoints of a dense witness, over the padded
/// `Dom::D` cube (the slice `SC_IO_IN` / `SC_IO_OUT` claim)
fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the shape has a plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
    let spec = IoSpec::new_shaped(sh, dense_context(), 0, 0).expect("the dense endpoint spec");
    prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2))).expect("the dense endpoint owners")
}

fn prove_dense(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// **FINDING S19-F1, THE HEADLINE OF THIS STAGE — AN HONEST PROOF IS
/// REJECTED BY THE VERIFIER.** This test FAILS. It is kept, `#[ignore]`d and
/// failing, because it is the shortest statement of the defect, and it is NOT
/// fixed here: the production source is final from this lane's side.
///
/// **The reproducer is the production fixture with ONE WORD of the hidden
/// input changed.** `grow_tests::tame_case`'s own diagonal weights, its own
/// input, and `input[0] = 0`. The witness builder accepts it, every relation
/// `pad::every_checkable_relation_holds` can evaluate holds, the reference
/// kernel agrees with it — and the honest receipt is REJECTED at
/// `slot 15 [04 Q zero-check (hosts 09Q, 11)]: sumcheck round 0:
/// s(0) + s(1) != claim`.
///
/// **Why no earlier test saw it.** With `tame_case`'s input the norm output
/// is exactly `+3` at even width indices and `-3` at odd ones, at every
/// token — so the hidden state is the SAME in every head, and every
/// key-value head carries the same keys and values. `input[0] = 0` moves one
/// word of head 0 and nothing else. See `stage19_bisect_the_head_axis` for
/// which axis of variation does it.
#[test]
#[ignore = "FAILS: finding S19-F1, a production defect in argument.rs's grouped-query claim construction. Not fixed here: the production source is final from this lane's side."]
fn s19_f1_an_honest_proof_of_the_fixture_with_one_input_word_moved_is_rejected() {
    let sh = Shape::rung_g();
    let (public, ff, mut input) = super::grow_tests::tame_case(&sh);
    input[0] = 0;
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the witness builder accepts the moved fixture input");
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the witness itself is inconsistent, so this is not S19-F1");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_dense(&sh, &blk, w).expect("the honest prover");
    assert_eq!(bytes.len(), 4_234_648, "the frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("S19-F1: an HONEST receipt is rejected in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("S19-F1: an HONEST receipt is rejected from bytes");
}

/// **THE ACCEPTANCE OF ITEM 5, one block, on the PROVABLE recipe.** The dense
/// FEED-FORWARD recipe's honest proof verifies FROM BYTES at the rung-G
/// profile, and its frame is the SAME counted length as the tame fixture's —
/// 4,234,648 B — because a receipt's length is a function of the shape and of
/// nothing else. A one-byte truncation is still refused.
#[test]
fn an_honest_dense_feed_forward_block_proves_and_verifies_from_bytes_at_the_rung_g() {
    let sh = Shape::rung_g();
    let (public, ff, input) = dense_ff_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense feed-forward honest witness");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_dense(&sh, &blk, w).expect("the dense feed-forward prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), 4_234_648, "the dense feed-forward rung-G frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the receipt verifies from bytes");
    eprintln!("{} DENSE-FF one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", sh.name, t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short frame was accepted");
}

/// The FULLY dense recipe's one-block proof. **This test FAILS on finding
/// S19-F1** — the dense attention weights make the key-value heads carry
/// different activations, which is exactly what the defect rejects. Kept
/// `#[ignore]`d and failing beside the reproducer above.
#[test]
#[ignore = "FAILS: finding S19-F1 (the same defect as s19_f1_...). Not fixed here."]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_g() {
    let sh = Shape::rung_g();
    let (public, ff, input) = dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_dense(&sh, &blk, w).expect("the dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), 4_234_648, "the dense rung-G frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the dense receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the dense receipt verifies from bytes");
    eprintln!("{} DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", sh.name, t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short dense frame was accepted");
}

/// **THE BISECTION DIAGNOSTIC (`#[ignore]`d).** The honest dense proof was
/// rejected by the verifier the first time it was run; this is the harness
/// that says WHICH knob of the recipe does it. Each variant is built, the
/// witness's own checkable relations are evaluated, and the proof is made and
/// verified in typed form, with the outcome printed. It is kept because the
/// next person to widen the recipe will want it.
#[test]
#[ignore = "a diagnostic, not a gate: it proves eight rung-G blocks"]
fn stage19_bisect_the_dense_failure() {
    let s = Shape::rung_g();
    let (dw, dx) = dense_words(&s);
    let (tw, tx) = tame_words(&s);
    let mix = |a: &[Vec<i8>; 9], b: &[Vec<i8>; 9], from_b: &[usize]| -> [Vec<i8>; 9] {
        let mut out = a.clone();
        for k in from_b {
            out[*k] = b[*k].clone();
        }
        out
    };
    let mut cases: Vec<(String, [Vec<i8>; 9], Vec<i16>)> = vec![
        ("00 all tame, tame input (the control)".into(), tw.clone(), tx.clone()),
        ("01 all dense, dense input".into(), dw.clone(), dx.clone()),
        ("02 dense attention, tame feed-forward, dense input".into(), mix(&dw, &tw, &[5, 6, 7, 8]), dx.clone()),
        ("03 tame attention, dense feed-forward, dense input".into(), mix(&dw, &tw, &[0, 1, 2, 3, 4]), dx.clone()),
        ("04 all dense but both gains tame (64), dense input".into(), mix(&dw, &tw, &[4, 5]), dx.clone()),
        ("05 all dense, TAME input".into(), dw.clone(), tx.clone()),
        ("06 all tame, DENSE input".into(), tw.clone(), dx.clone()),
    ];
    for band in [1i64, 8, 24] {
        let (w, x) = dense_words_with(&s, band, BAND_GATE, band_down(&s), GAIN, INPUT_MAG);
        cases.push((format!("07 dense with attention band {band}"), w, x));
    }
    let ids = Ids::new(&s).expect("the rung-G plane map");
    for (name, w, input) in cases {
        let (public, ff) = statement_of_words(&s, &w);
        let wit = match witness::build_shaped(&s, &public, &ff, &input) {
            Ok(w) => w,
            Err(m) => {
                eprintln!("BISECT {name}: the WITNESS BUILDER refused: {m}");
                continue;
            }
        };
        let checkable = super::pad::every_checkable_relation_holds(&s, &ids, &wit);
        let blk = BlockPublic::new(public, ff);
        let verdict = match prove_dense(&s, &blk, wit) {
            Err(e) => format!("the PROVER refused: {e}"),
            Ok((expected, receipt, bytes)) => match verify_inner_at(&s, &blk, &expected, &receipt) {
                Err(e) => format!("the VERIFIER rejected (typed): {e}"),
                Ok(_) => match verify_bytes_at(&s, &blk, &expected, &bytes) {
                    Err(e) => format!("the VERIFIER rejected (from bytes): {e}"),
                    Ok(()) => "VERIFIED".to_string(),
                },
            },
        };
        eprintln!("BISECT {name}: checkable relations {}, {verdict}", if checkable { "HOLD" } else { "FAIL" });
    }
}

/// **THE SECOND BISECTION (`#[ignore]`d): the HIDDEN INPUT alone.** The first
/// bisection found that the DIAGONAL production fixture also fails once the
/// hidden input changes, so the recipe is not what matters. This one holds the
/// public weights at `tame_case`'s diagonal matrices and moves only the input,
/// and it prints the structural degeneracies of each witness beside the
/// verdict: how many distinct values `norm_a`'s output takes, whether the Q
/// requantization remainder is constant, and whether the two RoPE partner
/// halves agree everywhere (which they do at the fixture, and which would hide
/// any confusion between a position and its partner).
#[test]
#[ignore = "a diagnostic, not a gate: it proves eight rung-G blocks"]
fn stage19_bisect_the_hidden_input() {
    let s = Shape::rung_g();
    let (tw, tx) = tame_words(&s);
    let (public, ff) = statement_of_words(&s, &tw);
    let (n, d) = (s.tokens * s.width, s.width);
    let by = |f: &dyn Fn(usize) -> i64| -> Vec<i16> { (0..n).map(|k| (24_000 * f(k % d)) as i16).collect() };
    let mut r = Rng(0xABCD_1234_5678_9001);
    let seeded: Vec<i16> = (0..n).map(|_| if r.next() & 1 == 0 { 24_000i16 } else { -24_000 }).collect();
    let cases: Vec<(String, Vec<i16>)> = vec![
        ("H the tame fixture input, unchanged (the control)".into(), tx.clone()),
        ("A |x| constant, signs alternating by i parity (the fixture's pattern, no ramp)".into(), by(&|i| if i % 2 == 0 { 1 } else { -1 })),
        ("B |x| constant, signs from a seeded stream".into(), seeded),
        ("C |x| constant, every sign +".into(), by(&|_| 1)),
        ("D |x| constant, sign blocks of head_dim (RoPE partner halves AGREE)".into(), by(&|i| if (i / 16) % 2 == 0 { 1 } else { -1 })),
        ("E |x| constant, sign blocks of half a head (RoPE partner halves DISAGREE)".into(), by(&|i| if (i / 8) % 2 == 0 { 1 } else { -1 })),
        ("F the fixture input with x[0] set to 0".into(), {
            let mut v = tx.clone();
            v[0] = 0;
            v
        }),
        ("G the fixture input with x[0] + 1".into(), {
            let mut v = tx.clone();
            v[0] += 1;
            v
        }),
    ];
    let ids = Ids::new(&s).expect("the rung-G plane map");
    let (dp, dh, half) = (s.d_pad, s.head_dim, s.head_dim / 2);
    for (name, input) in cases {
        let w = match witness::build_shaped(&s, &public, &ff, &input) {
            Ok(w) => w,
            Err(m) => {
                eprintln!("INPUT {name}: the WITNESS BUILDER refused: {m}");
                continue;
            }
        };
        // the three degeneracies, measured on the true support
        let sup_d = super::witness::Geom::new(&s).support(Dom::D);
        let mut ys: Vec<i64> = sup_d.iter().map(|i| w.planes[ids.at(A_Y)][*i]).collect();
        ys.sort_unstable();
        ys.dedup();
        let sup_q = super::witness::Geom::new(&s).support(Dom::Q);
        let mut rq: Vec<i64> = sup_q.iter().map(|i| w.planes[ids.at(A_RQL)][*i]).collect();
        rq.sort_unstable();
        rq.dedup();
        let partners_agree = (0..s.tokens).all(|t| {
            (0..s.h_pad).filter(|sl| s.slot_is_true_head(*sl)).all(|sl| (0..half).all(|i| w.planes[ids.at(A_Q8)][t * dp + sl * dh + i] == w.planes[ids.at(A_Q8)][t * dp + sl * dh + i + half]))
        });
        let blk = BlockPublic::new(public.clone(), ff.clone());
        let verdict = match prove_dense(&s, &blk, w) {
            Err(e) => format!("the PROVER refused: {e}"),
            Ok((expected, receipt, bytes)) => match verify_inner_at(&s, &blk, &expected, &receipt) {
                Err(e) => format!("the VERIFIER rejected: {e}"),
                Ok(_) => match verify_bytes_at(&s, &blk, &expected, &bytes) {
                    Err(e) => format!("the VERIFIER rejected (from bytes): {e}"),
                    Ok(()) => "VERIFIED".to_string(),
                },
            },
        };
        eprintln!("INPUT {name}: norm_a takes {} distinct values, A_RQL takes {} ({rq:?}), RoPE partner halves {}; {verdict}", ys.len(), rq.len(), if partners_agree { "AGREE everywhere" } else { "differ" });
    }
}

/// **THE THIRD BISECTION (`#[ignore]`d): WHICH AXIS OF VARIATION BREAKS IT.**
///
/// The second bisection found that the verdict tracks whether the hidden
/// state VARIES BETWEEN HEADS, not the weights recipe. Two slots read the
/// head axis in two different ways — `SC_SCORE` and `SC_PV` take the QUERY
/// head from the whole of `r_h` and the KEY-VALUE head from its top
/// `log2(kv_heads)` bits (trap T-3) — so this drives the two sides apart
/// independently, with diagonal weights scaled PER HEAD and PER KEY-VALUE
/// HEAD, on the fixture's own input.
#[test]
#[ignore = "a diagnostic, not a gate: it proves four rung-G blocks"]
fn stage19_bisect_the_head_axis() {
    let s = Shape::rung_g();
    let (d, kvw, dh, group) = (s.width, s.kv_heads * s.head_dim, s.head_dim, s.q_heads / s.kv_heads);
    let (_, tx) = tame_words(&s);
    // `Wq` / `Wo` diagonal with a scale that depends on the LOGICAL QUERY
    // HEAD, `Wk` / `Wv` diagonal with a scale that depends on the KEY-VALUE
    // HEAD: the two sides of the grouped-query map, moved one at a time
    let wq_of = |a: &[i64; 6]| -> Vec<i8> { (0..d * d).map(|k| if k / d == k % d { a[(k / d) / dh] as i8 } else { 0 }).collect() };
    let wkv_of = |b: &[i64; 2]| -> Vec<i8> { (0..kvw * d).map(|k| if k / d == k % d { b[(k / d) / dh] as i8 } else { 0 }).collect() };
    let flat_q = [64i64; 6];
    let flat_kv = [64i64; 2];
    let per_head = [64i64, 40, 24, 64, 40, 24];
    let per_group = [64i64, 64, 64, 40, 40, 40];
    let per_kv = [64i64, 40];
    let cases: [(&str, [i64; 6], [i64; 2]); 5] = [
        ("i   query heads FLAT, key-value heads FLAT (the fixture's regime)", flat_q, flat_kv),
        ("ii  query heads VARY WITHIN a group, key-value heads FLAT", per_head, flat_kv),
        ("iii query heads FLAT, key-value heads VARY (the review's distinct-KV regime)", flat_q, per_kv),
        ("iv  query heads vary ONLY BETWEEN groups, key-value heads VARY", per_group, per_kv),
        ("v   query heads VARY WITHIN a group, key-value heads VARY", per_head, per_kv),
    ];
    assert_eq!(group, 3, "the rung-G group is 3");
    for (name, a, b) in cases {
        let gamma = vec![64i8; d];
        let words: [Vec<i8>; 9] = [
            wq_of(&a),
            wkv_of(&b),
            wkv_of(&b),
            wq_of(&a),
            gamma.clone(),
            gamma.clone(),
            (0..d * s.hidden).map(|k| if k / s.hidden == k % s.hidden { 64i8 } else { 0 }).collect(),
            (0..d * s.hidden).map(|k| if k / s.hidden == k % s.hidden { 64i8 } else { 0 }).collect(),
            (0..s.hidden * d).map(|k| if k / d == k % d { 64i8 } else { 0 }).collect(),
        ];
        let (public, ff) = statement_of_words(&s, &words);
        let w = match witness::build_shaped(&s, &public, &ff, &tx) {
            Ok(w) => w,
            Err(m) => {
                eprintln!("HEAD {name}: the WITNESS BUILDER refused: {m}");
                continue;
            }
        };
        let blk = BlockPublic::new(public, ff);
        let verdict = match prove_dense(&s, &blk, w) {
            Err(e) => format!("the PROVER refused: {e}"),
            Ok((expected, receipt, _)) => match verify_inner_at(&s, &blk, &expected, &receipt) {
                Err(e) => format!("the VERIFIER rejected: {e}"),
                Ok(_) => "VERIFIED".to_string(),
            },
        };
        eprintln!("HEAD {name}: {verdict}");
    }
    // and the review's own distinct-key-value fixture, at BOTH rung profiles,
    // beside the same construction with a different pair of scales: the
    // review's attack-3 test asserts that this case proves honestly at
    // `Shape::rung()`, so whatever separates it from case (iii) is the fact
    // to name
    for sh in [Shape::rung(), Shape::rung_g()] {
        let (blk, input) = super::review_tests::distinct_kv_case(&sh);
        let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the distinct-KV honest witness");
        let o = outcome(&sh, &blk, w);
        eprintln!("HEAD review distinct_kv_case at {}: {}", sh.name, o.short());
    }
}

// ------------------------------------------------------- the negative controls

/// **THE CONTROLS THAT MAKE ITEM 3 MEAN SOMETHING (item 6).** With the tame
/// fixture every `Dom::F` plane is ZERO above `d`, so a perturbation there is
/// caught by the pad-zero / support machinery and says nothing about the
/// relations. With the dense recipe those positions carry real values, and
/// each one must be held by the relation that computes it. One perturbation
/// per committed `Dom::F` plane — the gate, its remainder, the activation
/// output, the up product, its limbs, the product, its limbs and remainder —
/// at a TRUE position with hidden index in `[d, f)`, and every one must be
/// refused by the prover or rejected by the verifier.
///
/// The harness is `review_tests`' own (attack 9's), unchanged. It runs on the
/// PROVABLE recipe (`dense_ff_case`), because on the fully dense one the
/// honest control is itself rejected by S19-F1 and the battery would say
/// nothing. The feed-forward slots read no head axis, so S19-F1 does not
/// reach them.
#[test]
fn every_upper_hidden_half_perturbation_of_the_dense_witness_is_rejected_at_the_rung_g() {
    let sh = Shape::rung_g();
    let (public, ff, input) = dense_ff_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    // the position: token 1 (whose row starts at `f_pad`), hidden index
    // `d + 7`, which is in the upper half
    let at = sh.f_pad + sh.width + 7;
    assert!(sh.width + 7 < sh.hidden, "the chosen hidden index is not in [d, f)");
    // the honest witness must be ACCEPTED under this harness, or the
    // rejections below say nothing
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest dense witness was not accepted, so the controls say nothing");
    let mut accepted: Vec<String> = Vec::new();
    let mut prover: usize = 0;
    let mut verifier: usize = 0;
    for toy in A_G8..=A_RH1 {
        let p = ids.at(toy);
        if ids.is_multiplicity(p) {
            continue;
        }
        assert_eq!(ids.dom(p), Dom::F, "plane {toy} is not a Dom::F plane");
        let mut w = clone_witness(&base);
        w.planes[p][at] += 1;
        let o = outcome(&sh, &blk, w);
        let label = format!("Dom::F plane {p} (toy id {toy}) at token 1, hidden index {}", sh.width + 7);
        eprintln!("UPPER HALF {label}: {}", o.short());
        match o {
            Outcome::Accepted => accepted.push(label),
            Outcome::ProverRefused(_) => prover += 1,
            Outcome::VerifierRejected(_) => verifier += 1,
        }
    }
    eprintln!("UPPER-HALF SWEEP at the rung-G shape: {} refused by the prover, {verifier} rejected by the verifier, {} accepted", prover, accepted.len());
    assert!(accepted.is_empty(), "an upper-hidden-half perturbation was ACCEPTED on: {accepted:#?}");
    assert_eq!(prover + verifier, (A_RH1 - A_G8) + 1, "not every Dom::F plane was exercised");
}

/// **THE GROUPED-QUERY CONTROL (item 6).** With dense `Wk` / `Wv` the key and
/// value planes of key-value head 1 — the head that query heads 3, 4 and 5
/// share — are genuinely populated, so a perturbation there is a statement
/// about the group structure and not about a zero. Three cases: an
/// OFF-DIAGONAL score entry of a query head in the shared group, and one
/// entry each of the shared head's rotated key and value planes.
///
/// **CONFOUNDED BY S19-F1 and therefore `#[ignore]`d.** Every one of these
/// three perturbations makes the key-value heads carry different activations,
/// which is precisely the condition under which S19-F1 rejects an HONEST
/// proof — so a rejection here would not distinguish the tamper from the
/// defect, and the honest control the test opens with is itself rejected.
/// It becomes a real control the day S19-F1 is fixed.
#[test]
#[ignore = "blocked by finding S19-F1: the honest control is rejected, so a rejection of the tamper says nothing"]
fn a_shared_kv_head_perturbation_of_the_dense_witness_is_rejected_at_the_rung_g() {
    let sh = Shape::rung_g();
    let group = sh.q_heads / sh.kv_heads;
    assert_eq!(group, 3, "the rung-G group is 3");
    let (public, ff, input) = dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    let (tp, dh, kvw) = (sh.t_pad, sh.head_dim, sh.kv_heads * sh.head_dim);
    // query head 4 reads key-value head 1, which heads 3, 4 and 5 share
    let h = 4usize;
    let kv = h / group;
    assert_eq!(kv, 1, "query head 4 must read the shared key-value head 1");
    let slot = sh.head_slot(h);
    // an OFF-DIAGONAL, causally live score entry: row t = 5, column j = 2
    let s_at = (slot * tp + 5) * tp + 2;
    let cases: [(&str, usize, usize); 3] = [
        ("an off-diagonal score of a query head in the shared group", ids.at(A_S8), s_at),
        ("the rotated key of the shared key-value head", ids.at(A_KR8), 3 * kvw + kv * dh + 9),
        ("the value of the shared key-value head", ids.at(A_V8), 7 * kvw + kv * dh + 2),
    ];
    // the base must be accepted, or nothing below is a statement
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest dense witness was not accepted");
    for (what, plane, at) in cases {
        let mut w = clone_witness(&base);
        assert_ne!(w.planes[plane][at], 0, "{what}: the position perturbed is already zero, so the case says nothing");
        w.planes[plane][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("SHARED KV {what}: {}", o.short());
        assert!(!o.is_accepted(), "{what} was ACCEPTED");
    }
}
