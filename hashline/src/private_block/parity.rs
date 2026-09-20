//! WITNESS-VS-KERNEL PARITY of the private block module (disposition
//! condition 6): the integer witness built here must equal
//! `private-block-kernel::run_block` element for element, and must refuse at
//! the same site with the same message, on many deterministic public inputs.
//!
//! Everything generated here is PUBLIC SYNTHETIC test data produced by a
//! fixed-seed integer generator: no OS randomness, no real model, no real
//! input, nothing read from or written to disk, and nothing printed but
//! counts and site names (never a witness value, as the kernel's own
//! `Trace` documentation requires).
//!
//! SCOPE. The witness of this module computes the WHOLE block, so exactly two
//! outcomes are allowed per case: both accept — every plane with a kernel
//! counterpart compared element for element, and every plane without one
//! (the remainder and limb planes, which the kernel keeps no witness for)
//! checked against the kernel's own biased requantization identity — or both
//! refuse with the SAME string (same site, same text). Either one-sided
//! outcome is a failure.

use super::layout::*;
use super::witness::{self, Witness};
use super::{AttentionPublic, BlockPublic, FeedForwardPublic};
use private_block_kernel as kern;
// JOB K: the SHAPE-DRIVEN reference lives in its own crate, because
// `private-block-kernel` is compiled into the zkVM guest and is byte-frozen.
// `cross_parity_tests` below is what keeps the two from drifting.
use private_block_kernel_shaped as kshaped;
use std::collections::BTreeMap;
use std::sync::OnceLock;

/// generated cases per parity run (the brief's floor is 1,000)
const CASES: usize = 1_200;

// ---------------------------------------------------------------- generator

/// SplitMix64: a fixed, portable integer stream. No OS randomness anywhere.
struct Rng(u64);

impl Rng {
    fn seeded(idx: usize) -> Self {
        // a fixed lane constant mixed with the case index
        Rng(0x7A6B_5C4D_3E2F_1009u64.wrapping_add((idx as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15)))
    }
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    /// uniform-ish in [lo, hi]
    fn pick(&mut self, lo: i64, hi: i64) -> i64 {
        lo + (self.next() % ((hi - lo + 1) as u64)) as i64
    }
}

/// The three PUBLIC tables, generated once: the rope pair and the exp table of
/// the attention calibration, and the frozen int16-output SiLU activation
/// table of the feed-forward half (`(e_in, e_out) = (-3, -11)`, the fixture's).
fn tables() -> &'static (Vec<i64>, Vec<i64>, [i64; 256], [i16; 256]) {
    static TAB: OnceLock<(Vec<i64>, Vec<i64>, [i64; 256], [i16; 256])> = OnceLock::new();
    TAB.get_or_init(|| {
        let (cos, sin) = crate::tables_attn::rope_tables_generate(T, DH, 10000.0, F_RO);
        let (exp, _) = crate::tables_attn::exp_member(0, DH, F_E);
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member (-3, -11)");
        (cos, sin, exp, act)
    })
}

/// One generated public case: the same words in the module's statement form
/// and in the kernel's.
pub(crate) struct Case {
    pub public: AttentionPublic,
    /// the feed-forward half's public words, in this module's own form
    pub ff: FeedForwardPublic,
    pub kweights: kern::PublicWeights,
    pub ktables: kern::PublicTables,
    pub input: Vec<i16>,
}

/// `(out, in)` row-major matrix with a fixed diagonal and a signed band of
/// amplitude `mag`; `mag` is what sweeps the cases from well-conditioned
/// (every class holds) to hopeless (an early requant refuses).
fn matrix(r: &mut Rng, outer: usize, inner: usize, diag: i64, mag: i64) -> Vec<i8> {
    (0..outer * inner)
        .map(|k| {
            let (o, i) = (k / inner, k % inner);
            let v = if o == i { diag } else { r.pick(-mag, mag) };
            v.clamp(-127, 127) as i8
        })
        .collect()
}

/// Case `idx` of the deterministic sweep. Same index, same bytes, always.
pub(crate) fn case(idx: usize) -> Case {
    let mut r = Rng::seeded(idx);
    let (cos, sin, exp, act) = tables();
    // Three independent knobs on a 13 x 4 x 7 grid, swept by nested strides so
    // that 1,200 cases cover every grid point (364 of them, 23 sweeps of the
    // inner 52): off-diagonal weight amplitude, norm gain, input amplitude.
    // The large amplitudes are what drives a case into a refusal: with a full
    // band the Q/K/V and score requants leave their int8 class, and with a
    // near-full input residual 1 leaves int16.
    const BAND: [i64; 13] = [0, 1, 3, 8, 20, 48, 80, 100, 110, 118, 124, 127, 127];
    let mag = BAND[idx % 13];
    let gain = [24i64, 64, 96, 127][(idx / 13) % 4];
    let xmag = [1i64, 3, 9, 40, 200, 3_000, 32_767][(idx / 52) % 7];
    // The feed-forward band is swept INDEPENDENTLY (stride 11, which is
    // coprime with 364 = 13 * 4 * 7, so all 1,200 four-tuples are distinct):
    // a case whose attention half is tame can still stress the gate, up,
    // product and down requants, which a shared band would hide behind the
    // score refusals of the high-amplitude region.
    let ffn_mag = BAND[(idx / 11) % 13];

    let wq = matrix(&mut r, D, D, 64, mag);
    let wk = matrix(&mut r, KV, D, 64, mag);
    let wv = matrix(&mut r, KV, D, 64, mag);
    let wo = matrix(&mut r, D, D, 64, mag);
    let gamma_a: Vec<i8> = (0..D).map(|_| r.pick(gain - 8, gain).clamp(-127, 127) as i8).collect();
    let gamma_m: Vec<i8> = (0..D).map(|_| r.pick(gain - 8, gain).clamp(-127, 127) as i8).collect();
    // the feed-forward matrices are `(in, out)` row-major, as the kernel wants
    let wg_t = matrix(&mut r, D, 16, 64, ffn_mag);
    let wu_t = matrix(&mut r, D, 16, 64, ffn_mag);
    let wd_t = matrix(&mut r, 16, D, 64, ffn_mag);
    let input: Vec<i16> = (0..T * D).map(|_| r.pick(-xmag, xmag) as i16).collect();

    let public = AttentionPublic::new(&wq, &wk, &wv, &wo, &gamma_a, cos, sin, exp).expect("generated public statement");
    let ff = FeedForwardPublic::new(&gamma_m, &wg_t, &wu_t, &wd_t, act).expect("generated feed-forward statement");
    let kweights = kern::PublicWeights::from_slices(&wq, &wk, &wv, &wo, &gamma_a, &gamma_m, &wg_t, &wu_t, &wd_t).expect("generated kernel weights");
    let ktables = kern::PublicTables::from_slices(cos, sin, exp, act).expect("generated kernel tables");
    Case { public, ff, kweights, ktables, input }
}

