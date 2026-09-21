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
// stage 20's independent identity check works in the field directly
use crate::field::{Fp, Fp2};

// ---------------------------------------------------------------- the recipe

/// **THE SEED OF THE PUBLIC WEIGHTS.** One fixed lane constant; the nine
/// PUBLIC words are this stream read in a fixed order, so the same shape
/// gives the same weights forever.
///
/// **STAGE 22: this stream carries the PUBLIC WEIGHTS AND NOTHING ELSE.**
/// Until stage 22 the synthetic HIDDEN INPUT was the tenth read of this same
/// stream, and the recipe's published description said so — so the seed a
/// run statement publishes regenerated the hidden input as well as the
/// weights. Harmless for a synthetic test, wrong as the model for a
/// production statement writer, in which the weights are public and the
/// input is the secret. The input now comes from [`DENSE_INPUT_SEED`], and
/// `the_dense_recipes_public_stream_is_consumed_entirely_by_public_words`
/// asserts that this stream is exhausted by the nine words.
pub(super) const DENSE_SEED: u64 = 0xD15E_ED19_0000_0001;

/// **STAGE 22: THE HIDDEN INPUT'S OWN SEED, WHICH IS NEVER PUBLISHED.**
///
/// It appears in this test source (which is what a test's synthetic secret
/// is) and in NO retained file: not in a run statement, not in a capture
/// bundle, not in a log. The two streams are independent, so a reader who
/// has the public recipe — the seed, the distributions, the read order and
/// the bands — can regenerate every public weight and learns nothing
/// whatever about the input.
pub(super) const DENSE_INPUT_SEED: u64 = 0x1DDE_4E17_0000_0001;

/// the attention band: every entry of `Wq`, `Wk`, `Wv`, `Wo` is drawn
/// uniformly from `[-56, -1] u [1, 56]`
pub(super) const BAND_ATTN: i64 = 56;

/// the gate and up band: every entry of `Wg` and `Wu` is drawn uniformly from
/// `[-96, -1] u [1, 96]`
pub(super) const BAND_GATE: i64 = 96;

/// the two norm gains are drawn uniformly from `[40, 127]` (positive, as a
/// trained RMSNorm gain in this calibration is)
pub(super) const GAIN: (i64, i64) = (40, 127);

/// the hidden input is drawn uniformly from `[-6000, -1] u [1, 6000]`
pub(super) const INPUT_MAG: i64 = 6_000;

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