// ---------------------------------------------------------------- comparison

/// Element-for-element equality. Reports the differing COUNT and the first
/// differing INDEX only — never a value, on either side.
fn eq(mine: &[i64], theirs: &[i64], idx: usize, name: &str) {
    assert_eq!(mine.len(), theirs.len(), "case {idx}: plane {name} length {} vs kernel {}", mine.len(), theirs.len());
    let bad = mine.iter().zip(theirs).filter(|(a, b)| a != b).count();
    let first = mine.iter().zip(theirs).position(|(a, b)| a != b);
    assert!(bad == 0, "case {idx}: plane {name} differs from the kernel in {bad} of {} elements (first at index {first:?})", mine.len());
}

/// The planes the kernel records before the attention half can refuse again
/// (it writes them all at once, after the score requant).
fn compare_traced_prefix(w: &Witness, tr: &kern::Trace, idx: usize) {
    eq(&w.planes[A_D], &tr.na_dd, idx, "norm_a D");
    eq(&w.planes[A_Y], &tr.na_y, idx, "norm_a y");
    eq(&w.planes[A_Q8], &tr.q8, idx, "q8");
    eq(&w.planes[A_K8], &tr.k8, idx, "k8");
    eq(&w.planes[A_V8], &tr.v8, idx, "v8");
    eq(&w.planes[A_QR8], &tr.qr8, idx, "qr8");
    eq(&w.planes[A_KR8], &tr.kr8, idx, "kr8");
    eq(&w.planes[A_S8], &tr.s8, idx, "s8");
}

/// Every attention-half plane with a kernel counterpart, plus the derived
/// planes the kernel does not carry (`D^2`, the one-hot selector).
pub(crate) fn compare_attention_half(w: &Witness, tr: &kern::Trace, idx: usize) {
    compare_traced_prefix(w, tr, idx);
    eq(&w.planes[A_MX], &tr.m_row, idx, "row max");
    eq(&w.planes[A_SUM], &tr.sum, idx, "row sum");
    eq(&w.planes[A_P], &tr.p, idx, "softmax p");
    eq(&w.planes[A_O8], &tr.o8, idx, "o8");
    eq(&w.planes[A_AO], &tr.ao8, idx, "ao");
    eq(&w.planes[A_X1], &tr.xres1, idx, "xres1");
    // D^2 is the witness's own plane; the kernel keeps only D
    let dsq: Vec<i64> = tr.na_dd.iter().map(|d| d * d).collect();
    eq(&w.planes[A_DSQ], &dsq, idx, "norm_a D^2");
    // the one-hot selector against the kernel's argmax index
    let mut zsel = vec![0i64; H * T * T];
    for row in 0..H * T {
        zsel[row * T + tr.arg[row] as usize] = 1;
    }
    eq(&w.planes[A_ZSEL], &zsel, idx, "softmax selector");
}

// ---------------------------------------------------------------- the test

/// Every plane the block half adds, against its kernel counterpart. The
/// remainder and limb planes have no kernel counterpart (the kernel keeps no
/// requantization witness), so they are checked against the kernel's own
/// BIASED requantization identity instead, which is the relation the argument
/// will prove: `acc = 2^sh y + r' - 2^(sh-1)` with `r'` the committed plane.
fn compare_block_half(c: &Case, w: &Witness, tr: &kern::Trace, idx: usize) {
    eq(&w.planes[A_DM], &tr.nm_dd, idx, "norm_m D");
    eq(&w.planes[A_YM], &tr.nm_y, idx, "norm_m y (nm)");
    eq(&w.planes[A_G8], &tr.g8, idx, "g8");
    eq(&w.planes[A_A16], &tr.a16, idx, "a16");
    eq(&w.planes[A_U16], &tr.u16, idx, "u16");
    eq(&w.planes[A_H16], &tr.h16, idx, "h16");
    eq(&w.planes[A_Z16], &tr.z16, idx, "z16");
    eq(&w.planes[A_X2], &tr.xres2, idx, "xres2");
    let dsqm: Vec<i64> = tr.nm_dd.iter().map(|d| d * d).collect();
    eq(&w.planes[A_DSQM], &dsqm, idx, "norm_m D^2");
    // the two-limb int16 decompositions, offset 32768
    for (v, l0, l1, name) in [
        (A_U16, A_UL0, A_UL1, "u16 limbs"),
        (A_H16, A_HL0, A_HL1, "h16 limbs"),
        (A_Z16, A_ZL0, A_ZL1, "z16 limbs"),
        (A_X2, A_X2L0, A_X2L1, "xres2 limbs"),
    ] {
        let joined: Vec<i64> = w.planes[l0].iter().zip(w.planes[l1].iter()).map(|(a, b)| a + 256 * b).collect();
        let offset: Vec<i64> = w.planes[v].iter().map(|x| x + 32768).collect();
        eq(&joined, &offset, idx, name);
        assert!(w.planes[l0].iter().chain(w.planes[l1].iter()).all(|l| (0..256).contains(l)), "case {idx}: a limb of {name} is not a byte");
    }
    // the biased requantization identities of the gate, the product and the
    // down matmul, recomputed from the kernel's own inputs
    let gacc: Vec<i64> = (0..T * F)
        .map(|k| {
            let (t, j) = (k / F, k % F);
            (0..D).map(|i| tr.nm_y[t * D + i] * i64::from(c.ff.wg_t[i * F + j])).sum()
        })
        .collect();
    let gid: Vec<i64> = (0..T * F).map(|k| (1i64 << SH_G) * w.planes[A_G8][k] + w.planes[A_RGL][k] - (1i64 << (SH_G - 1))).collect();
    eq(&gid, &gacc, idx, "gate requantization identity");
    assert!(w.planes[A_RGL].iter().all(|r| (0..1 << SH_G).contains(r)), "case {idx}: a gate remainder leaves [0, 2^7)");
    let hacc: Vec<i64> = (0..T * F).map(|k| tr.a16[k] * tr.u16[k]).collect();
    let rh: Vec<i64> = (0..T * F).map(|k| w.planes[A_RH0][k] + 256 * w.planes[A_RH1][k]).collect();
    let hid: Vec<i64> = (0..T * F).map(|k| (1i64 << SH_H_PROD) * w.planes[A_H16][k] + rh[k] - (1i64 << (SH_H_PROD - 1))).collect();
    eq(&hid, &hacc, idx, "product requantization identity");
    assert!(rh.iter().all(|r| (0..1 << SH_H_PROD).contains(r)), "case {idx}: a product remainder leaves [0, 2^14)");
    let zacc: Vec<i64> = (0..T * D)
        .map(|k| {
            let (t, i) = (k / D, k % D);
            (0..F).map(|j| tr.h16[t * F + j] * i64::from(c.ff.wd_t[j * D + i])).sum()
        })
        .collect();
    let zid: Vec<i64> = (0..T * D).map(|k| (1i64 << SH_Z) * w.planes[A_Z16][k] + w.planes[A_RDL][k] - (1i64 << (SH_Z - 1))).collect();
    eq(&zid, &zacc, idx, "down requantization identity");
    assert!(w.planes[A_RDL].iter().all(|r| (0..1 << SH_Z).contains(r)), "case {idx}: a down remainder leaves [0, 2^6)");
    // residual 2 and the classes the kernel refuses outside
    let sum: Vec<i64> = (0..T * D).map(|k| w.planes[A_X1][k] + w.planes[A_Z16][k]).collect();
    eq(&w.planes[A_X2], &sum, idx, "residual 2 (xres2 = xres1 + z16)");
    assert!(w.planes[A_G8].iter().all(|g| (-128..=127).contains(g)), "case {idx}: g8 leaves the kernel's int8 class");
    assert!(w.planes[A_YM].iter().all(|v| (-127..=127).contains(v)), "case {idx}: nm leaves the int8 subset");
}

#[test]
fn the_whole_block_witness_equals_the_reference_kernel() {
    // the layout exists and holds every plane the witness fills
    let lay = Layout::new();
    let (mut both_ok, mut both_refuse) = (0usize, 0usize);
    let mut sites: BTreeMap<String, usize> = BTreeMap::new();
    for idx in 0..CASES {
        let c = case(idx);
        let mut tr = Box::new(kern::Trace::zeroed());
        let kernel = kern::run_block_slice(&c.input, &c.kweights, &c.ktables, Some(&mut *tr));
        let wit = witness::build(&c.public, &c.ff, &c.input);
        match (&kernel, &wit) {
            (Ok(out), Ok(w)) => {
                compare_attention_half(w, &tr, idx);
                compare_block_half(&c, w, &tr, idx);
                let mine = w.output().expect("xres2 is in class once the witness accepted");
                assert_eq!(&mine[..], &out[..], "case {idx}: the block output differs from the kernel's");
                // every plane the grown layout declares is filled at its declared length
                for p in lay.a_planes() {
                    let want = if is_multiplicity(p) { 0 } else { a_dom(p).len() };
                    assert_eq!(w.planes[p].len(), want, "case {idx}: plane {p} length");
                }
                both_ok += 1;
            }
            (Err(e), Err(m)) => {
                assert_eq!(&format!("{e}"), m, "case {idx}: the two refusals differ");
                *sites.entry(m.clone()).or_default() += 1;
                both_refuse += 1;
            }
            (Err(e), Ok(_)) => panic!("case {idx}: the whole-block witness accepted where the kernel refused ({e})"),
            (Ok(_), Err(m)) => panic!("case {idx}: the whole-block witness refused (`{m}`) where the kernel accepted"),
        }
    }
    assert_eq!(both_ok + both_refuse, CASES, "every case is decided the same way by both");
    assert!(both_ok >= 100, "the sweep must exercise accepted blocks: only {both_ok} of {CASES}");
    assert!(both_refuse >= 100, "the sweep must exercise refusals: only {both_refuse} of {CASES}");
    assert!(sites.len() >= 6, "the sweep must reach several refusal sites, it reached {}", sites.len());
    assert!(sites.keys().any(|s| s.contains("residual 2")), "the sweep must reach a block-half refusal");
    eprintln!("private block whole-block parity: {CASES} generated public cases — {both_ok} accepted by both, {both_refuse} refused identically by both");
    for (site, count) in &sites {
        eprintln!("  refusal site `{site}`: {count}");
    }
}

/// The generator itself is deterministic: the same index gives the same bytes,
/// in this process and in any other (no OS randomness, no time, no hashing of
/// pointers). Cheap, so it runs on every build.
#[test]
fn the_case_generator_is_deterministic_and_covers_its_grid() {
    for idx in [0usize, 1, 7, 13, 65, 199, 1_199] {
        let a = case(idx);
        let b = case(idx);
        assert_eq!(a.input, b.input, "case {idx}: input differs between two generations");
        let dg = |c: &Case| BlockPublic::new(c.public.clone(), c.ff.clone()).digest();
        assert_eq!(dg(&a), dg(&b), "case {idx}: public statement differs between two generations");
    }
    let mut seen = std::collections::BTreeSet::new();
    let mut with_ffn = std::collections::BTreeSet::new();
    for idx in 0..CASES {
        seen.insert(((idx % 13), (idx / 13) % 4, (idx / 52) % 7));
        with_ffn.insert(((idx % 13), (idx / 13) % 4, (idx / 52) % 7, (idx / 11) % 13));
    }
    assert!(seen.len() >= 13 * 4 * 7, "the sweep covers {} of the {} grid points", seen.len(), 13 * 4 * 7);
    assert_eq!(with_ffn.len(), CASES, "the (attention band, gain, input, feed-forward band) settings are not all distinct");
    assert_ne!(case(0).input, case(1).input, "two cases share an input");
}

// ======================================================================
// STEP S6/S7: THE SAME PARITY AT THE DEVELOPMENT RUNG
// ======================================================================
//
// The toy sweep above is the frozen contract. Everything below runs the
// SAME two implementations — this module's witness builder and
// `private-block-kernel` — at the development rung of ruling P-7
// (`T24 / d96 / f192, 6 query heads of 16 over 2 KV heads`, GROUP 3), the
// shape the toy cannot express. The acceptance is WITNESS PARITY on the
// true (non-padded) coordinates and the no-wraparound bounds of memo
// section 3; it is NOT an end-to-end rung proof, which needs the pad rule
// (S9), the column count (S10) and the hidden endpoints (S11).
//
// Still public synthetic test data from a fixed-seed integer generator: no
// OS randomness, no real model, no real input, nothing on disk, and nothing
// printed but counts and site names.

use super::shape::Shape;
use super::witness::Geom;

/// generated cases per rung sweep
const RUNG_CASES: usize = 160;

/// **THE RUNG ITSELF (step S8 retired the fixture).** S6 and S7 could only
/// run the parity sweep at the rung's GEOMETRY with the toy's softmax
/// calibration (`F_E = 9`), because `Shape::rung()`'s own `F_E = 12` forces
/// a THIRD `sigma_s` limb and the plane table was pinned to two. S8's
/// `layout::Ids` maps that third limb, so the sweep now runs at
/// `Shape::rung()` — the shape of memo section 9a, windows and all — and
/// the separate fixture profile is gone.
fn rung_parity_shape() -> Shape {
    Shape::rung()
}

/// the same geometry and the same three windows, in the kernel's own terms
fn kernel_shape(s: &Shape) -> kshaped::Shape {
    kshaped::Shape::new(s.tokens, s.width, s.hidden, s.q_heads, s.kv_heads, s.head_dim, s.f_e, F_P, s.wrho_s, s.norm_wrho)
}