pub(super) fn band_down(s: &Shape) -> i64 {
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
///
/// **STAGE 22: two independent streams.** The nine PUBLIC words come from
/// [`dense_public_words_with`] and the hidden input from
/// [`dense_hidden_input`]; nothing about the input can be reached from the
/// public seed any more.
pub(super) fn dense_words_with(s: &Shape, attn: i64, gate: i64, down: i64, gains: (i64, i64), xmag: i64) -> ([Vec<i8>; 9], Vec<i16>) {
    let (words, _) = dense_public_words_with(s, attn, gate, down, gains);
    (words, dense_hidden_input(s, xmag))
}

/// **THE PUBLIC HALF OF THE RECIPE, and the whole of what a run statement's
/// recipe string describes (stage 22).** The nine TRUE-sized public words,
/// drawn in the fixed order `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd]`
/// from [`DENSE_SEED`], and the stream's state AFTERWARDS so that a test can
/// assert the stream is CONSUMED ENTIRELY by those nine words — which is the
/// structural form of "this seed regenerates the public weights and nothing
/// else".
pub(super) fn dense_public_words_with(s: &Shape, attn: i64, gate: i64, down: i64, gains: (i64, i64)) -> ([Vec<i8>; 9], u64) {
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
    (words, r.0)
}

/// **THE HIDDEN INPUT, FROM ITS OWN STREAM (stage 22).** One draw per word,
/// uniform on `[-xmag, -1] u [1, xmag]`, from [`DENSE_INPUT_SEED`]. It is
/// the test's synthetic SECRET: no retained file names this seed, this
/// function or this distribution.
pub(super) fn dense_hidden_input(s: &Shape, xmag: i64) -> Vec<i16> {
    let mut r = Rng(DENSE_INPUT_SEED);
    (0..s.tokens * s.width).map(|_| r.nonzero(xmag) as i16).collect()
}

/// How many draws the nine public words take from [`DENSE_SEED`] — one per
/// entry, because `nonzero` and `pick` each call `next` exactly once.
pub(super) fn dense_public_word_draws(s: &Shape) -> u64 {
    let (d, f, kvw) = (s.width as u64, s.hidden as u64, (s.kv_heads * s.head_dim) as u64);
    d * d + kvw * d + kvw * d + d * d + d + d + d * f + d * f + f * d
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
pub(super) fn statement_of_words(s: &Shape, w: &[Vec<i8>; 9]) -> (AttentionPublic, FeedForwardPublic) {
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

/// **STAGE 21: THE FULLY DENSE *RUN* RECIPE — the same nine words, at the
/// one band a CHAIN can carry.**
///
/// A run needs a smaller down-projection band than a single block, and the
/// reason is arithmetic, not a choice: block `k+1`'s hidden input IS block
/// `k`'s `xres2 = xres1 + z16`, so `z16`'s spread COMPOUNDS along the chain
/// and the residual eventually leaves `int16` — the witness builder refuses
/// it by name, `fixed oracle range refusal: residual 2`. Everything else
/// about the recipe is untouched: the same seed, the same read order, the
/// same attention / gate / gain / input bands, so every entry of all nine
/// words is still nonzero and the two key-value groups still carry different
/// data, which is what finding S19-F1 was about.
///
/// **These bands are MEASURED, not chosen**, by the witness-builder search
/// `run_tests::first_admissible_dense_run_band`, which walks DOWN from the
/// recipe's own `band_down` and takes the first band at which the builder
/// accepts every block of the chain. They are pinned here so that the recipe
/// stays a deterministic function of the shape alone and a fresh verifier
/// can regenerate the public weights from its name; the search is re-run as
/// a test at the rungs and as an `#[ignore]`d probe at 125M.
///
/// | shape | `band_down` (one block) | `band_down_run` (a chain) | chain length measured |
/// |---|---:|---:|---:|
/// | `rung`, `rung_g` | 48 | **47** | 3 |
/// | `m125` | 14 | **1** | 12 |
///
/// **125M needs band 1, and the search says so with no room to spare**
/// (`results/zk60_block125m_lane/u4-s21-m125-band.log`, 707 s, twelve
/// witnesses at the accepted band and two at each of the thirteen refused
/// ones): every band from the recipe's own 14 down to 2 is refused, always
/// at the same site, `fixed oracle range refusal: residual 2`, and always by
/// the SECOND block of the chain. At band 1 every entry of `Wd` is `+1` or
/// `-1` — still nonzero, so the recipe is still literally dense — and
/// `z16`'s spread is finally small enough that `xres2 = xres1 + z16` stays
/// inside `int16` for twelve compositions. The hidden axis is 2,048 wide at
/// 125M against 192 at the rung, so `z16` accumulates over ten times as many
/// terms; band 1 is what that costs, and it is a property of THIS
/// calibration's `int16` residual, not of the argument.
/// **STAGE 22: the key is `(hidden, kv_heads)` and no longer `hidden`
/// alone.** `Shape::rung_k4` has the rungs' hidden axis and a different head
/// axis, so it needs its own MEASURED band
/// (`k4_tests::the_pinned_rung_k4_chain_band_is_the_first_admissible_one`);
/// the two rungs' 47 and 125M's 1 are the stage-21 values, unchanged.
pub(super) fn band_down_run(s: &Shape) -> i64 {
    match (s.hidden, s.kv_heads) {
        (192, 2) => 47,
        (192, 4) => 47,
        (2048, 4) => 1,
        // any other geometry has not been measured; fall back to the
        // single-block band, which is the recipe's own and is honest about
        // saying nothing new
        _ => band_down(s),
    }
}

/// The fully dense recipe at the chain band: a run's nine public words and
/// its hidden input, everything else exactly [`dense_words`].
pub(super) fn dense_run_words(s: &Shape) -> ([Vec<i8>; 9], Vec<i16>) {
    dense_words_with(s, BAND_ATTN, BAND_GATE, band_down_run(s), GAIN, INPUT_MAG)
}

/// The same as this module's public STATEMENT, with `tame_case`'s signature.
pub(super) fn dense_run_case(s: &Shape) -> (AttentionPublic, FeedForwardPublic, Vec<i16>) {
    let (w, input) = dense_run_words(s);
    let (public, ff) = statement_of_words(s, &w);
    (public, ff, input)
}

/// **THE PUBLIC NAME of the fully dense run recipe**, written into a run
/// statement file so a fresh verifier regenerates exactly these PUBLIC
/// WEIGHTS. Every number a reader needs to reproduce that stream is in the
/// string, and NOTHING ELSE IS.
///
/// **STAGE 22.** Until stage 22 this string also ended the read order with
/// `x` and gave the hidden input's distribution, and the input really was
/// the tenth read of the same seeded stream — so the published seed
/// regenerated the hidden input. The stream is now exhausted by the nine
/// public words (asserted structurally by
/// `the_dense_recipes_public_stream_is_consumed_entirely_by_public_words`)
/// and the input has its own unpublished seed, so this string regenerates
/// the public weights and nothing else. **The PUBLIC WEIGHTS DID NOT MOVE
/// BY A BYTE**: the input was always drawn LAST, so removing it from the
/// stream leaves every weight draw where it was. The stage-21 string is kept
/// as a READ-ONLY alias ([`LEGACY_DENSE_RUN_RECIPE_NAME`]) so the statements
/// retained before stage 22 still regenerate their blocks.
pub(super) const DENSE_RUN_RECIPE_NAME: &str =
    "private_block::dense_tests::dense_run_case(<block profile's Shape>)'s NINE PUBLIC WORDS, the same fully dense public words for every block: SplitMix64 seeded 0xD15EED1900000001, read in the fixed order [Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd] and CONSUMED ENTIRELY by them; Wq/Wk/Wv/Wo uniform on [-56,-1] u [1,56]; gamma_a/gamma_m uniform on [40,127]; Wg/Wu uniform on [-96,-1] u [1,96]; Wd uniform on [-B,-1] u [1,B] with B = band_down_run(shape) (47 at the rungs, 1 at 125M). PUBLIC WEIGHTS ONLY: this recipe regenerates the nine public words and nothing else, and the test witness's secret is drawn from a separate stream whose seed is in no retained file";

/// **THE STAGE-21 RECIPE STRING, KEPT FOR READING AND NEVER FOR WRITING
/// (stage 22).**
///
/// The two run statements this lane retained before stage 22
/// (`results/zk60_block125m_lane/m125-run-l12-dense-run-statement.json` and
/// the twelve-block artifact's own copy) carry this exact string. Its public
/// weights are the ones [`dense_run_case`] still produces — bit for bit, at
/// every shape — so mapping the old name to the same generator keeps those
/// statements REGENERABLE and checkable against the block digests their
/// headers absorb, which is the whole contract of the field.
///
/// It is on no writer's path:
/// `the_writer_never_emits_the_legacy_recipe_string` asserts that the two
/// recipes this module may WRITE are the stage-22 ones.
pub(super) const LEGACY_DENSE_RUN_RECIPE_NAME: &str =
    "private_block::dense_tests::dense_run_case(<block profile's Shape>), the same fully dense public words for every block: SplitMix64 seeded 0xD15EED1900000001, read in the fixed order [Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg, Wu, Wd, x]; Wq/Wk/Wv/Wo uniform on [-56,-1] u [1,56]; gamma_a/gamma_m uniform on [40,127]; Wg/Wu uniform on [-96,-1] u [1,96]; Wd uniform on [-B,-1] u [1,B] with B = band_down_run(shape) (47 at the rungs, 1 at 125M); hidden input uniform on [-6000,-1] u [1,6000]";

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

/// the counted rung-G frame length, pre-stage-20 plus the counted bilinear
/// delta of the S19-F1 repair (`grow_tests::s20_bilinear_delta`)
fn rung_g_frame_bytes() -> usize {
    super::grow_tests::s20_frame_bytes(&Shape::rung_g(), 4_234_648)
}

/// **THE ACCEPTANCE TEST OF FINDING S19-F1 — the honest proof this defect
/// used to REJECT is now ACCEPTED.**
///
/// **History.** Until stage 20 this test was named
/// `s19_f1_an_honest_proof_of_the_fixture_with_one_input_word_moved_is_rejected`,
/// was `#[ignore]`d and FAILED on purpose: it was the shortest statement of
/// the defect. The two bilinear attention slots took the KEY-VALUE GROUP as
/// a FIXED coordinate of both private factors, so the slot's claimed sum was
/// a product of two multilinear extensions where the statement needed the
/// extension of a pointwise product — equal only when one side does not vary
/// across key-value groups. The honest receipt was REJECTED at
/// `slot 15 [04 Q zero-check (hosts 09Q, 11)]: sumcheck round 0:
/// s(0) + s(1) != claim`. Stage 20 makes the group bits sumcheck variables
/// under a public `eq`, and nothing about this test's WITNESS or its
/// assertions was weakened to make it pass — only the `#[ignore]`, the name
/// and the two `expect` messages changed.
///
/// **The witness is the production fixture with ONE WORD of the hidden input
/// changed**: `grow_tests::tame_case`'s own diagonal weights, its own input,
/// and `input[0] = 0`. With `tame_case`'s unmodified input the norm output is
/// exactly `+3` at even width indices and `-3` at odd ones at every token, so
/// the hidden state is the SAME in every head and every key-value head
/// carries the same keys and values; `input[0] = 0` moves one word of head 0
/// and nothing else, and that was enough.
#[test]
fn s19_f1_an_honest_proof_of_the_fixture_with_one_input_word_moved_is_accepted() {
    let sh = Shape::rung_g();
    let (public, ff, mut input) = super::grow_tests::tame_case(&sh);
    input[0] = 0;
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the witness builder accepts the moved fixture input");
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the witness itself is inconsistent, so this is not S19-F1");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_dense(&sh, &blk, w).expect("the honest prover");
    assert_eq!(bytes.len(), rung_g_frame_bytes(), "the frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("S19-F1 is not fixed: an HONEST receipt is rejected in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("S19-F1 is not fixed: an HONEST receipt is rejected from bytes");
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
    assert_eq!(bytes.len(), rung_g_frame_bytes(), "the dense feed-forward rung-G frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the receipt verifies from bytes");
    eprintln!("{} DENSE-FF one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", sh.name, t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short frame was accepted");
}

/// **THE FULLY DENSE one-block proof — the recipe of item 3 with no tame
/// word left in it.** Until stage 20 this test was `#[ignore]`d and FAILED on
/// finding S19-F1: the dense attention weights make the key-value heads carry
/// different activations, which is exactly what the defect rejected. Nothing
/// about it was weakened; the `#[ignore]` was removed and the frame length is
/// now the counted one of the repaired schedule.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_g() {
    let sh = Shape::rung_g();
    let (public, ff, input) = dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_dense(&sh, &blk, w).expect("the dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), rung_g_frame_bytes(), "the dense rung-G frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the dense receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the dense receipt verifies from bytes");
    eprintln!("{} DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", sh.name, t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short dense frame was accepted");
}

/// **STAGE 20: THE FIRST BISECTION, NOW A REGRESSION TEST.** It was stage
/// 19's `#[ignore]`d diagnostic — the harness that said WHICH knob of the
/// recipe made the honest dense proof fail. Every one of its ten variants is
/// HONEST, so the statement that survives the repair is the completeness one:
/// **no variant may be rejected by the VERIFIER.** A refusal by the witness
/// builder or by the prover is an ADMISSIBILITY statement about a recipe and
/// stays allowed (some bands really do leave `int16`); a verifier rejecting
/// an honest receipt is the S19-F1 class of failure and is forbidden. The
/// per-case line is still printed, so the diagnostic is not lost.
#[test]
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
    let mut rejected: Vec<String> = Vec::new();
    let (mut verified, mut refused) = (0usize, 0usize);
    for (name, w, input) in cases {
        let (public, ff) = statement_of_words(&s, &w);
        let wit = match witness::build_shaped(&s, &public, &ff, &input) {
            Ok(w) => w,
            Err(m) => {
                refused += 1;
                eprintln!("BISECT {name}: the WITNESS BUILDER refused: {m}");
                continue;
            }
        };
        let checkable = super::pad::every_checkable_relation_holds(&s, &ids, &wit);
        let blk = BlockPublic::new(public, ff);
        let mut bad = false;
        let verdict = match prove_dense(&s, &blk, wit) {
            Err(e) => {
                refused += 1;
                format!("the PROVER refused: {e}")
            }
            Ok((expected, receipt, bytes)) => match verify_inner_at(&s, &blk, &expected, &receipt) {
                Err(e) => {
                    bad = true;
                    format!("the VERIFIER rejected (typed): {e}")
                }
                Ok(_) => match verify_bytes_at(&s, &blk, &expected, &bytes) {
                    Err(e) => {
                        bad = true;
                        format!("the VERIFIER rejected (from bytes): {e}")
                    }
                    Ok(()) => {
                        verified += 1;
                        assert_eq!(bytes.len(), rung_g_frame_bytes(), "{name}: the frame is not the counted length");
                        "VERIFIED".to_string()
                    }
                },
            },
        };
        eprintln!("BISECT {name}: checkable relations {}, {verdict}", if checkable { "HOLD" } else { "FAIL" });
        if bad {
            rejected.push(format!("{name}: {verdict}"));
        }
    }
    eprintln!("BISECT the dense recipe at the rung-G shape: {verified} verified, {refused} refused before a proof existed, {} REJECTED", rejected.len());
    assert!(rejected.is_empty(), "an HONEST receipt was rejected by the verifier — the S19-F1 class of failure: {rejected:#?}");
    assert!(verified > 0, "no variant reached the verifier, so the test says nothing");
}

/// **STAGE 20: THE SECOND BISECTION, NOW A REGRESSION TEST** on the same
/// rule as the first — no HONEST case may be rejected by the verifier, and
/// with `tame_case`'s admissible diagonal weights every one of these eight
/// inputs must in fact VERIFY. This is the sharpest regression guard the
/// stage has: five of the eight were REJECTED before the repair.
///
/// **The HIDDEN INPUT alone.** The first
/// bisection found that the DIAGONAL production fixture also fails once the
/// hidden input changes, so the recipe is not what matters. This one holds the
/// public weights at `tame_case`'s diagonal matrices and moves only the input,
/// and it prints the structural degeneracies of each witness beside the
/// verdict: how many distinct values `norm_a`'s output takes, whether the Q
/// requantization remainder is constant, and whether the two RoPE partner
/// halves agree everywhere (which they do at the fixture, and which would hide
/// any confusion between a position and its partner).
#[test]
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
    let want_cases = cases.len();
    let mut verified = 0usize;
    for (name, input) in cases {
        let w = witness::build_shaped(&s, &public, &ff, &input).unwrap_or_else(|m| panic!("INPUT {name}: the WITNESS BUILDER refused: {m}"));
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
                    Ok(()) => {
                        assert_eq!(bytes.len(), rung_g_frame_bytes(), "{name}: the frame is not the counted length");
                        "VERIFIED".to_string()
                    }
                },
            },
        };
        eprintln!("INPUT {name}: norm_a takes {} distinct values, A_RQL takes {} ({rq:?}), RoPE partner halves {}; {verdict}", ys.len(), rq.len(), if partners_agree { "AGREE everywhere" } else { "differ" });
        // STAGE 20: every one of these inputs is HONEST and admissible, so
        // every one must VERIFY. Five of the eight were rejected by S19-F1.
        assert_eq!(verdict, "VERIFIED", "INPUT {name} did not verify");
        verified += 1;
    }
    assert_eq!(verified, want_cases, "not every hidden input reached the verifier");
}

/// **STAGE 20: THE THIRD BISECTION IS THE ACCEPTANCE MATRIX OF S19-F1**, and
/// is no longer `#[ignore]`d. It drives the two sides of the grouped-query
/// map apart INDEPENDENTLY — diagonal weights scaled per QUERY head and per
/// KEY-VALUE head, on the fixture's own input — and stage 19 measured three
/// of its five cases REJECTED, all three being exactly the ones in which the
/// key-value heads carry different activations. **Every one of the five must
/// now VERIFY**, and so must the review's own `distinct_kv_case` at both rung
/// profiles. Nothing was weakened: the cases, the scales and the input are
/// stage 19's, and the verdicts are still printed.
#[test]
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
        let w = witness::build_shaped(&s, &public, &ff, &tx).unwrap_or_else(|m| panic!("HEAD {name}: the WITNESS BUILDER refused: {m}"));
        let blk = BlockPublic::new(public, ff);
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
        eprintln!("HEAD {name}: {verdict}");
        // STAGE 20: cases iii, iv and v were REJECTED by S19-F1. All five are
        // honest and admissible, so all five must verify.
        assert_eq!(verdict, "VERIFIED", "HEAD {name} did not verify");
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
        assert!(o.is_accepted(), "{}: the review's distinct-KV honest control is not accepted", sh.name);
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
/// **STAGE 20: IT IS A REAL CONTROL NOW.** Stage 19 had to `#[ignore]` this
/// test because every one of its three perturbations makes the key-value
/// heads carry different activations, which is precisely the condition under
/// which S19-F1 rejected an HONEST proof: a rejection would not have
/// distinguished the tamper from the defect, and the honest control the test
/// opens with was itself rejected. With the repair the honest control is
/// ACCEPTED, so each rejection below is the tamper.
#[test]
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

// ===================================================================
// STAGE 22 — the recipe's stream carries the PUBLIC WEIGHTS and nothing else
// ===================================================================

/// **THE STRUCTURAL HALF OF STAGE 22 ITEM 1.** A string can say anything;
/// this asserts the arithmetic behind it.
///
/// 1. **The published stream is EXHAUSTED by the nine public words.** After
///    [`dense_public_words_with`] the SplitMix64 state is exactly the state
///    of [`DENSE_SEED`] advanced by one draw per public weight ENTRY and no
///    more. SplitMix64's state is a counter, `seed + n * GAMMA`, injective
///    in `n` over a `u64`, so this equality pins the draw count exactly: a
///    tenth read of any length would move it.
/// 2. **The hidden input is NOT that stream continued.** The witness the
///    tests use is drawn from [`DENSE_INPUT_SEED`], and what the PUBLISHED
///    seed would give if a reader guessed that the input comes next — which
///    is what it DID give until stage 22 — is a different vector.
/// 3. The two seeds are different constants, and the input stream is still
///    deterministic and dense.
#[test]
fn the_dense_recipes_public_stream_is_consumed_entirely_by_public_words() {
    for s in [Shape::rung(), Shape::rung_g(), Shape::m125()] {
        let draws = dense_public_word_draws(&s);
        let entries: u64 = {
            let (w, _) = dense_public_words_with(&s, BAND_ATTN, BAND_GATE, band_down_run(&s), GAIN);
            w.iter().map(|m| m.len() as u64).sum()
        };
        assert_eq!(draws, entries, "{}: the counted draw total is not the number of public weight entries", s.name);
        // (1) the stream stops exactly there
        let (_, after) = dense_public_words_with(&s, BAND_ATTN, BAND_GATE, band_down_run(&s), GAIN);
        let mut probe = Rng(DENSE_SEED);
        for _ in 0..draws {
            probe.next();
        }
        assert_eq!(after, probe.0, "{}: the public-weights stream is not exhausted by the nine public words", s.name);
        // and one more draw is a DIFFERENT state, so the equality above is a
        // tight count and not an accident of the generator
        probe.next();
        assert_ne!(after, probe.0, "{}: the stream state does not move with a draw", s.name);
        // (2) the hidden input is not the published stream continued
        let mut leaked = Rng(after);
        let would_have_been: Vec<i16> = (0..s.tokens * s.width).map(|_| leaked.nonzero(INPUT_MAG) as i16).collect();
        let mine = dense_hidden_input(&s, INPUT_MAG);
        assert_eq!(mine.len(), would_have_been.len(), "{}: the input length", s.name);
        assert_ne!(mine, would_have_been, "{}: the hidden input IS the published stream continued — the split did not happen", s.name);
        // (3) two constants, and the input is still what the tests need
        assert_ne!(DENSE_SEED, DENSE_INPUT_SEED, "the two streams share a seed");
        assert_eq!(mine, dense_hidden_input(&s, INPUT_MAG), "{}: the hidden input is not deterministic", s.name);
        assert!(mine.iter().all(|v| *v != 0), "{}: the hidden input has a zero", s.name);
        assert!(mine.iter().any(|v| *v != mine[0]), "{}: the hidden input is constant", s.name);
        assert!(mine.iter().any(|v| *v > 0) && mine.iter().any(|v| *v < 0), "{}: the hidden input is one-signed", s.name);
        eprintln!("S22 STREAM SPLIT at {}: {draws} public draws, stream exhausted, the input is an independent stream", s.name);
    }
}

/// **THE TEXTUAL HALF, and its non-vacuity.** The two recipe strings this
/// build may WRITE into a statement say nothing about the hidden input, and
/// the stage-21 string they replaced is caught by the very same deny-list —
/// so the check has teeth. `run_statement_file::hidden_input_token` is the
/// one checker and it is used by the statement-file test too.
#[test]
fn the_recipe_strings_this_build_writes_describe_public_weights_only() {
    use super::run_statement_file::{hidden_input_token, DENSE_RUN_FIXTURE, LEGACY_TAME_RECIPE_NAME, TAME_FIXTURE};
    for (what, s) in [
        ("the dense recipe name", DENSE_RUN_FIXTURE.name),
        ("the dense recipe description", DENSE_RUN_FIXTURE.description),
        ("the tame recipe name", TAME_FIXTURE.name),
        ("the tame recipe description", TAME_FIXTURE.description),
    ] {
        assert_eq!(hidden_input_token(s), None, "{what} describes the hidden input: {s:?}");
        // **AND IT MUST BE PRINTABLE ASCII.** `run_statement_file::ascii`
        // refuses anything else at write time, because `{:?}`'s escaping of
        // a non-ASCII character is `\u{..}`, which is not valid JSON. That
        // guard is fail-closed and it worked — a single em dash in one of
        // these descriptions made every statement-file test fail at once
        // (stage 22, `w6`) — but it names the writer and not the string, so
        // the string is checked here where the mistake is made.
        assert!(s.bytes().all(|b| (0x20..0x7f).contains(&b)), "{what} is not printable ASCII, so no statement file can be written: {s:?}");
    }
    // THE CHECK HAS TEETH: the string stage 22 replaced is refused by it, by
    // name, and the token it is caught on is printed
    let t = hidden_input_token(LEGACY_DENSE_RUN_RECIPE_NAME).expect("the stage-21 dense recipe string passed the deny-list, so the deny-list says nothing");
    eprintln!("S22 DENY-LIST: the stage-21 dense recipe string is caught on {t:?}");
    // the legacy TAME name was never a leak — it was vague, not revealing —
    // and it is recorded here that the deny-list does not pretend otherwise
    assert_eq!(hidden_input_token(LEGACY_TAME_RECIPE_NAME), None, "the legacy tame name is not a hidden-input leak and must not be reported as one");
    // and the two names the writer uses are not the two legacy ones
    assert_ne!(DENSE_RUN_FIXTURE.name, LEGACY_DENSE_RUN_RECIPE_NAME, "the writer still emits the stage-21 dense string");
    assert_ne!(TAME_FIXTURE.name, LEGACY_TAME_RECIPE_NAME, "the writer still emits the stage-18 tame string");
}

// ===================================================================
// STAGE 20 — the repair of finding S19-F1
// ===================================================================

/// **THE INDEPENDENT CHECK OF THE TWO IDENTITIES.**
///
/// The prover and the verifier of this module share ONE definition
/// (`argument::define`), which is exactly why S19-F1 survived every
/// prove-and-verify test written on a degenerate witness: both sides
/// evaluated the same wrong expression. Nothing below goes through `define`,
/// `Layout`, the transcript or the sumcheck. It evaluates, with plain loops
/// over the Boolean cube and nothing else,
///
/// * **LHS** — the multilinear extension of the pointwise product the slot's
///   HOST demands: `sum_{h,t,j,c} eq(r_h,h) eq(r_t,t) eq(r_j,j) QR8[t,h,c]
///   KR8[j,g(h),c]` for the score, and the matching sum for `PV`, with
///   `g(h)` the key-value group of head slot `h` (its top `lkv` bits);
/// * **NEW** — the identity stage 20 builds: `sum_{g,c} eq(r_g,g)
///   Q~(r_t,(g,r_hj),c) K~(r_j,g,c)`, the group SUMMED under a public `eq`;
/// * **OLD** — what the module computed until stage 20: the product of the
///   two extensions at the shared fixed group point, `sum_c Q~(r_t,r_h,c)
///   K~(r_j,r_g,c)`.
///
/// The statement is three-part and each part is load-bearing: **NEW = LHS
/// always**; **OLD != LHS on a generic witness** (or the defect would not
/// have existed and the repair would be unnecessary); **OLD = LHS on the
/// degenerate fixture** (which is why nothing saw it for nineteen stages).
struct Bilinear {
    t_pad: usize,
    h_pad: usize,
    head_dim: usize,
    kv_heads: usize,
}

impl Bilinear {
    fn lkv(&self) -> usize {
        self.kv_heads.trailing_zeros() as usize
    }
    fn lh(&self) -> usize {
        self.h_pad.trailing_zeros() as usize
    }
    /// the key-value group of head slot `h`: its top `lkv` bits
    fn group(&self, h: usize) -> usize {
        h >> (self.lh() - self.lkv())
    }
}

/// `eq(point, x)` for the boolean vector whose bits are `x`'s, MOST
/// SIGNIFICANT FIRST — the convention of `mle::eq_table_msb`, written out
/// here rather than called, so that the check shares no code with the module.
fn eq_at(point: &[Fp2], x: usize) -> Fp2 {
    let n = point.len();
    let mut acc = Fp2::ONE;
    for (k, r) in point.iter().enumerate() {
        let b = (x >> (n - 1 - k)) & 1;
        acc = acc.mul(if b == 1 { *r } else { Fp2::ONE.sub(*r) });
    }
    acc
}

/// the three values of the SCORE identity: `(LHS, NEW, OLD)`
fn score_identity(g: &Bilinear, qr8: &[i64], kr8: &[i64], r_h: &[Fp2], r_t: &[Fp2], r_j: &[Fp2]) -> (Fp2, Fp2, Fp2) {
    let (tp, hp, dh, kv, lkv) = (g.t_pad, g.h_pad, g.head_dim, g.kv_heads, g.lkv());
    let (r_g, r_hj) = (&r_h[..lkv], &r_h[lkv..]);
    let q = |t: usize, h: usize, c: usize| Fp2::from_i64(qr8[t * hp * dh + h * dh + c]);
    let k = |j: usize, grp: usize, c: usize| Fp2::from_i64(kr8[j * kv * dh + grp * dh + c]);
    // LHS: the extension of the pointwise product
    let mut lhs = Fp2::ZERO;
    for h in 0..hp {
        for t in 0..tp {
            for j in 0..tp {
                let w = eq_at(r_h, h).mul(eq_at(r_t, t)).mul(eq_at(r_j, j));
                if w == Fp2::ZERO {
                    continue;
                }
                let mut s = Fp2::ZERO;
                for c in 0..dh {
                    s = s.add(q(t, h, c).mul(k(j, g.group(h), c)));
                }
                lhs = lhs.add(w.mul(s));
            }
        }
    }
    // NEW: the group summed, under a public eq
    let mut new = Fp2::ZERO;
    for grp in 0..kv {
        for c in 0..dh {
            // Q~(r_t, (grp, r_hj), c)
            let mut qe = Fp2::ZERO;
            for t in 0..tp {
                for hj in 0..(hp / kv) {
                    qe = qe.add(eq_at(r_t, t).mul(eq_at(r_hj, hj)).mul(q(t, grp * (hp / kv) + hj, c)));
                }
            }
            // K~(r_j, grp, c)
            let mut ke = Fp2::ZERO;
            for j in 0..tp {
                ke = ke.add(eq_at(r_j, j).mul(k(j, grp, c)));
            }
            new = new.add(eq_at(r_g, grp).mul(qe).mul(ke));
        }
    }
    // OLD: the product of the two extensions at the shared fixed group point
    let mut old = Fp2::ZERO;
    for c in 0..dh {
        let mut qe = Fp2::ZERO;
        for t in 0..tp {
            for h in 0..hp {
                qe = qe.add(eq_at(r_t, t).mul(eq_at(r_h, h)).mul(q(t, h, c)));
            }
        }
        let mut ke = Fp2::ZERO;
        for j in 0..tp {
            for grp in 0..kv {
                ke = ke.add(eq_at(r_j, j).mul(eq_at(r_g, grp)).mul(k(j, grp, c)));
            }
        }
        old = old.add(qe.mul(ke));
    }
    (lhs, new, old)
}

/// the three values of the PV identity: `(LHS, NEW, OLD)`
fn pv_identity(g: &Bilinear, p: &[i64], v8: &[i64], r_h: &[Fp2], r_t: &[Fp2], r_i: &[Fp2]) -> (Fp2, Fp2, Fp2) {
    let (tp, hp, dh, kv, lkv) = (g.t_pad, g.h_pad, g.head_dim, g.kv_heads, g.lkv());
    let (r_g, r_hj) = (&r_h[..lkv], &r_h[lkv..]);
    let pp = |h: usize, t: usize, s: usize| Fp2::from_i64(p[(h * tp + t) * tp + s]);
    let vv = |s: usize, grp: usize, i: usize| Fp2::from_i64(v8[s * kv * dh + grp * dh + i]);
    let mut lhs = Fp2::ZERO;
    for h in 0..hp {
        for t in 0..tp {
            for i in 0..dh {
                let w = eq_at(r_t, t).mul(eq_at(r_h, h)).mul(eq_at(r_i, i));
                if w == Fp2::ZERO {
                    continue;
                }
                let mut o = Fp2::ZERO;
                for s in 0..tp {
                    o = o.add(pp(h, t, s).mul(vv(s, g.group(h), i)));
                }
                lhs = lhs.add(w.mul(o));
            }
        }
    }
    let mut new = Fp2::ZERO;
    for grp in 0..kv {
        for s in 0..tp {
            let mut pe = Fp2::ZERO;
            for t in 0..tp {
                for hj in 0..(hp / kv) {
                    pe = pe.add(eq_at(r_hj, hj).mul(eq_at(r_t, t)).mul(pp(grp * (hp / kv) + hj, t, s)));
                }
            }
            let mut ve = Fp2::ZERO;
            for i in 0..dh {
                ve = ve.add(eq_at(r_i, i).mul(vv(s, grp, i)));
            }
            new = new.add(eq_at(r_g, grp).mul(pe).mul(ve));
        }
    }
    let mut old = Fp2::ZERO;
    for s in 0..tp {
        let mut pe = Fp2::ZERO;
        for h in 0..hp {
            for t in 0..tp {
                pe = pe.add(eq_at(r_h, h).mul(eq_at(r_t, t)).mul(pp(h, t, s)));
            }
        }
        let mut ve = Fp2::ZERO;
        for grp in 0..kv {
            for i in 0..dh {
                ve = ve.add(eq_at(r_g, grp).mul(eq_at(r_i, i)).mul(vv(s, grp, i)));
            }
        }
        old = old.add(pe.mul(ve));
    }
    (lhs, new, old)
}

/// a deterministic point of `n` field elements from this module's own stream
fn point_of(r: &mut Rng, n: usize) -> Vec<Fp2> {
    (0..n).map(|_| Fp2::new(Fp::new(r.next() % crate::field::P), Fp::new(r.next() % crate::field::P))).collect()
}

/// **THE IDENTITY CHECK ON THE REAL RUNG-G WITNESSES.** The FULLY dense
/// witness is the generic one; `tame_case`'s is the degenerate one every
/// earlier stage proved at. Both are read plane by plane out of the witness
/// builder, and the three sums above are taken at a fixed random point.
#[test]
fn the_two_bilinear_identities_hold_independently_of_the_argument_at_the_rung_g() {
    let sh = Shape::rung_g();
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    let g = Bilinear { t_pad: sh.t_pad, h_pad: sh.h_pad, head_dim: sh.head_dim, kv_heads: sh.kv_heads };
    assert_eq!(g.lkv(), 1, "the rung-G shape must group, or this test says nothing");
    let mut r = Rng(0x5C0E_1D01_0000_0001);
    let (r_h, r_t, r_j) = (point_of(&mut r, g.lh()), point_of(&mut r, 5), point_of(&mut r, 5));
    let r_i = point_of(&mut r, g.head_dim.trailing_zeros() as usize);
    assert_eq!(1usize << r_t.len(), sh.t_pad, "the token point is not the padded token axis");
    for (what, case, generic) in [("FULLY DENSE (generic)", dense_case(&sh), true), ("tame_case (the degenerate fixture)", super::grow_tests::tame_case(&sh), false)] {
        let (public, ff, input) = case;
        let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the honest witness");
        let pl = |toy: usize| -> &[i64] { &w.planes[ids.at(toy)] };
        let (s_lhs, s_new, s_old) = score_identity(&g, pl(A_QR8), pl(A_KR8), &r_h, &r_t, &r_j);
        let (o_lhs, o_new, o_old) = pv_identity(&g, pl(A_P), pl(A_V8), &r_h, &r_t, &r_i);
        assert_eq!(s_new, s_lhs, "{what}: the repaired SCORE identity does not hold");
        assert_eq!(o_new, o_lhs, "{what}: the repaired PV identity does not hold");
        eprintln!("IDENTITY {what}: SCORE new == lhs, PV new == lhs; SCORE old {} lhs, PV old {} lhs", if s_old == s_lhs { "==" } else { "!=" }, if o_old == o_lhs { "==" } else { "!=" });
        if generic {
            assert_ne!(s_old, s_lhs, "{what}: the OLD product-of-extensions formula AGREES on a generic witness — then S19-F1 was not what it was said to be");
            assert_ne!(o_old, o_lhs, "{what}: the OLD PV formula AGREES on a generic witness");
        } else {
            assert_eq!(s_old, s_lhs, "{what}: the OLD formula DISAGREES on the degenerate fixture — then the fixture is not what hid the defect");
            assert_eq!(o_old, o_lhs, "{what}: the OLD PV formula DISAGREES on the degenerate fixture");
        }
    }
}

/// **STAGE 22: THE SAME INDEPENDENT CHECK ON THE REAL rung-K4 WITNESSES,
/// WHERE THE GROUP IS TWO BITS.**
///
/// The rung-G check above is the same statement at `lkv = 1`, and the
/// synthetic check below is at `lkv = 2` but on RANDOM planes. This one is
/// the pair of them: two group bits AND a real witness of a shape that
/// proves. `sum_{g in {0,1}^2} eq(r_g, g) ...` has four terms, so a
/// construction that summed only the leading bit — or that kept the trailing
/// one fixed on both factors, which is precisely S19-F1 restricted to half
/// the group — would disagree here and agree at every rung-G test.
#[test]
fn the_two_bilinear_identities_hold_independently_of_the_argument_at_the_rung_k4() {
    let sh = Shape::rung_k4();
    let ids = Ids::new(&sh).expect("the rung-K4 plane map");
    let g = Bilinear { t_pad: sh.t_pad, h_pad: sh.h_pad, head_dim: sh.head_dim, kv_heads: sh.kv_heads };
    assert_eq!(g.lkv(), 2, "the rung-K4 shape must carry TWO group bits, or this test says nothing new");
    let mut r = Rng(0x5C0E_1D03_0000_0001);
    let lt = sh.t_pad.trailing_zeros() as usize;
    let (r_h, r_t, r_j) = (point_of(&mut r, g.lh()), point_of(&mut r, lt), point_of(&mut r, lt));
    let r_i = point_of(&mut r, sh.head_dim.trailing_zeros() as usize);
    assert_eq!((1usize << r_h.len(), 1usize << r_t.len()), (sh.h_pad, sh.t_pad), "the head or token point is not the padded axis");
    for (what, case, generic) in [
        ("FULLY DENSE (generic)", dense_case(&sh), true),
        ("tame_case (the degenerate fixture)", super::grow_tests::tame_case(&sh), false),
    ] {
        let (public, ff, input) = case;
        let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the honest rung-K4 witness");
        let pl = |toy: usize| -> &[i64] { &w.planes[ids.at(toy)] };
        let (s_lhs, s_new, s_old) = score_identity(&g, pl(A_QR8), pl(A_KR8), &r_h, &r_t, &r_j);
        let (o_lhs, o_new, o_old) = pv_identity(&g, pl(A_P), pl(A_V8), &r_h, &r_t, &r_i);
        assert_eq!(s_new, s_lhs, "{what}: the repaired SCORE identity does not hold at rung-K4");
        assert_eq!(o_new, o_lhs, "{what}: the repaired PV identity does not hold at rung-K4");
        eprintln!("K4 IDENTITY {what}: SCORE new == lhs, PV new == lhs; SCORE old {} lhs, PV old {} lhs", if s_old == s_lhs { "==" } else { "!=" }, if o_old == o_lhs { "==" } else { "!=" });
        if generic {
            assert_ne!(s_old, s_lhs, "{what}: the OLD product-of-extensions SCORE formula AGREES at rung-K4, so the check is vacuous here");
            assert_ne!(o_old, o_lhs, "{what}: the OLD PV formula AGREES at rung-K4");
        } else {
            assert_eq!(s_old, s_lhs, "{what}: the OLD SCORE formula DISAGREES on the degenerate fixture, so the fixture is not what hid the defect");
            assert_eq!(o_old, o_lhs, "{what}: the OLD PV formula DISAGREES on the degenerate fixture");
        }
    }
}

/// **THE SAME CHECK AT A SYNTHETIC `kv_heads = 4` GEOMETRY**, on RANDOM
/// planes rather than a witness. No shape this lane proves at has four
/// key-value heads except 125M, which is far too large to sum over here; and
/// random planes are a stronger test of an algebraic identity than a witness,
/// because a witness has structure that could hide a mistake. `lkv = 2` is
/// also the first case in which the group is more than one bit.
#[test]
fn the_two_bilinear_identities_hold_at_a_synthetic_four_key_value_head_geometry() {
    let mut r = Rng(0x5C0E_1D02_0000_0001);
    for (t_pad, h_pad, head_dim, kv_heads) in [(8usize, 4usize, 4usize, 4usize), (8, 8, 4, 4), (8, 4, 4, 2), (8, 2, 4, 1)] {
        let g = Bilinear { t_pad, h_pad, head_dim, kv_heads };
        let plane = |r: &mut Rng, n: usize| -> Vec<i64> { (0..n).map(|_| r.pick(-127, 127)).collect() };
        let qr8 = plane(&mut r, t_pad * h_pad * head_dim);
        let kr8 = plane(&mut r, t_pad * kv_heads * head_dim);
        let p = plane(&mut r, h_pad * t_pad * t_pad);
        let v8 = plane(&mut r, t_pad * kv_heads * head_dim);
        let lt = t_pad.trailing_zeros() as usize;
        let (r_h, r_t, r_j) = (point_of(&mut r, g.lh()), point_of(&mut r, lt), point_of(&mut r, lt));
        let r_i = point_of(&mut r, head_dim.trailing_zeros() as usize);
        let (s_lhs, s_new, s_old) = score_identity(&g, &qr8, &kr8, &r_h, &r_t, &r_j);
        let (o_lhs, o_new, o_old) = pv_identity(&g, &p, &v8, &r_h, &r_t, &r_i);
        let label = format!("T{t_pad}/H{h_pad}/dh{head_dim}/KV{kv_heads}");
        assert_eq!(s_new, s_lhs, "{label}: the repaired SCORE identity does not hold");
        assert_eq!(o_new, o_lhs, "{label}: the repaired PV identity does not hold");
        // with ONE key-value group the two formulas are the SAME expression,
        // which is the toy's exemption, stated algebraically
        if kv_heads == 1 {
            assert_eq!(s_old, s_lhs, "{label}: the OLD formula must be the identity when there is one key-value head");
            assert_eq!(o_old, o_lhs, "{label}: the OLD PV formula must be the identity when there is one key-value head");
        } else {
            assert_ne!(s_old, s_lhs, "{label}: the OLD SCORE formula agrees on random planes");
            assert_ne!(o_old, o_lhs, "{label}: the OLD PV formula agrees on random planes");
        }
        eprintln!("IDENTITY {label}: new == lhs on both; old {} lhs", if s_old == s_lhs && o_old == o_lhs { "==" } else { "!=" });
    }
}

/// **THE NEGATIVE CONTROLS THE REPAIR MAKES POSSIBLE (stage 20 item 3).**
///
/// With the FULLY dense recipe both key-value groups carry real, DIFFERENT
/// data — the regime S19-F1 rejected outright, so none of this could be
/// asked before. One `+1` in each of the four planes the two bilinear slots
/// read, at a NON-FIRST key-value group and a NON-FIRST query head, and the
/// exchange of the two groups' whole key family. Every one must be refused
/// by the prover or rejected by the verifier, and who does it is recorded.
#[test]
fn a_perturbation_in_the_second_key_value_group_of_the_dense_witness_is_rejected_at_the_rung_g() {
    let sh = Shape::rung_g();
    let group = sh.q_heads / sh.kv_heads;
    let (public, ff, input) = dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    let (tp, dp, dh, kvw) = (sh.t_pad, sh.d_pad, sh.head_dim, sh.kv_heads * sh.head_dim);
    // the honest control FIRST, or nothing below is a statement
    let honest = outcome(&sh, &blk, clone_witness(&base));
    assert!(honest.is_accepted(), "the fully dense honest witness is not accepted: {}", honest.short());
    // query head 4 is the second head of key-value group 1 — neither the
    // first head nor the first group
    let (h, kv) = (4usize, 1usize);
    assert_eq!(h / group, kv, "query head 4 must sit in key-value group 1");
    let slot = sh.head_slot(h);
    assert!(slot >= sh.h_pad / sh.kv_heads, "slot {slot} is not in the second group's block");
    let cases: [(&str, usize, usize); 4] = [
        ("A_QR8, the rotated query of a non-first head of the second group", ids.at(A_QR8), 3 * dp + slot * dh + 5),
        ("A_KR8, the rotated key of the second key-value group", ids.at(A_KR8), 3 * kvw + kv * dh + 9),
        ("A_P, a causally live softmax weight of a non-first head of the second group", ids.at(A_P), (slot * tp + 5) * tp + 2),
        ("A_V8, the value of the second key-value group", ids.at(A_V8), 7 * kvw + kv * dh + 2),
    ];
    let (mut prover, mut verifier) = (0usize, 0usize);
    for (what, plane, at) in cases {
        let mut w = clone_witness(&base);
        w.planes[plane][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("SECOND GROUP {what}: {}", o.short());
        match o {
            Outcome::Accepted => panic!("{what} was ACCEPTED"),
            Outcome::ProverRefused(_) => prover += 1,
            Outcome::VerifierRejected(_) => verifier += 1,
        }
    }
    eprintln!("SECOND-GROUP SWEEP at the rung-G shape: {prover} refused by the prover, {verifier} rejected by the verifier, 0 accepted");
    assert_eq!(prover + verifier, 4, "not every plane was exercised");
}

/// **THE KEY-VALUE SWAP ON A WITNESS WHOSE TWO GROUPS BOTH CARRY DATA.**
///
/// The independent review's attack 3 could only be written on
/// `distinct_kv_case`, whose SECOND key-value head requantizes to identically
/// zero (stage 19's surprise 3) — which is also the one grouped case S19-F1
/// happened to accept. On the fully dense recipe both groups are nonzero and
/// different, so exchanging the two groups' whole KEY family is a statement
/// about the group map and nothing else. It must be rejected BY THE VERIFIER:
/// every relation inside `SC_KVZC` is per position and survives the swap.
#[test]
fn exchanging_the_two_key_value_groups_keys_is_rejected_at_the_rung_g() {
    let sh = Shape::rung_g();
    assert_eq!(sh.kv_heads, 2, "this case is written for the rung-G shape's two key-value groups");
    let (public, ff, input) = dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the fully dense honest witness is not accepted");
    // the KEY family alone: the requantized key, its remainder, the rotated
    // key and its remainder. The value planes are left alone, so this is a
    // statement about the keys.
    let key_planes = [ids.at(A_K8), ids.at(A_RKL), ids.at(A_KR8), ids.at(A_RKRL)];
    let mut w = clone_witness(&base);
    let mut moved = 0usize;
    for p in key_planes {
        for t in 0..sh.t_pad {
            for i in 0..dh {
                let (a, b) = (t * kvw + i, t * kvw + dh + i);
                if w.planes[p][a] != w.planes[p][b] {
                    moved += 1;
                }
                w.planes[p].swap(a, b);
            }
        }
    }
    assert!(moved > 0, "the two key-value groups carry identical keys: the swap is a no-op");
    let o = outcome(&sh, &blk, w);
    eprintln!("GQA DENSE: the two key-value groups' key family exchanged ({moved} positions differ): {}", o.short());
    assert!(matches!(o, Outcome::VerifierRejected(_)), "the dense key-value swap was not rejected by the VERIFIER: {}", o.short());
}