/// One generated public case at an arbitrary shape: the same words in the
/// module's statement form and in the kernel's.
struct ShapedCase {
    public: AttentionPublic,
    ff: FeedForwardPublic,
    input: Vec<i16>,
    words: [Vec<i8>; 9],
    cos: Vec<i64>,
    sin: Vec<i64>,
    exp: Vec<i64>,
    act: Vec<i16>,
}

impl ShapedCase {
    fn weights(&self) -> kshaped::WeightsRef<'_> {
        let w = &self.words;
        kshaped::WeightsRef { wq: &w[0], wk: &w[1], wv: &w[2], wo: &w[3], gamma_a: &w[4], gamma_m: &w[5], wg_t: &w[6], wu_t: &w[7], wd_t: &w[8] }
    }
    fn tables(&self) -> kshaped::TablesRef<'_> {
        kshaped::TablesRef { rope_cos: &self.cos, rope_sin: &self.sin, exp: &self.exp, act: &self.act }
    }
}

/// Case `idx` of a deterministic sweep at `s`, built the way the toy
/// fixtures are: diagonal-plus-band matrices, a gain-swept norm gain and an
/// amplitude-swept input, on three nested strides plus an independent
/// feed-forward band.
fn shaped_case(s: &Shape, idx: usize) -> ShapedCase {
    // a lane constant well clear of the toy sweep's indices
    let mut r = Rng::seeded(1_000_000 + idx);
    let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
    // the band is narrower than the toy's: at 96 inputs per accumulation a
    // full band leaves the int8 class six times sooner than at 16
    const BAND: [i64; 8] = [0, 1, 2, 4, 8, 16, 48, 127];
    let mag = BAND[idx % 8];
    let gain = [8i64, 24, 64, 127][(idx / 8) % 4];
    let xmag = [1i64, 4, 32, 512, 32_767][(idx / 32) % 5];
    let ffn_mag = BAND[(idx / 3) % 8];
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member (-3, -11)");
    let words = [
        matrix(&mut r, d, d, 64, mag),
        matrix(&mut r, kvw, d, 64, mag),
        matrix(&mut r, kvw, d, 64, mag),
        matrix(&mut r, d, d, 64, mag),
        (0..d).map(|_| r.pick(gain - 8, gain).clamp(-127, 127) as i8).collect(),
        (0..d).map(|_| r.pick(gain - 8, gain).clamp(-127, 127) as i8).collect(),
        matrix(&mut r, d, f, 64, ffn_mag),
        matrix(&mut r, d, f, 64, ffn_mag),
        matrix(&mut r, f, d, 64, ffn_mag),
    ];
    let input: Vec<i16> = (0..s.tokens * d).map(|_| r.pick(-xmag, xmag) as i16).collect();
    // the module takes the PADDED, head-permuted statement (ruling P-2); the
    // kernel keeps the TRUE-sized `words`, so the parity comparison is still
    // against the same arithmetic
    let aw = super::grow_tests::pad_attention_weights(s, &words[0], &words[1], &words[2], &words[3], &words[4]);
    let fw = super::grow_tests::pad_ff_weights(s, &words[5], &words[6], &words[7], &words[8]);
    let public = AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("generated public statement");
    let ff = FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("generated feed-forward statement");
    ShapedCase { public, ff, input, words, cos, sin, exp: exp.to_vec(), act: act.to_vec() }
}

/// Run the reference kernel at `s`, returning its verdict and trace buffer.
fn run_kernel_shaped(s: &Shape, c: &ShapedCase) -> (Result<Vec<i16>, kshaped::KernelError>, Vec<i64>) {
    let ksh = kernel_shape(s);
    let mut scratch = vec![0i64; ksh.scratch_len()];
    let mut tbuf = vec![0i64; ksh.trace_len()];
    let mut out = vec![0i16; ksh.x_len()];
    let r = kshaped::run_shaped(&ksh, &c.input, &c.weights(), &c.tables(), &mut scratch, Some(&mut tbuf), &mut out);
    (r.map(|()| out), tbuf)
}

/// Every witness plane with a kernel counterpart, on the TRUE coordinates,
/// element for element — plus the two derived planes the kernel does not
/// carry, plus the fact that every PAD position is still zero (which is a
/// statement about today's builder, not the pad rule of S9).
fn compare_shaped(s: &Shape, w: &Witness, tbuf: &[i64], idx: usize) {
    use kshaped::Part;
    let ksh = kernel_shape(s);
    let g = Geom::new(s);
    let part = |p: Part| {
        let (o, n) = ksh.part(p);
        &tbuf[o..o + n]
    };
    let maps: Vec<(Dom, Vec<usize>)> = [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F].into_iter().map(|d| (d, g.support(d))).collect();
    let map = |d: Dom| &maps.iter().find(|(k, _)| *k == d).expect("mapped domain").1;
    // S8: the plane ids are the SHAPE's, not the toy's literals — at the
    // rung's three `sigma_s` limbs every id above `Dom::S` is two higher
    let ids = Ids::new(s).expect("the parity shape has a plane map");
    let eq_at = |toy_plane: usize, k: &[i64], m: &[usize], name: &str| {
        let plane = ids.at(toy_plane);
        let mine: Vec<i64> = m.iter().map(|i| w.planes[plane][*i]).collect();
        eq(&mine, k, idx, name);
    };
    eq_at(A_D, part(Part::NaDd), map(Dom::T), "norm_a D");
    eq_at(A_DM, part(Part::NmDd), map(Dom::T), "norm_m D");
    eq_at(A_MX, part(Part::MRow), map(Dom::Ht), "row max");
    eq_at(A_SUM, part(Part::Sum), map(Dom::Ht), "row sum");
    for (plane, p, name) in
        [(A_Y, Part::NaY, "norm_a y"), (A_YM, Part::NmY, "norm_m y (nm)"), (A_AO, Part::Ao8, "ao"), (A_X1, Part::Xres1, "xres1"), (A_Z16, Part::Z16, "z16"), (A_X2, Part::Xres2, "xres2")]
    {
        eq_at(plane, part(p), map(Dom::D), name);
    }
    // S9: `q8`, `qr8` and `o8` live on `Dom::Q`, whose support is the
    // HEAD-PERMUTED one. The kernel lays its buffers out by LOGICAL head, and
    // `Geom::support(Dom::Q)` walks the logical heads in order, so the two
    // still line up element for element — at the rung they land on different
    // plane positions than `Dom::D`'s support does, which is the whole point
    // of correction C-1.
    for (plane, p, name) in [(A_Q8, Part::Q8, "q8"), (A_QR8, Part::Qr8, "qr8"), (A_O8, Part::O8, "o8")] {
        eq_at(plane, part(p), map(Dom::Q), name);
    }
    for (plane, p, name) in [(A_K8, Part::K8, "k8"), (A_V8, Part::V8, "v8"), (A_KR8, Part::Kr8, "kr8")] {
        eq_at(plane, part(p), map(Dom::Kv), name);
    }
    for (plane, p, name) in [(A_S8, Part::S8, "s8"), (A_P, Part::P, "softmax p")] {
        eq_at(plane, part(p), map(Dom::S), name);
    }
    for (plane, p, name) in [(A_G8, Part::G8, "g8"), (A_A16, Part::A16, "a16"), (A_U16, Part::U16, "u16"), (A_H16, Part::H16, "h16")] {
        eq_at(plane, part(p), map(Dom::F), name);
    }
    // the two planes the kernel keeps no witness for
    let dsq: Vec<i64> = part(Part::NaDd).iter().map(|d| d * d).collect();
    eq_at(A_DSQ, &dsq, map(Dom::T), "norm_a D^2");
    let dsqm: Vec<i64> = part(Part::NmDd).iter().map(|d| d * d).collect();
    eq_at(A_DSQM, &dsqm, map(Dom::T), "norm_m D^2");
    // the one-hot selector against the kernel's argmax index
    let smap = map(Dom::S);
    let mut zsel = vec![0i64; smap.len()];
    for (row, arg) in part(Part::Arg).iter().enumerate() {
        zsel[row * s.tokens + *arg as usize] = 1;
    }
    eq_at(A_ZSEL, &zsel, smap, "softmax selector");
    // every plane is exactly its padded domain's length, and every position
    // OUTSIDE the true support is zero (S9 is what rules on what it should be)
    for (dom, m) in &maps {
        let mut is_true = vec![false; s.size(*dom)];
        for i in m {
            is_true[*i] = true;
        }
        for p in 0..ids.n_a() {
            if ids.is_multiplicity(p) || ids.dom(p) != *dom {
                continue;
            }
            assert_eq!(w.planes[p].len(), s.size(*dom), "case {idx}: plane {p} length");
            // **S12a.** The rule is the memo's table (`pad::a_rule`), not
            // "everything is zero": `A_E` is EXEMPT, and its padded
            // positions carry a genuine `exp` row on purpose — the LogUp arm
            // is never gated, so a zero there would put a pair that is not a
            // table row into the value-0 identity (finding S12-F3). Every
            // ZERO-rule plane is still zero off its support, and that is
            // what the pad-zero term proves.
            if super::pad::a_rule(s, &ids, p) == Some(super::pad::Rule::Exempt) {
                continue;
            }
            let bad = (0..w.planes[p].len()).filter(|i| !is_true[*i] && w.planes[p][*i] != 0).count();
            assert_eq!(bad, 0, "case {idx}: plane {p} has {bad} nonzero pad positions");
        }
    }
}

/// THE ACCEPTANCE OF S6/S7: at the rung, the witness builder and the
/// reference kernel decide every generated case the same way, and on an
/// accepted case every plane with a kernel counterpart agrees element for
/// element on every true coordinate.
///
/// BEFORE step S7 this test FAILS at `kr8` (and then at `s8` and `o8`): the
/// witness rotated one key head and read key-value head 0 for all six query
/// heads, while the kernel reads head `h / 3`.
#[test]
fn the_whole_block_witness_equals_the_reference_kernel_at_the_rung() {
    let s = rung_parity_shape();
    assert_eq!(s.q_heads / s.kv_heads, 3, "the rung's group is 3");
    let (mut both_ok, mut both_refuse) = (0usize, 0usize);
    let mut sites: BTreeMap<String, usize> = BTreeMap::new();
    for idx in 0..RUNG_CASES {
        let c = shaped_case(&s, idx);
        let (kernel, tbuf) = run_kernel_shaped(&s, &c);
        let wit = witness::build_shaped(&s, &c.public, &c.ff, &c.input);
        match (&kernel, &wit) {
            (Ok(out), Ok(w)) => {
                compare_shaped(&s, w, &tbuf, idx);
                let dmap = Geom::new(&s).support(Dom::D);
                let mine: Vec<i16> = dmap.iter().map(|i| w.planes[A_X2][*i] as i16).collect();
                assert_eq!(&mine[..], &out[..], "case {idx}: the block output differs from the kernel's");
                both_ok += 1;
            }
            (Err(e), Err(m)) => {
                assert_eq!(&format!("{e}"), m, "case {idx}: the two refusals differ");
                *sites.entry(m.clone()).or_default() += 1;
                both_refuse += 1;
            }
            (Err(e), Ok(_)) => panic!("case {idx}: the rung witness accepted where the kernel refused ({e})"),
            (Ok(_), Err(m)) => panic!("case {idx}: the rung witness refused (`{m}`) where the kernel accepted"),
        }
    }
    assert_eq!(both_ok + both_refuse, RUNG_CASES, "every rung case is decided the same way by both");
    assert!(both_ok >= 100, "the rung sweep must exercise accepted blocks: only {both_ok} of {RUNG_CASES}");
    assert!(both_refuse >= 20, "the rung sweep must exercise refusals: only {both_refuse} of {RUNG_CASES}");
    assert!(sites.len() >= 4, "the rung sweep must reach several refusal sites, it reached {}", sites.len());
    eprintln!("private block rung parity: {RUNG_CASES} cases — {both_ok} accepted by both, {both_refuse} refused identically by both");
    for (site, count) in &sites {
        eprintln!("  rung refusal site `{site}`: {count}");
    }
}

/// THE GROUP STRUCTURE IN THE WITNESS, as a property and not a literal
/// (step S7's permanent regression test).
///
/// Zeroing key-value head `kill`'s `Wk` and `Wv` rows makes that head's
/// `k8`, `kr8` and `v8` identically zero, so every query head that READS it
/// gets an all-zero score row and an all-zero attention output. The test
/// therefore first finds a case whose base scores and outputs are nonzero on
/// EVERY query head — which makes "the plane changed" a consequence of the
/// grouping and not of the fixture — and then asserts that killing head
/// `kill` moves exactly the query heads of that group and leaves the others
/// bit for bit unchanged.
///
/// With the ungrouped code every query head read key-value head 0, so
/// killing head 1 changed NOTHING and this test failed.
#[test]
fn a_witness_query_head_reads_only_its_own_key_value_head_at_the_rung() {
    let s = rung_parity_shape();
    let g = Geom::new(&s);
    let group = s.q_heads / s.kv_heads;
    let d = s.width;
    let ssup = g.support(Dom::S);
    let head_rows = |h: usize| &ssup[h * s.tokens * s.tokens..(h + 1) * s.tokens * s.tokens];
    // S9: a query head's output sits at its padded head SLOT
    let (tk, dp, dh) = (s.tokens, s.d_pad, s.head_dim);
    let head_out: Vec<Vec<usize>> = (0..s.q_heads)
        .map(|h| {
            let sl = s.head_slot(h);
            (0..tk).flat_map(|t| (0..dh).map(move |i| t * dp + sl * dh + i)).collect()
        })
        .collect();
    let build = |c: &ShapedCase, kill: Option<usize>| -> Result<Witness, String> {
        let mut words = c.words.clone();
        if let Some(h) = kill {
            for j in h * s.head_dim..(h + 1) * s.head_dim {
                for i in 0..d {
                    words[1][j * d + i] = 0;
                    words[2][j * d + i] = 0;
                }
            }
        }
        let aw = super::grow_tests::pad_attention_weights(&s, &words[0], &words[1], &words[2], &words[3], &words[4]);
        let public = AttentionPublic::new_shaped(&s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &c.cos, &c.sin, &c.exp).expect("statement");
        witness::build_shaped(&s, &public, &c.ff, &c.input)
    };
    // a case that ACCEPTS and whose every query head has something to lose
    let mut chosen = None;
    for idx in 0..RUNG_CASES {
        let c = shaped_case(&s, idx);
        if let Ok(w) = build(&c, None) {
            let live = (0..s.q_heads).all(|h| head_rows(h).iter().any(|i| w.planes[A_S8][*i] != 0) && head_out[h].iter().any(|i| w.planes[A_O8][*i] != 0));
            if live {
                chosen = Some((idx, c, w));
                break;
            }
        }
    }
    let (idx, case, all) = chosen.expect("the rung sweep has an accepted case with a nonzero score and output on every query head");
    eprintln!("private block rung grouping: case {idx}, group {group}, {} key-value heads", s.kv_heads);
    for kill in 0..s.kv_heads {
        let w = build(&case, Some(kill)).expect("zeroing a key-value head's projection cannot make an accepted case refuse");
        for h in 0..s.q_heads {
            let same_s = head_rows(h).iter().all(|i| w.planes[A_S8][*i] == all.planes[A_S8][*i]);
            assert_eq!(same_s, h / group != kill, "killing key-value head {kill}: query head {h}'s scores (unchanged = {same_s}) do not follow the grouping");
            let same_o = head_out[h].iter().all(|i| w.planes[A_O8][*i] == all.planes[A_O8][*i]);
            assert_eq!(same_o, h / group != kill, "killing key-value head {kill}: query head {h}'s attention output (unchanged = {same_o}) does not follow the grouping");
        }
    }
}

/// **M-1, the argument side of S7.** `SC_KVZC`'s public RoPE table is laid
/// out over the KEY-VALUE heads: at the rung it must hold
/// `tokens * kv_heads * head_dim` entries. With the bare literal `1` it held
/// `tokens * 1 * head_dim` and the slot's own table-length check
/// (`run_slot`, `argument.rs`) would refuse the first proof.
///
/// The argument is still instantiable only at the toy (finding S5-F2), so
/// this exercises the table BUILDER at the rung, which is where the literal
/// lived.
#[test]
fn the_key_value_rope_table_is_laid_out_over_the_key_value_heads() {
    for s in [Shape::toy(), Shape::rung()] {
        let c = shaped_case(&s, 0);
        let (ct, st) = super::argument::rope_tables(&s, &c.public, s.kv_heads);
        let want = s.tokens * s.kv_heads * s.head_dim;
        assert_eq!(ct.len(), want, "{}: the key-value RoPE cos table is not T * H_kv * d_h", s.name);
        assert_eq!(st.len(), want, "{}: the key-value RoPE sin table is not T * H_kv * d_h", s.name);
        // the bare `1` is exactly `kv_heads` times too short at the rung
        let (bare, _) = super::argument::rope_tables(&s, &c.public, 1);
        assert_eq!(bare.len() * s.kv_heads, want, "{}: the ungrouped table length is not the grouped one over kv_heads", s.name);
        assert_eq!(bare.len() == want, s.kv_heads == 1, "{}: the bare literal 1 is only right at one key-value head", s.name);
        // the query side is unchanged: one table row per (t, h, i')
        let (qt, _) = super::argument::rope_tables(&s, &c.public, s.q_heads);
        assert_eq!(qt.len(), s.tokens * s.q_heads * s.head_dim, "{}: the query RoPE table moved", s.name);
    }
}

/// THE NO-WRAPAROUND BOUNDS OF MEMO SECTION 3, at the rung's widths, as
/// assertions computed from the shape. Rows 1-6 and 11-12 of the summary
/// table of section 3.8; rows 7-10 are the two limb counts and the two
/// windows, which the shape derives and the builder enforces.
#[test]
fn the_memo_section_three_bounds_hold_at_the_rung() {
    let s = rung_parity_shape();
    let two49 = 1i128 << 49;
    // the field of the proof: p = 2^64 - 2^32 + 1
    let p: i128 = (1i128 << 64) - (1i128 << 32) + 1;
    let (d, f, dh, t) = (s.width as i128, s.hidden as i128, s.head_dim as i128, s.tokens as i128);
    // 1: QKV / Wo / gate / up, int8 x int8 over the width (weights may be -128)
    let mm = d * 127 * 128;
    assert!(mm < two49, "the width-{d} matmul accumulation {mm} reaches 2^49");
    // 2: down, int16 x int8 over the hidden width
    let down = f * 32_767 * 128;
    assert!(down < two49, "the down accumulation {down} reaches 2^49");
    // 3: scores, int8 x int8 over the head dimension
    let score = dh * 127 * 127;
    assert!(score < two49, "the score accumulation {score} reaches 2^49");
    // 4: PV, at the PROVED bound p < 2^10 (two limbs with scaled(A_PL1, 64))
    let pv = t * ((1i128 << 10) - 1) * 127;
    assert!(pv < two49, "the PV accumulation {pv} reaches 2^49");
    // 5: a16 * u16
    let prod = 32_767i128 * 32_767;
    assert!(prod < two49, "the activation product {prod} reaches 2^49");
    // 6, 7, 8: the isqrt witness and its three byte limbs
    let dmax = s.d_max;
    assert_eq!(dmax, 321_049, "the rung's D_max moved");
    assert!(dmax * dmax + 2 * dmax < p, "D^2 + a1 reaches the field modulus");
    let limb_window = 1i128 << (8 * super::shape::LIMBS_ISQRT);
    assert!(dmax < limb_window && 2 * dmax < limb_window, "D, a1 or a2 needs a fourth byte limb at the rung");
    // 9: the norm remainder window. den - 1 = 4096 D_max - 1 must fit
    assert_eq!(s.norm_wrho, 31, "the rung's norm window moved");
    assert!(4096 * dmax - 1 < (1i128 << s.norm_wrho), "the norm remainder leaves its window at the rung");
    assert!(s.norm_wrho <= 32, "the four-limb `1 << (32 - wrho)` idiom needs wrho <= 32");
    assert_eq!(s.limbs_norm(), 4, "the norm remainder's limb count moved");
    // 10: the softmax window, at the rung's OWN calibration (S8: the sweep no
    // longer borrows the toy's `F_E`)
    assert_eq!(s.f_e, 12, "the rung's exponential scale moved");
    let sum_max = t * (1i128 << s.f_e);
    assert_eq!(sum_max, 98_304, "Sum's rung bound moved");
    assert!(sum_max > (1i128 << 14), "the toy's 14-bit softmax window would be enough, so the rung proves nothing here");
    assert!(sum_max < (1i128 << s.wrho_s), "Sum {sum_max} leaves the 2^{} softmax window", s.wrho_s);
    assert_eq!((s.wrho_s, s.limbs_sigma_s()), (17, 3), "the rung's softmax window and its limb count");
    // 11: p * Sum + rho_s
    let quot = (1i128 << F_P) * sum_max + sum_max;
    assert!(quot < two49, "the softmax quotient identity {quot} reaches 2^49");
    // 12: delta < 256 is enforced by the builder's own `exp difference` refusal
    // the plane table the witness writes, through S8's shape-driven map
    let ids = Ids::new(&s).expect("the rung has a plane map");
    assert_eq!(s.a_plane_doms().len(), N_A + 2, "the rung's two extra Dom::S planes");
    assert_eq!(ids.n_a(), N_A + 2, "the map and the shape disagree on the plane count");
    assert!((0..N_A).all(|q| ids.dom(ids.at(q)) == a_dom(q)), "a toy plane maps onto another domain at the rung");
}

// ======================================================================
// JOB K: THE TWO KERNEL CRATES AGREE AT THE TOY
// ======================================================================
//
// `private-block-kernel` is compiled into the project's zkVM guest, whose
// image identity is an approved recorded artifact, so it is BYTE-FROZEN at
// commit `11c01b2` and the shape-driven kernel was moved into the separate
// crate `private-block-kernel-shaped`. That crate may not depend on the
// frozen one (the guest must keep compiling the frozen crate as a leaf), so
// the calibration table and the scalar primitives are COPIES.
//
// A copy can drift silently. These tests are the only thing that stops it:
// this file is the one place in the repository that sees BOTH crates.

/// One trace part of the frozen crate's fixed [`kern::Trace`], by the
/// shape-driven crate's own part name.
fn frozen_part<'a>(tr: &'a kern::Trace, p: kshaped::Part) -> &'a [i64] {
    use kshaped::Part as P;
    match p {
        P::NaDd => &tr.na_dd,
        P::NaY => &tr.na_y,
        P::Q8 => &tr.q8,
        P::K8 => &tr.k8,
        P::V8 => &tr.v8,
        P::Qr8 => &tr.qr8,
        P::Kr8 => &tr.kr8,
        P::S8 => &tr.s8,
        P::MRow => &tr.m_row,
        P::Arg => &tr.arg,
        P::Sum => &tr.sum,
        P::P => &tr.p,
        P::O8 => &tr.o8,
        P::Ao8 => &tr.ao8,
        P::Xres1 => &tr.xres1,
        P::NmDd => &tr.nm_dd,
        P::NmY => &tr.nm_y,
        P::G8 => &tr.g8,
        P::A16 => &tr.a16,
        P::U16 => &tr.u16,
        P::H16 => &tr.h16,
        P::Z16 => &tr.z16,
        P::Xres2 => &tr.xres2,
    }
}

/// **JOB K's acceptance.** At `Shape::toy()` the shape-driven crate computes
/// what the frozen crate computes, on EVERY case of the 1,200-case toy
/// fixture sweep — the same verdict, the same refusal string, and on both
/// outcomes every one of the 23 trace planes element for element (the traces
/// are filled progressively in the same order, so a refused case's partial
/// trace is compared too).
#[test]
fn the_shaped_kernel_equals_the_frozen_kernel_at_the_toy() {
    let sh = kshaped::Shape::toy();
    assert_eq!((sh.tokens, sh.width, sh.hidden), (T, D, F), "the shaped toy geometry is not the module's");
    assert_eq!((sh.q_heads, sh.kv_heads, sh.head_dim), (H, kern::HKV, DH), "the shaped toy head layout is not the module's");
    let (mut both_ok, mut both_refuse) = (0usize, 0usize);
    for idx in 0..CASES {
        let c = case(idx);
        let mut tr = Box::new(kern::Trace::zeroed());
        let frozen = kern::run_block_slice(&c.input, &c.kweights, &c.ktables, Some(&mut *tr));
        // the SAME public words, read off this case's own statement
        let w = kshaped::WeightsRef {
            wq: &c.public.wq,
            wk: &c.public.wk,
            wv: &c.public.wv,
            wo: &c.public.wo,
            gamma_a: &c.public.gamma_a,
            gamma_m: &c.ff.gamma_m,
            wg_t: &c.ff.wg_t,
            wu_t: &c.ff.wu_t,
            wd_t: &c.ff.wd_t,
        };
        let tab = kshaped::TablesRef { rope_cos: &c.public.rope_cos, rope_sin: &c.public.rope_sin, exp: &c.public.exp, act: &c.ff.act };
        let mut scratch = vec![0i64; sh.scratch_len()];
        let mut tbuf = vec![0i64; sh.trace_len()];
        let mut out = vec![0i16; sh.x_len()];
        let shaped = kshaped::run_shaped(&sh, &c.input, &w, &tab, &mut scratch, Some(&mut tbuf), &mut out);
        // plane by plane, on BOTH outcomes
        for p in kshaped::PARTS {
            let (o, n) = sh.part(p);
            eq(&tbuf[o..o + n], frozen_part(&tr, p), idx, &format!("shaped-vs-frozen {p:?}"));
        }
        match (&frozen, &shaped) {
            (Ok(a), Ok(())) => {
                assert_eq!(&a[..], &out[..], "case {idx}: the two crates' block outputs differ");
                both_ok += 1;
            }
            (Err(a), Err(b)) => {
                assert_eq!(format!("{a}"), format!("{b}"), "case {idx}: the two crates refuse with different strings");
                both_refuse += 1;
            }
            (Err(a), Ok(())) => panic!("case {idx}: the shaped crate accepted where the frozen crate refused ({a})"),
            (Ok(_), Err(b)) => panic!("case {idx}: the shaped crate refused (`{b}`) where the frozen crate accepted"),
        }
    }
    assert_eq!(both_ok + both_refuse, CASES);
    assert!(both_ok >= 100 && both_refuse >= 100, "the cross-parity sweep must exercise both outcomes: {both_ok} / {both_refuse}");
    eprintln!("job K cross-parity: {CASES} toy cases — {both_ok} accepted by both crates, {both_refuse} refused identically, 23 trace planes equal on every case");
}

/// The COPIED calibration table, constant for constant. A drift here is the
/// one way the split could change what either kernel computes without any
/// test of either crate alone noticing.
#[test]
fn the_shaped_crate_copies_the_frozen_calibration_exactly() {
    assert_eq!(kshaped::calib::NORM_TN, kern::calib::NORM_TN);
    assert_eq!(kshaped::calib::NORM_CN, kern::calib::NORM_CN);
    assert_eq!(kshaped::calib::NORM_CEPS, kern::calib::NORM_CEPS);
    assert_eq!(kshaped::calib::NORM_WRHO, kern::calib::NORM_WRHO);
    assert_eq!(kshaped::calib::SH_Q, kern::calib::SH_Q);
    assert_eq!(kshaped::calib::SH_K, kern::calib::SH_K);
    assert_eq!(kshaped::calib::SH_V, kern::calib::SH_V);
    assert_eq!(kshaped::calib::SH_QR, kern::calib::SH_QR);
    assert_eq!(kshaped::calib::SH_KR, kern::calib::SH_KR);
    assert_eq!(kshaped::calib::SH_S, kern::calib::SH_S);
    assert_eq!(kshaped::calib::SH_O, kern::calib::SH_O);
    assert_eq!(kshaped::calib::SH_AO, kern::calib::SH_AO);
    assert_eq!(kshaped::calib::SH_X1, kern::calib::SH_X1);
    assert_eq!(kshaped::calib::SH_A1, kern::calib::SH_A1);
    assert_eq!(kshaped::calib::SH_R1, kern::calib::SH_R1);
    assert_eq!(kshaped::calib::F_E, kern::calib::F_E);
    assert_eq!(kshaped::calib::F_P, kern::calib::F_P);
    assert_eq!(kshaped::calib::F_RO, kern::calib::F_RO);
    assert_eq!(kshaped::calib::WRHO_S, kern::calib::WRHO_S);
    assert_eq!(kshaped::calib::SH_G, kern::calib::SH_G);
    assert_eq!(kshaped::calib::SH_U, kern::calib::SH_U);
    assert_eq!(kshaped::calib::SH_H, kern::calib::SH_H);
    assert_eq!(kshaped::calib::SH_Z, kern::calib::SH_Z);
    assert_eq!(kshaped::calib::SH_X2, kern::calib::SH_X2);
    assert_eq!(kshaped::calib::SH_Z2, kern::calib::SH_Z2);
    assert_eq!(kshaped::calib::SH_R2, kern::calib::SH_R2);
    assert_eq!(kshaped::calib::MASK, kern::calib::MASK);
    // and the shaped toy shape reads the same four windows the module does
    let sh = kshaped::Shape::toy();
    assert_eq!((sh.f_e, sh.f_p, sh.wrho_s, sh.norm_wrho), (kern::calib::F_E, kern::calib::F_P, kern::calib::WRHO_S, kern::calib::NORM_WRHO));
}

/// The COPIED scalar primitives and the two matmuls, function for function
/// rather than only through a whole block: a difference in a corner neither
/// fixture reaches would otherwise wait for a shape nobody has run yet.
#[test]
fn the_shaped_crate_copies_the_frozen_primitives_exactly() {
    // isqrt over small values, powers of two and their neighbours, and the
    // range the norm actually reaches at 125M widths
    let mut vals: Vec<u64> = (0u64..512).collect();
    for k in 0..63u32 {
        let b = 1u64 << k;
        vals.extend([b.saturating_sub(1), b, b + 1]);
    }
    vals.extend([u64::MAX, u64::MAX - 1, 321_049u64 * 321_049, 4_096 * 321_049]);
    for v in &vals {
        assert_eq!(kshaped::isqrt(*v), kern::isqrt(*v), "isqrt differs at {v}");
    }
    // requant at every shift the calibration uses, plus the two edges
    let accs: [i64; 13] = [0, 1, -1, 2, -2, 127, -127, 32_767, -32_768, 1 << 40, -(1 << 40), i64::MAX, i64::MIN];
    for sh in [-2i32, -1, 0, 1, 6, 7, 9, 14, 62, 63] {
        for a in accs {
            let (x, y) = (kshaped::requant(a, sh, "s"), kern::requant(a, sh, "s"));
            assert_eq!(x.ok(), y.ok(), "requant({a}, {sh}) differs");
            assert_eq!(x.err().map(|e| format!("{e}")), y.err().map(|e| format!("{e}")), "requant({a}, {sh}) refuses differently");
        }
    }
    // the two matmuls at the toy's row count, on a deterministic fixture
    let mut r = Rng::seeded(424_242);
    let x: Vec<i64> = (0..T * D).map(|_| r.pick(-32_768, 32_767)).collect();
    let w: Vec<i8> = (0..D * D).map(|_| r.pick(-128, 127) as i8).collect();
    let (mut a, mut b) = (vec![0i64; T * D], vec![0i64; T * D]);
    kshaped::matmul_out_in(T, &x, &w, D, D, &mut a).expect("shaped matmul_out_in");
    kern::matmul_out_in(&x, &w, D, D, &mut b).expect("frozen matmul_out_in");
    assert_eq!(a, b, "matmul_out_in differs between the two crates");
    kshaped::matmul_in_out(T, &x, &w, D, D, &mut a).expect("shaped matmul_in_out");
    kern::matmul_in_out(&x, &w, D, D, &mut b).expect("frozen matmul_in_out");
    assert_eq!(a, b, "matmul_in_out differs between the two crates");
    // the softmax row, including its refusals, on rows drawn to hit both
    let sh = kshaped::Shape::toy();
    let (_, _, exp, _) = tables();
    for t in [0usize, 1, 7, 31] {
        for band in [1i64, 8, 64, 127, 200] {
            let scores: Vec<i64> = (0..T).map(|_| r.pick(-band, band)).collect();
            let row: &[i64; T] = scores[..].try_into().expect("row");
            let frozen = kern::softmax_row(row, t, exp);
            let (mut e, mut p) = (vec![0i64; T], vec![0i64; T]);
            let shaped = kshaped::softmax_row_into(&sh, &scores, t, exp, &mut e, &mut p);
            match (&frozen, &shaped) {
                (Ok(f), Ok((max, arg, sum))) => {
                    assert_eq!((f.max, f.arg, f.sum), (*max, *arg, *sum), "softmax scalars differ at t={t} band={band}");
                    assert_eq!(&f.p[..], &p[..], "softmax p differs at t={t} band={band}");
                }
                (Err(f), Err(s)) => assert_eq!(format!("{f}"), format!("{s}"), "softmax refusals differ at t={t} band={band}"),
                _ => panic!("softmax verdicts differ at t={t} band={band}"),
            }
        }
    }
}
